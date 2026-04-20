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
**Status:** `done`

Fixed all outstanding Kyverno policy violations to establish a clean baseline (PRs #221, #229, 2026-04-04). Label injection via mutate policies, autogen disabled to prevent webhook breakage.

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

## Phase 2.5 — Flux Upgrade (v2.4 → v2.8)

**Status:** `planned` (after Phase 2 observability)
**Depends on:** Phase 2 monitoring stable (want visibility during the upgrade)
**Risk:** Medium — two-hop upgrade with API removals; requires `flux migrate` between hops

Current cluster runs **Flux v2.4.0**. Latest stable is **v2.8.5**. Several deprecated Flux API versions produce log noise and will be hard-removed in newer releases. Direct upgrade is not possible — must hop through v2.7 first.

### Why two hops

| Removed in | APIs dropped |
| --- | --- |
| v2.7.0 | `Kustomization v1beta1`, `Provider v1beta2/v2beta1` |
| v2.8.0 | `OCIRepository v1beta2`, `HelmChart v1beta2`, `GitRepository v1beta2`, `Provider v2beta2` |

### Procedure

#### Hop 1: v2.4 → v2.7

```bash
# Rewrite deprecated apiVersions in Git manifests
flux migrate -f ./clusters/ --from 2.4.0 --to 2.7.0
# Commit + PR the migrated files, then upgrade components:
flux install --version v2.7.5 --export > clusters/vollminlab-cluster/flux-system/gotk-components.yaml
# Commit + PR, verify cluster stable before proceeding
```

#### Hop 2: v2.7 → v2.8

```bash
flux migrate -f ./clusters/ --from 2.7.0 --to 2.8.0
flux install --version v2.8.5 --export > clusters/vollminlab-cluster/flux-system/gotk-components.yaml
# Commit + PR
```

### Known pre-work in this repo

- 11 `OCIRepository` files still on `source.toolkit.fluxcd.io/v1beta2` — `flux migrate` handles these automatically on hop 2
- Kubernetes v1.32.3 meets the v2.8 minimum requirement

---

## Phase 3 — Security & Access

### 3.0 PKI — Automated Certificate Lifecycle

**Status:** `deferred`

Control plane certs issued by kubeadm expire annually and require manual renewal on each control plane node. This became an incident on 2026-04-14 when all certs expired simultaneously.

**Interim:** Next expiry is **2027-04-14**. Until a proper solution is in place, renew manually on each control plane node when prompted:

```bash
sudo kubeadm certs renew all
sudo systemctl restart kubelet
sudo cp /etc/kubernetes/admin.conf ~/.kube/config && sudo chown $(id -u):$(id -g) ~/.kube/config
```

**Long-term options (in order of preference for this homelab):**

1. **cert-manager** — already in-cluster, handles ingress TLS today. Extend it to manage cluster PKI via a `ClusterIssuer` backed by a self-signed or external CA. Certs would auto-rotate before expiry. Most natural fit with no new infrastructure.
2. **HashiCorp Vault** — used in production at work; familiar. Heavier than needed for homelab alone, but worth reconsidering if Vault gets deployed for secrets management more broadly. 1Password already serves a similar role for some use cases.
3. **1Password + cert-manager bridge** — if 1Password is the org-wide secrets store, a cert-manager external issuer or Vault-compatible API could bridge the two.

**Relation to 3.1:** If Vault is chosen as the CA backend, deploy Authentik first for SSO on the Vault UI. The cert-manager path has no such dependency.

---

### 3.1 Authentik — SSO / Identity Provider

**Status:** `planned`

Deploy Authentik as the central IdP:

- OIDC/OAuth2 for all web UIs (Grafana, Longhorn, Capacitor, Homepage, etc.)
- LDAP outpost for apps that don't support OIDC natively
- Forward Auth proxy for apps with no built-in auth
- Requires PostgreSQL (Bitnami subchart or shared instance TBD)

---

## Phase 4 — Infrastructure Diagrams

**Goal:** Create living architecture diagrams for every repo in the org once observability and security are settled — so diagrams reflect a stable system and don't need immediate revision.

### 4.0 Diagram Creation — All Repos

**Status:** `planned`

Create an Excalidraw-based `diagrams/` folder in each repo with architecture diagrams covering the full system as it exists at that point. Scope:

- `k8s-vollminlab-cluster` — cluster topology (nodes, namespaces, networking), Flux reconciliation flow, storage layout (Longhorn, MinIO), backup data path (Velero → B2), DMZ isolation
- `homelab-infrastructure` — Terraform resource graph, network topology, VM/node inventory
- `github-admin` — repo/branch protection structure
- Any other repos as they exist

**Format:** `.excalidraw` files (JSON, committable to Git and viewable in VS Code via Excalidraw extension or on excalidraw.com). Optionally export `.svg` alongside for quick previewing in GitHub.

**Maintenance:** diagrams live in `<repo>/diagrams/` and are updated as the system changes — not generated, hand-authored.

---

## Phase 5 — Service Mesh

### 5.1 Istio
**Status:** `planned` (depends on Phase 2 observability being in place)

Deploy Istio via the Helm-based install (not `istioctl`):
- Mutual TLS (mTLS) between all services by default
- Traffic management (weighted routing, retries, circuit breaking)
- Integration with Kiali for topology visualization
- Distributed tracing via OTLP → Grafana Tempo

Note: Istio's sidecar injection will interact with Kyverno policies — review `kyverno.md` before deploying.

---

## Phase 6 — SRE Practice

### 6.1 SLOTH — SLO-based Alerting
**Status:** `planned` (depends on Phase 2.1 Prometheus)

Use SLOTH to generate SLO alert rules from a declarative YAML spec:
- Define SLIs/SLOs for key services (ingress latency, Shlink availability, etc.)
- SLOTH generates Prometheus recording rules + multi-burn-rate alerts
- Dashboards in Grafana

### 6.2 Chaos Mesh
**Status:** `planned` (depends on Phase 2 observability)

Controlled fault injection for resilience testing:
- Pod kill, network partition, CPU/memory stress experiments
- Scheduled chaos experiments via CronWorkflow
- Dashboards to verify SLOs hold under fault conditions

---

## Phase 7 — Node Maintenance Window

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

## Phase 8 — CNI Migration (Calico → Cilium)

**Status:** `planned`
**Depends on:** 1.1 test restore validated, Phase 2 observability (2.1 + 2.2 minimum), Phase 7 node maintenance complete
**Risk:** High — CNI replacement requires a full cluster maintenance window

Cilium offers significant advantages over Calico for this use case:
- **Hubble** — built-in L4/L7 network observability (flows, DNS, HTTP)
- eBPF-native (better performance, richer policy)
- Native Gateway API support
- Industry direction for SRE/platform engineering roles

Migration approach:
1. Confirm Velero backups are healthy and a test restore has been validated
2. Confirm Phase 2 observability is in place (Prometheus + Loki at minimum)
3. Confirm all nodes are on current, normalized versions (Phase 7)
4. Plan a maintenance window
5. Drain nodes, uninstall Calico, install Cilium
6. Validate network policies and DMZ rules (especially DMZ namespace on k8sworker05)
7. Update `bootstrap/calico/` → `bootstrap/cilium/` references

This is a cluster rebuild risk event — do not attempt without working backups.

---

## Deferred / Under Evaluation

| Item | Notes |
|---|---|
| Longhorn dedicated disks per worker | `/var/lib/longhorn` sits on root LVM (`ubuntu-vg/ubuntu-lv`); Longhorn can't resolve the LVM device in sysfs from inside its container, producing periodic `collectNodeDiskCount` warnings. Fix: provision a dedicated partition or disk on each worker and configure it as a Longhorn disk. Node-level change, not a Helm fix. |
| Dynatrace / Dash0 | Evaluate after homegrown observability stack is established |
| Tekton | Not needed for dependency updates (Renovate covers that); revisit if building/pushing custom images |
| ELK (Elasticsearch/Kibana) | ECK is already deployed; evaluate whether Loki replaces it or both coexist |
| Crossplane | Potential future IaC-as-Kubernetes for cloud resources |

---

## Completed

| Item | PR / Notes |
|---|---|
| Kyverno policy violations cleanup | PRs #221, #229 — label injection via mutate policies, autogen disabled |
| Shlink Ingress Controller | Custom Go controller: Ingress annotation → auto-create `vollm.in/<slug>` via Shlink API |
| Shlink short link service | Deployed with `vollm.in`, `go.vollminlab.com`, `vl.vollminlab.com` |
| Internal CA issuer | 10-year cert, `internal-ca` ClusterIssuer |
| ARC runner pool cleanup | Removed pool-2, pool-1 bumped to 3 replicas |
| ARC migration to OCIRepository | Migrated `arc-repo` HelmRepository type:oci to two OCIRepository resources (arc-controller-repo, arc-runners-repo) per Flux best practice |
| Renovate Bot | Deployed as CronJob, nightly, covers HelmRelease + OCIRepository + GitHub Actions |
| HelmRepository naming convention | Renamed minio/velero/shlink to use -repo suffix; documented convention in flux.md |
| Kyverno category expansion | Added `media` and `ci` as valid category values |
| Sealed Secrets | Bootstrap procedure + 1Password key backup |
| DMZ namespace + Minecraft | Node-isolated on k8sworker05, Kyverno-enforced |
