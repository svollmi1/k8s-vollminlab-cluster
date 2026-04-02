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

Migrated to ARC v2 (`gha-runner-scale-set-controller` + `AutoscalingRunnerSet`). Legacy summerwind resources removed.

---

### 1.3 Renovate Bot — Automated Helm Chart Updates
**Status:** `planned`
**Priority:** High — complete before Cilium migration

Install Renovate Bot as a GitHub App on `svollmi1/k8s-vollminlab-cluster`. Configure `renovate.json` to:
- Watch `HelmRelease` chart versions across all namespaces
- Open PRs when upstream Helm chart versions are published
- Auto-merge patch-level updates (optional, after observability is in place)

Covers Helm chart version bumps only. Raw container image tag updates are handled by Flux Image Update Automation (1.4).

---

### 1.4 Flux Image Update Automation
**Status:** `planned`
**Priority:** High — complete before Cilium migration; pair with 1.3

Automates container image tag updates directly in git without opening PRs. Complements Renovate (which handles chart versions) for any workloads with raw image references.

Components:
- `image-reflector-controller` — polls image registries, stores tag metadata
- `image-automation-controller` — commits image tag updates to git when tags match a policy
- `ImageRepository` + `ImagePolicy` + `ImageUpdateAutomation` CRDs per tracked image

**Prerequisite:** both controllers must be enabled in the Flux bootstrap — they are not installed by default. Add `--components-extra=image-reflector-controller,image-automation-controller` to the bootstrap or patch the `flux-system` kustomization.

Reference: https://fluxcd.io/flux/guides/image-update/

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

## Phase 6 — CNI Migration (Calico → Cilium)

**Status:** `planned` (depends on: 1.1 backups validated with a test restore, 1.3 Renovate, and 1.4 Flux Image Automation in place)
**Risk:** High — CNI replacement requires controlled cluster-level maintenance

Cilium offers significant advantages over Calico for this use case:
- **Hubble** — built-in L4/L7 network observability (flows, DNS, HTTP)
- eBPF-native (better performance, richer policy)
- Native Gateway API support
- Industry direction for SRE/platform engineering roles

Migration approach:
1. Ensure Velero backups are healthy and a test restore has been validated
2. Plan a maintenance window
3. Drain nodes, uninstall Calico, install Cilium
4. Validate network policies and DMZ rules
5. Update `bootstrap/calico/` → `bootstrap/cilium/` references

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
| Sealed Secrets | Bootstrap procedure + 1Password key backup |
| DMZ namespace + Minecraft | Node-isolated on k8sworker05, Kyverno-enforced |
