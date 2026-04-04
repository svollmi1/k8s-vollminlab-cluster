# Vollminlab Cluster Roadmap

Living document tracking planned infrastructure work. Update status as projects progress.

**Status key:** `planned` | `in-progress` | `done` | `blocked` | `deferred`

---

## Phase 1 — Foundations (Prerequisite for everything else)

### 1.1 Backup Stack — MinIO + Velero + Backblaze B2
**Status:** `done`

- MinIO deployed in-cluster as the primary (fast) backup target
- Velero with two BackupStorageLocations: `minio` (default, daily at 02:00 UTC) and `b2` (off-site, daily at 04:00 UTC)
- Backblaze B2 bucket: `vollminlab-k8s-backups`, region `us-west-000`
- Credentials in SealedSecrets; validation frequency tuned to 1h to limit B2 Class C API calls
- **Still needed:** run a test restore and document the procedure in `docs/`

---

### 1.2 GitHub Actions Runner Migration
**Status:** `done`

Migrated to ARC v2 (`gha-runner-scale-set-controller` + `AutoscalingRunnerSet`). Legacy summerwind resources removed. Both ARC HelmReleases use `OCIRepository` + `spec.chartRef` per current Flux best practice. Single `vollminlab` runner pool.

---

### 1.3 Renovate Bot — Automated Helm Chart Updates
**Status:** `done`

Self-hosted Renovate deployed as a Kubernetes CronJob in the `renovate` namespace. Runs nightly at 02:00 ET. Covers:
- All `HelmRelease` chart versions (`spec.chart.spec.version`) across all namespaces
- All `OCIRepository` tag versions (`spec.ref.tag`) — TrueCharts mediastack apps, ARC, Renovate itself
- GitHub Actions `uses:` version pins in all workflow files

All updates require manual review (no automerge). Dependency Dashboard issue maintained automatically in GitHub.

---

### 1.4 Kyverno Policy Violations Cleanup
**Status:** `in-progress` ← **NEXT ACTION**
**Priority:** Complete before resuming chart updates

Fix all outstanding Kyverno policy violations to establish a clean baseline. Known violations from audit on 2026-04-04:

- `sonarr`, `sabnzbd`, `radarr`, `prowlarr` Deployments — missing `category` label on pod templates (TrueCharts charts don't inject custom labels onto pods; fix via chart values `podLabels`)
- Flux Kustomization CRs — 25/27 missing `app`, `env`, `category` labels
- `shlink` and `shlink-web` Ingress resources — missing all labels
- `portainer` Namespace — non-standard label format
- Verify `actions-runner-system` and `mediastack` Namespace categories are correct after adding `ci` and `media` to valid list

Branch: `chore/fix-kyverno-violations`

---

### 1.5 Flux Image Update Automation
**Status:** `deferred`

Renovate now covers OCI image tag updates via the `flux` manager on `OCIRepository` resources. Flux Image Update Automation adds complexity (additional controllers, ImagePolicy CRDs) for marginal gain. Revisit only if a use case arises that Renovate can't handle.

---

## Phase 2 — Observability Stack

**Goal:** Build a production-grade SRE observability platform to upskill and to support everything that follows (Istio, Chaos Mesh, SLOs).

### 2.1 Prometheus + Grafana (kube-prometheus-stack)
**Status:** `planned`

Deploy `kube-prometheus-stack` to a new `monitoring` namespace:
- Prometheus for metrics scraping
- Grafana for dashboards (behind Authentik SSO once available)
- Alertmanager → delivery target TBD (Ntfy, PushOver, or email)
- ServiceMonitors for existing apps (ingress-nginx, Longhorn, Flux, etc.)

### 2.2 Loki + Promtail
**Status:** `planned`

Log aggregation stack:
- Loki for log storage (S3-backed via MinIO once backup stack is deployed)
- Promtail DaemonSet for log shipping from all nodes
- Grafana Loki data source (integrated with 2.1)

### 2.3 OpenTelemetry Collector
**Status:** `planned`

Deploy the OpenTelemetry Operator + a collector pipeline:
- Receive OTLP traces from instrumented apps
- Export to Jaeger or Tempo (Grafana Tempo preferred for Grafana integration)
- Foundation for Istio distributed tracing

---

## Phase 3 — Security & Access

### 3.1 Authentik — SSO / Identity Provider
**Status:** `planned`

Deploy Authentik as the central IdP:
- OIDC/OAuth2 for all web UIs (Grafana, Longhorn, Capacitor, Homepage, etc.)
- LDAP outpost for apps that don't support OIDC natively
- Forward Auth proxy for apps with no built-in auth
- Requires PostgreSQL (Bitnami subchart or shared instance TBD)

---

## Phase 4 — Service Mesh

### 4.1 Istio
**Status:** `planned` (depends on Phase 2 observability being in place)

Deploy Istio via the Helm-based install (not `istioctl`):
- Mutual TLS (mTLS) between all services by default
- Traffic management (weighted routing, retries, circuit breaking)
- Integration with Kiali for topology visualization
- Distributed tracing via OTLP → Grafana Tempo

Note: Istio's sidecar injection will interact with Kyverno policies — review `kyverno.md` before deploying.

---

## Phase 5 — SRE Practice

### 5.1 SLOTH — SLO-based Alerting
**Status:** `planned` (depends on Phase 2.1 Prometheus)

Use SLOTH to generate SLO alert rules from a declarative YAML spec:
- Define SLIs/SLOs for key services (ingress latency, Shlink availability, etc.)
- SLOTH generates Prometheus recording rules + multi-burn-rate alerts
- Dashboards in Grafana

### 5.2 Chaos Mesh
**Status:** `planned` (depends on Phase 2 observability)

Controlled fault injection for resilience testing:
- Pod kill, network partition, CPU/memory stress experiments
- Scheduled chaos experiments via CronWorkflow
- Dashboards to verify SLOs hold under fault conditions

---

## Phase 6 — Node Maintenance Window

**Status:** `planned` (depends on Phase 2 observability being in place for monitoring during maintenance)
**Risk:** Medium — rolling node reboots; cluster should stay available if done one node at a time

Normalize all nodes to current versions before the CNI migration. Current state (as of 2026-04-01):

| Node | k8s | Kernel | Ubuntu |
|---|---|---|---|
| k8scp01 | v1.32.3 | 6.8.0-106 | 24.04.2 |
| k8scp02 | v1.32.3 | 6.8.0-85 | 24.04.1 |
| k8scp03 | v1.32.3 | 6.8.0-87 | 24.04.1 |
| k8sworker01 | v1.32.3 | 6.8.0-79 | 24.04.1 |
| k8sworker02 | v1.32.3 | 6.8.0-84 | 24.04.1 |
| k8sworker03 | v1.32.3 | 6.8.0-87 | 24.04.1 |
| k8sworker04 | v1.32.3 | 6.8.0-106 | 24.04.1 |
| k8sworker05 | v1.32.9 | 6.8.0-87 | 24.04.3 |
| k8sworker06 | v1.32.3 | 6.8.0-106 | 24.04.1 |

Scope:
- Upgrade all nodes to the latest Kubernetes 1.32.x patch (or latest stable minor if 1.33+ is current)
- `apt upgrade` on all nodes to normalize Ubuntu patch levels and kernel versions
- Upgrade containerd if a newer stable version is available (currently 1.7.27 across all nodes)
- Drain → upgrade → reboot → uncordon, one node at a time
- Control plane nodes first, workers after

Do not bundle this with the Cilium migration — they should be separate maintenance windows.

---

## Phase 7 — CNI Migration (Calico → Cilium)

**Status:** `planned`
**Depends on:** 1.1 test restore validated, 1.3 Renovate, 1.4 Flux Image Automation, Phase 2 observability (2.1 + 2.2 minimum), Phase 6 node maintenance complete
**Risk:** High — CNI replacement requires a full cluster maintenance window

Cilium offers significant advantages over Calico for this use case:
- **Hubble** — built-in L4/L7 network observability (flows, DNS, HTTP)
- eBPF-native (better performance, richer policy)
- Native Gateway API support
- Industry direction for SRE/platform engineering roles

Migration approach:
1. Confirm Velero backups are healthy and a test restore has been validated
2. Confirm Phase 2 observability is in place (Prometheus + Loki at minimum)
3. Confirm all nodes are on current, normalized versions (Phase 6)
4. Plan a maintenance window
5. Drain nodes, uninstall Calico, install Cilium
6. Validate network policies and DMZ rules (especially DMZ namespace on k8sworker05)
7. Update `bootstrap/calico/` → `bootstrap/cilium/` references

This is a cluster rebuild risk event — do not attempt without working backups.

---

## Deferred / Under Evaluation

| Item | Notes |
|---|---|
| Dynatrace / Dash0 | Evaluate after homegrown observability stack is established |
| Tekton | Not needed for dependency updates (Renovate covers that); revisit if building/pushing custom images |
| ELK (Elasticsearch/Kibana) | ECK is already deployed; evaluate whether Loki replaces it or both coexist |
| Crossplane | Potential future IaC-as-Kubernetes for cloud resources |

---

## Completed

| Item | PR / Notes |
|---|---|
| Shlink short link service | Deployed with `vollm.in`, `go.vollminlab.com`, `vl.vollminlab.com` |
| Internal CA issuer | 10-year cert, `internal-ca` ClusterIssuer |
| ARC runner pool cleanup | Removed pool-2, pool-1 bumped to 3 replicas |
| ARC migration to OCIRepository | Migrated `arc-repo` HelmRepository type:oci to two OCIRepository resources (arc-controller-repo, arc-runners-repo) per Flux best practice |
| Renovate Bot | Deployed as CronJob, nightly, covers HelmRelease + OCIRepository + GitHub Actions |
| HelmRepository naming convention | Renamed minio/velero/shlink to use -repo suffix; documented convention in flux.md |
| Kyverno category expansion | Added `media` and `ci` as valid category values |
| Sealed Secrets | Bootstrap procedure + 1Password key backup |
| DMZ namespace + Minecraft | Node-isolated on k8sworker05, Kyverno-enforced |
