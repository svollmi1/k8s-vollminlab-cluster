# Observability Stack Design

**Date:** 2026-04-17
**Phase:** 2 (Roadmap)
**Status:** Approved — pending implementation

---

## Summary

Deploy a production-grade observability stack in the existing `monitoring` namespace:

- **kube-prometheus-stack** — Prometheus + Grafana + Alertmanager
- **Loki** — log storage (S3-backed via MinIO)
- **Promtail** — log shipping DaemonSet on all nodes
- **OTel Collector** — deferred until Istio (Phase 5)

ECK (eck-operator) is removed in a follow-up PR after Loki is confirmed healthy.

---

## Architecture

```text
pods → Promtail (DaemonSet, all nodes) → Loki (SingleBinary) → Grafana
cluster components → Prometheus → Grafana
                               → Alertmanager → PushOver
```

All components run in the `monitoring` namespace. Loki uses MinIO (`loki` bucket) as its S3-compatible object store. Grafana is the single UI for both metrics and logs.

---

## Section 1 — kube-prometheus-stack

**Source:** `kind: HelmRepository`, `https://prometheus-community.github.io/helm-charts`

**Components deployed by this one HelmRelease:**

| Component | Config |
|---|---|
| Prometheus | 30s scrape interval, 15-day retention, 5Gi Longhorn PVC |
| Grafana | Ingress at `grafana.vollminlab.com`, TLS via `internal-ca`, Loki data source pre-wired |
| Alertmanager | PushOver receiver via SealedSecret, 1Gi Longhorn PVC |
| Node exporter | DaemonSet — toleration: `dmz=true:NoSchedule` + control-plane |
| kube-state-metrics | Default config, general workers |

**ServiceMonitors enabled out of the box:** ingress-nginx, Longhorn, Flux, CoreDNS, kube-state-metrics.

**Resource requests (conservative):**

| Component | CPU req | Memory req | CPU limit | Memory limit |
|---|---|---|---|---|
| Prometheus | 250m | 512Mi | 1000m | 1Gi |
| Grafana | 100m | 128Mi | 500m | 256Mi |
| Alertmanager | 50m | 64Mi | 200m | 128Mi |

**Alertmanager SealedSecret** — contains PushOver app token + user key. Single route: all alerts → PushOver.

**Ingress:**
- Host: `grafana.vollminlab.com`
- TLS: `internal-ca` ClusterIssuer
- Shlink annotation: `shlink.vollminlab.com/slug: grafana`
- Labels: `app: grafana`, `env: production`, `category: observability`

---

## Section 2 — Loki

**Source:** `kind: HelmRepository`, `https://grafana.github.io/helm-charts` (shared with Promtail)

**Deployment mode:** SingleBinary — single pod, simplest for homelab scale.

**Storage:**

| Backend | Detail |
|---|---|
| Object store | MinIO, bucket `loki`, endpoint `http://minio.minio.svc.cluster.local:9000` |
| Credentials | SealedSecret (`loki-minio-credentials`) in `monitoring` namespace — contains MinIO root username/password (SealedSecrets are namespace-scoped, so this is a separate seal of the same values from `minio-credentials`) |
| WAL PVC | 2Gi Longhorn (write-ahead log only — log data goes to MinIO) |

**Retention:** 30 days (`limits_config.retention_period`).

**No Ingress** — Grafana accesses Loki via in-cluster service at `http://loki.monitoring.svc.cluster.local:3100`.

**Grafana data source** (pre-configured in kube-prometheus-stack values):

```yaml
additionalDataSources:
  - name: Loki
    type: loki
    url: http://loki.monitoring.svc.cluster.local:3100
    access: proxy
```

---

## Section 3 — Promtail

**Source:** same `grafana` HelmRepository as Loki.

**Deployment:** DaemonSet on all nodes.

**Tolerations:**

| Toleration | Reason |
|---|---|
| `dmz=true:NoSchedule` | Run on k8sworker05/06 |
| `node-role.kubernetes.io/control-plane:NoSchedule` | Run on k8scp01/02/03 |

**Log sources scraped:** `/var/log/pods`, `/var/log/containers`

**Push target:** `http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push`

**Pod labels:** `app: promtail`, `env: production`, `category: observability`

---

## Section 4 — MinIO Changes

One addition to `clusters/vollminlab-cluster/minio/minio/app/configmap.yaml`:

```yaml
buckets:
  - name: velero        # existing
    ...
  - name: loki          # new
    policy: none
    purge: false
    versioning: false
    objectlocking: false
```

No other MinIO changes.

---

## Section 5 — Flux Integration

### New file structure

```
clusters/vollminlab-cluster/monitoring/
  kube-prometheus-stack/app/
    helmrelease.yaml
    configmap.yaml
    ingress.yaml
    alertmanager-sealedsecret.yaml
    kustomization.yaml
  loki/app/
    helmrelease.yaml
    configmap.yaml
    loki-sealedsecret.yaml
    kustomization.yaml
  promtail/app/
    helmrelease.yaml
    configmap.yaml
    kustomization.yaml
  kustomization.yaml              # updated to list all three apps
```

### Flux index updates (both required per flux.md)

**`flux-system/flux-kustomizations/kustomization.yaml`**
- Verify `- monitoring-kustomization.yaml` is present (namespace exists but check if kustomization CR exists)
- Add if missing

**`flux-system/repositories/kustomization.yaml`**
- Add `- prometheus-community-helmrepository.yaml`
- Add `- grafana-helmrepository.yaml`

### New repository files

- `flux-system/repositories/prometheus-community-helmrepository.yaml` — `kind: HelmRepository`, URL `https://prometheus-community.github.io/helm-charts`
- `flux-system/repositories/grafana-helmrepository.yaml` — `kind: HelmRepository`, URL `https://grafana.github.io/helm-charts`

---

## Section 6 — ECK Removal (follow-up PR)

After Loki is confirmed healthy (logs flowing in Grafana):

1. Delete `clusters/vollminlab-cluster/elastic-system/` directory entirely
2. Remove `- elastic-system-kustomization.yaml` from `flux-system/flux-kustomizations/kustomization.yaml`
3. Remove ECK HelmRepository entry from `flux-system/repositories/kustomization.yaml`
4. Flux will garbage-collect the eck-operator HelmRelease and namespace

---

## Decisions Made

| Decision | Choice | Rationale |
|---|---|---|
| Alert delivery | PushOver | Reliable, $5 one-time, no infra to run |
| Log backend | Loki (replace ECK) | Grafana-native, MinIO already present, lighter than ELK |
| Loki mode | SingleBinary | Homelab scale, operational simplicity |
| OTel Collector | Deferred | No apps emitting traces yet; revisit at Istio (Phase 5) |
| Namespace | Single `monitoring` | Simpler than split monitoring/logging at this scale |

---

## Out of Scope

- OpenTelemetry Collector (deferred to Phase 5 — Istio)
- Authentik SSO on Grafana (Phase 3 — Security & Access)
- SLOs / SLOTH (Phase 6 — SRE Practice)
- Chaos Mesh (Phase 6)
