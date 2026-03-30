# Vollminlab Cluster Roadmap

Living document tracking planned infrastructure work. Update status as projects progress.

**Status key:** `planned` | `in-progress` | `done` | `blocked` | `deferred`

---

## Phase 1 — Foundations (Prerequisite for everything else)

### 1.1 Backup Stack — MinIO + Velero + Backblaze B2
**Status:** `planned`
**Priority:** CRITICAL — no backups currently exist

Deploy a full backup pipeline for the cluster:
- **MinIO** — S3-compatible object store running in-cluster as the local backup target
- **Velero** — Kubernetes backup/restore operator; backs up PVCs (via Longhorn CSI snapshots) and all Kubernetes resources
- **Backblaze B2** — Off-site cold storage; MinIO replicates to B2 for durability

Scope:
- MinIO deployed via Helm to a dedicated `backup` namespace
- Velero BackupStorageLocation pointed at MinIO
- MinIO configured with B2 as a remote tier (object lifecycle policy)
- Daily full cluster backup schedule
- Test restore procedure documented in `docs/`

Decisions to make:
- Which namespaces/PVCs are in scope for backup vs. recoverable-from-GitOps
- B2 bucket naming and access credentials (SealedSecret)
- Retention policy (e.g. 30 daily, 12 monthly)

---

### 1.2 GitHub Actions Runner Migration
**Status:** `planned`
**Priority:** High — current ARC (actions-runner-controller) is on the legacy `summerwind` image

Migrate from legacy `summerwind/actions-runner` to the new ARC (Actions Runner Controller) v2 stack:
- New controller: `gha-runner-scale-set-controller`
- New runner sets: `AutoscalingRunnerSet` CRDs replacing `RunnerDeployment`
- Ephemeral runner pods with `dind` or Kubernetes-mode container builds

Reference: [actions/actions-runner-controller](https://github.com/actions/actions-runner-controller)

---

### 1.3 Renovate Bot — Automated Dependency Updates
**Status:** `planned`
**Priority:** High

Install Renovate Bot as a GitHub App on `svollmi1/k8s-vollminlab-cluster`. Configure `renovate.json` to:
- Watch `HelmRelease` chart versions across all namespaces
- Open PRs when upstream Helm chart versions are published
- Pin digest-based image updates where applicable
- Auto-merge patch-level updates (optional, after observability is in place)

This replaces manual chart version tracking entirely.

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

**Status:** `planned` (depends on Phase 1.1 backups — needs recovery path)
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
