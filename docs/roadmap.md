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
- Circular backup fixed (PR #410): `minio` namespace excluded from FSB on both schedules; first clean `Completed` backup expected 2026-04-23 02:00 UTC
- **Still needed:** run a test restore and document the procedure in `docs/`
- **Still needed:** scoped MinIO access key for Velero (currently uses root credentials) — tracked in `chore/velero-minio-access-key`

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

Flux IUA's value is specifically for clusters that build and push custom container images — it scans a registry, detects new tags, and commits the update back to Git automatically (zero-touch CD for custom images). This cluster runs exclusively upstream Helm charts; Renovate already handles version bumps with human review, which is preferable. Revisit only if a CI pipeline starts building and pushing custom images.

---

## Phase 2 — Observability Stack

**Goal:** Build a production-grade SRE observability platform to upskill and to support everything that follows (Istio, Chaos Mesh, SLOs).

### 2.1 Prometheus + Grafana (kube-prometheus-stack)

**Status:** `done`

`kube-prometheus-stack` deployed in `monitoring` namespace:

- Prometheus scraping cluster metrics, Grafana as the unified UI, Alertmanager → Pushover notifications via SealedSecret
- ServiceMonitors: ingress-nginx (built-in), Longhorn, Velero, cert-manager
- Control plane metrics: etcd, controller-manager, scheduler, kube-proxy all bound to `0.0.0.0` and scraped
- Node-exporter hostname relabeling: `instance` label is node hostname, not `ip:port`
- Custom `PrometheusRule`: cert-manager certificate expiry (14d warning / 24h critical), Velero backup overdue/failed/metric-missing
- Dashboards: arr-media (Radarr/Sonarr/Bazarr consolidated), exportarr (Radarr/Sonarr/Bazarr/SABnzbd), Longhorn (custom sidecar), Velero (custom sidecar)

### 2.2 Loki + Promtail

**Status:** `done`

- Loki (SingleBinary mode) deployed, MinIO-backed object storage
- Promtail DaemonSet shipping logs from all nodes
- Grafana Loki data source configured and integrated with Grafana from 2.1

### 2.3 OpenTelemetry Collector

**Status:** `planned` (deploy after Phase 5 Istio)

Deploy the OpenTelemetry Operator + a collector pipeline:

- Receive OTLP traces from instrumented apps and Istio
- Export to Grafana Tempo (preferred for Grafana integration)
- Foundation for distributed tracing across the service mesh

---

## Phase 2.5 — Flux Upgrade (v2.4 → v2.8)

**Status:** `planned`
**Depends on:** Phase 2 observability complete (done)
**Risk:** Low — two-hop upgrade with manifest migration; cluster stays up throughout

Cluster currently runs Flux v2.4.0. Latest stable is v2.8.x. Deprecated APIs generate continuous Kyverno log warnings about invalid `apiVersion` values, and will be hard-removed in future releases.

**Two hops required** (cannot skip):

1. v2.4 → v2.7: removes `Kustomization v1beta1`, `Provider v1beta2/v2beta1` — run `flux migrate` first
2. v2.7 → v2.8: removes `OCIRepository v1beta2`, `HelmChart v1beta2`, `GitRepository v1beta2` — 11 `OCIRepository` files in this repo need migration (handled by `flux migrate` automatically)

**Kubernetes compatibility:** v1.32.3 meets v2.8 minimum.

**Procedure per hop:** migrate manifests PR → merge → upgrade `gotk-components.yaml` PR → merge → verify reconciliation before next hop. Do not bundle with other work.

---

## Phase 3 — Security & Access

### 3.0 PKI — Automated Certificate Lifecycle

**Status:** `planned`

Control plane certs issued by kubeadm expire annually and require manual renewal on each control plane node. This became an incident on 2026-04-14 when all certs expired simultaneously.

**Hard deadline:** Next expiry is **2027-04-14**. Emergency renewal procedure until automated:

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

### 3.2 MetalLB: L2 → BGP Peering

**Status:** `planned` (low priority — discuss before Phase 8 Cilium migration)

**Problem:** k8sworker04 shows the MetalLB VIP (ingress-nginx LoadBalancer IP) in the UDM console instead of its actual node IP. In L2 mode, MetalLB answers ARP for VIPs from whichever node is the current leader; the UDM sees this ARP and maps that node's MAC to the VIP address, shadowing the real node IP.

**Fix:** Switch MetalLB from L2 advertisement to BGP peering with the UDM Pro. MetalLB advertises VIP routes over BGP; the router learns them as routes (not ARP entries) and routes VIP traffic at L3. Node IPs are unaffected. Also enables ECMP across multiple nodes for better load distribution.

**Note on Cilium overlap:** Cilium (Phase 8) has native BGP support (`CiliumBGPPeeringPolicy`) and a built-in L4LB that can replace MetalLB entirely. If Phase 8 is imminent, it may be cleaner to skip this and migrate BGP as part of the Cilium rollout. Decide at the start of Phase 8 planning.

---

### 3.3 Personal Media Services — External Access (Plex + Overseerr)

**Status:** `planned` (architectural decision required — DMZ isolation constraint applies)

**Goal:** Make Plex and Overseerr accessible to friends and family externally, without disrupting local use.

**Hard constraint:** The DMZ is fully isolated from the internal network by design. No DMZ pod may initiate connections to internal LAN hosts or internal-cluster namespaces. This rules out any approach that puts Plex or Overseerr in the DMZ and has them reach back to TrueNAS (media) or the arr stack (Radarr/Sonarr/Prowlarr). Any solution must work with that isolation preserved.

#### The core problem

Both services have hard dependencies on internal resources:

- **Plex** needs direct filesystem access to the media library on TrueNAS
- **Overseerr** needs to call Radarr, Sonarr, Prowlarr, and Plex — all in `mediastack`

Neither can run in an isolated DMZ without solving this. The viable approaches are:

---

##### Option A — Cloudflare Tunnel (recommended)

Run `cloudflared` as a Deployment inside the internal cluster (in `mediastack` or a new `cloudflared` namespace). It creates an outbound-only connection to Cloudflare's edge — no inbound ports, no DMZ involvement, no internal network exposure. Visitors hit `plex.vollminlab.com` → Cloudflare edge → tunnel → internal Plex on TrueNAS (or Overseerr in mediastack).

- Cloudflare Access gates both services with SSO (email-based invites for friends/family)
- Zero impact on DMZ isolation — cloudflared runs inside the trusted internal network
- No dependency on Authentik being ready
- Plex stays on TrueNAS; Overseerr stays in mediastack — no migration needed
- Tradeoff: Cloudflare sits in the traffic path; free tier has bandwidth limits on some features

---

##### Option B — Dedicated storage VLAN

Add TrueNAS to a separate storage VLAN that DMZ workers (k8sworker05/06) also have access to. Plex and Overseerr run in the `dmz` namespace; media mounts come over the storage VLAN, not the main internal LAN. Arr stack connections from Overseerr → mediastack would still require a separate solution (either a storage VLAN for data + a message queue for requests, or accepting Overseerr can't be fully in DMZ).

- Requires UDM VLAN configuration and TrueNAS network interface changes
- True isolation preserved: DMZ workers connect to a dedicated storage network, not the internal LAN
- High complexity for what is essentially a personal use case
- Better long-term fit if storage VLAN is needed for other reasons anyway

---

##### Option C — UDM port forward (simple, no K8s changes)

Port forward 32400 on the UDM directly to TrueNAS. Friends connect to your external IP or a dynamic DNS hostname. No DMZ, no cluster involvement.

- No security model changes, no migration
- Exposes TrueNAS directly to the internet — depends entirely on Plex's own auth
- Overseerr would need a separate port forward; no SSO gating
- Fine as a stopgap but not the right long-term answer given the security posture of this cluster

---

#### Decision needed before implementation

1. **Preferred approach:** Cloudflare Tunnel (Option A) is the most consistent with the existing security model and requires the least new infrastructure. Decide whether to run `cloudflared` in-cluster (Flux-managed) or on TrueNAS directly.
2. **Overseerr capacity gate:** Before enabling external requests, audit TrueNAS free space and set per-user request quotas in Overseerr to prevent runaway downloads.
3. **Plex migration question:** Regardless of which option is chosen for external access, decide independently whether Plex should eventually migrate from TrueNAS into the cluster (better metrics, GitOps management) or stay on TrueNAS permanently.

---

## Phase 4 — Infrastructure Diagrams

**Goal:** Create living architecture diagrams for every repo in the org once observability and security are settled — so diagrams reflect a stable system and don't need immediate revision.

### 4.0 Diagram Creation — All Repos

**Status:** `planned`

Create a `diagrams/` folder in each repo with declarative Mermaid diagrams covering the full system as it exists at that point. Scope:

- `k8s-vollminlab-cluster` — cluster topology (nodes, namespaces, networking), Flux reconciliation flow, storage layout (Longhorn, MinIO), backup data path (Velero → B2), DMZ isolation
- `homelab-infrastructure` — Terraform resource graph, network topology, VM/node inventory
- `github-admin` — repo/branch protection structure
- Any other repos as they exist

**Format:** `.mmd` files (Mermaid — declarative, committable to Git, rendered natively in GitHub PRs/issues, previewable in VS Code with the Mermaid extension). Matches the declarative/GitOps ethos of the cluster. Diagram types: `graph TD` for topology, `flowchart` for data flows, `sequenceDiagram` for reconciliation flows.

**Maintenance:** diagrams live in `<repo>/diagrams/` and are updated as the system changes.

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

**Status:** `deferred`

Controlled fault injection for resilience testing (pod kill, network partition, CPU/memory stress). No immediate plans — incidents are being handled well without it. Revisit after SLOs (6.1) are established so there are clear baselines to validate against.

---

## Phase 7 — Node Maintenance Window

**Status:** `planned` (depends on Phase 2 observability being in place for monitoring during maintenance)
**Risk:** Medium — rolling node reboots; cluster should stay available if done one node at a time

Normalize all nodes to current versions before the CNI migration. Current state (as of 2026-04-01 — **update table before starting this phase**):

| Node | k8s | Kernel | Ubuntu |
| --- | --- | --- | --- |
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
| --- | --- |
| Dynatrace / Dash0 | Homegrown stack (Prometheus + Loki + Grafana) is now established — evaluate if a managed platform adds value |
| Tekton | Not needed for dependency updates (Renovate covers that); revisit if building/pushing custom images |
| Crossplane | Potential future IaC-as-Kubernetes for cloud resources |

---

## Completed

| Item | PR / Notes |
| --- | --- |
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
| kube-prometheus-stack | Prometheus + Grafana + Alertmanager (→ Pushover) in `monitoring` namespace |
| Loki + Promtail | SingleBinary Loki, MinIO-backed; Promtail DaemonSet on all nodes |
| Control plane metrics | etcd/controller-manager/scheduler/kube-proxy bound to `0.0.0.0` and scraped by Prometheus |
| Observability ServiceMonitors + alert rules | Longhorn, Velero, cert-manager scraped; custom `PrometheusRule` for cert expiry + Velero health (PR #395) |
| Node-exporter hostname relabeling | `instance` label is node hostname instead of IP:port (PR #397) |
| Exportarr | Radarr, Sonarr, Bazarr, SABnzbd exportarr exporters + Grafana dashboards (PRs #393–#394) |
| Grafana dashboards | Arr-media consolidated, Longhorn custom sidecar (PR #419), Velero custom sidecar (PR #420) |
| Etcd defrag CronJob | Weekly defrag job in `kube-system` (PR #413) |
| Velero circular backup fix | `minio` namespace excluded from FSB on both schedules; node-agents healthy on all 6 nodes (PR #410) |
