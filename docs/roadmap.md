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
- Circular backup fixed (PR #410): `minio` namespace excluded from FSB on both schedules
- Scoped MinIO access key for Velero deployed (PR #362) — root credentials no longer used
- **Still needed:** run a test restore and document the procedure in `docs/` (gate for Phase 8)

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

**Status:** `done`

Cluster upgraded from Flux v2.4.0 to v2.8.6 via two hops (PRs #423, #426, #428).

- 9 OCIRepository files migrated from `source.toolkit.fluxcd.io/v1beta2` → `v1`
- Both hops required manually applying `gotk-components.yaml` with `--server-side --field-manager=kustomize-controller --force-conflicts` to break the bootstrap deadlock (old controller can't apply config that removes its own internal API references)
- Post-hop: patched `ocirepositories` CRD `status.storedVersions` via `--subresource=status` to clear stale `v1beta2` entry

---

## Phase 3 — Security & Access

### 3.0 PKI — Automated Certificate Lifecycle

**Status:** `done` — PR #540

Control plane certs issued by kubeadm expire annually and require manual renewal on each control plane node. This became an incident on 2026-04-14 when all certs expired simultaneously.

**Next expiry: 2027-04-14.** cert-manager cannot write to the control plane node filesystem, so the approach keeps kubeadm as the issuer and wraps the renewal in GitOps-managed CronJobs.

**Implementation (kube-system namespace):**

- `kubeadm-cert-monitor` — monthly CronJob (1st of each month, 09:00 UTC). Uses `kubectl exec` into `kube-apiserver-*` and `etcd-*` static pods to check cert expiry via openssl. Sends Pushover alert at 90-day warning / 30-day critical. No hostPath required.
- `kubeadm-cert-renew-k8scp01/02/03` — three bi-annual CronJobs (April 14 + October 14, staggered 15 min apart). Uses `nsenter -t 1` to enter host namespaces and run `kubeadm certs renew all` + `systemctl restart kubelet`. Sends Pushover notification on success or differentiated alerts on partial failure.
- `exceptions-kubeadm-cert-renew` Kyverno `PolicyException` — preemptively exempts renewal pods from `restrict-privileged` and `restrict-hostpath-usage` policies in case `kube-system` is ever removed from those policies' exclude lists.

---

### 3.1 Authentik — SSO / Identity Provider

**Status:** `in-progress` — phases 1–5b complete, 5c and 6 remaining

Design doc: `docs/authentik-design.md`.

- **Phase 1** `done` — Core infra: shared Redis (`redis` ns), CNPG Cluster CR, Authentik server+worker, cloudflared tunnel for `auth.vollminlab.com`
- **Phase 2** `done` — External proxy outpost + Jellyseerr (replaces Overseerr) + Jellyfin OIDC. Plex decommissioned; Jellyfin stable.
- **Phase 3** `done` — Native OIDC: Grafana, Harbor, Headlamp, Portainer, Audiobookshelf, MinIO
- **Phase 4** `done` — Forward-auth sweep: Longhorn, Homepage, arr stack, Tautulli, Shlink Web, Policy Reporter
- **Phase 5a** `done` — tofu-controller deployed in `tofu` ns; MinIO `terraform-state` bucket + scoped IAM user (PRs #539)
- **Phase 5b** `done` — Full Authentik config under OpenTofu IaC: groups, users, OAuth2/proxy providers, scope mappings, applications, outpost, Portainer OAuth settings. All existing objects imported into state. Client secrets sealed. Post-merge fixes: cross-namespace refs (`allowCrossNamespaceRefs: true`, PR #547), flux-system NetworkPolicy for tofu→source-controller (PR #548, #549), Authentik provider 2026.2.x schema (`invalidation_flow` required, `redirect_uris`→`allowed_redirect_uris`, portainer `api_user`/`api_password`, PR #550, #551). tofu-controller reconciling cleanly. (PRs #542, #546–#551)
- **Phase 5c** `planned` — Extend IaC to MinIO (buckets, IAM users/policies), Harbor (OIDC config, projects, robot accounts), and Grafana (OAuth, notification policies, contact points). Add `terraform fmt --check` + `tofu validate` CI workflow for `terraform/**` PRs.
- **Phase 6** `planned` — NPM-proxied external services via Authentik `auth_request`: Pi-hole, TrueNAS, HAProxy, NPM itself. vCenter via native OIDC.

---

### 3.2 MetalLB: L2 → BGP Peering

**Status:** `planned` (low priority — discuss before Phase 8 Cilium migration)

**Problem:** k8sworker04 shows the MetalLB VIP (ingress-nginx LoadBalancer IP) in the UDM console instead of its actual node IP. In L2 mode, MetalLB answers ARP for VIPs from whichever node is the current leader; the UDM sees this ARP and maps that node's MAC to the VIP address, shadowing the real node IP.

**Fix:** Switch MetalLB from L2 advertisement to BGP peering with the UDM Pro. MetalLB advertises VIP routes over BGP; the router learns them as routes (not ARP entries) and routes VIP traffic at L3. Node IPs are unaffected. Also enables ECMP across multiple nodes for better load distribution.

**Note on Cilium overlap:** Cilium (Phase 8) has native BGP support (`CiliumBGPPeeringPolicy`) and a built-in L4LB that can replace MetalLB entirely. If Phase 8 is imminent, it may be cleaner to skip this and migrate BGP as part of the Cilium rollout. Decide at the start of Phase 8 planning.

---

### 3.3 Personal Media Services — External Access (Plex)

**Status:** `done`

- Plex migrated from TrueNAS into `mediastack` namespace (PRs #439, #442). Media files via existing SMB CSI mounts (`pvc-movies`, `pvc-tv`). 20Gi Longhorn PVC for config/metadata.
- `cloudflared` deployed as a plain Deployment in `mediastack` (PR #440). Tunnel connects outbound to Cloudflare edge; routes `plex.vollminlab.com → http://plex.mediastack.svc.cluster.local:32400`.
- Plex's own auth (myPlex accounts) is the sole access gate — no Cloudflare Access policy. Remote access disabled in Plex; port 32400 confirmed closed on public IP.
- Pi-hole DNS updated: `plex.vollminlab.com → 192.168.152.244`. TrueNAS Plex shut down.
- Overseerr remains internal-only. Can be added to tunnel via Cloudflare dashboard with no code changes.

### 3.4 Jellyfin — Free External Streaming for Friends

**Status:** `done`

- Jellyfin deployed in `mediastack` alongside Plex. Official `jellyfin/jellyfin` chart v3.2.0.
- Shares `pvc-movies` and `pvc-tv` SMB RWX mounts with Plex (read-only access, UID/GID 568).
- Dedicated `pvc-jellyfin-config` 20Gi Longhorn RWO.
- Separate `cloudflared-jellyfin` Deployment with its own tunnel — independent blast-radius from Plex.
- Route: `jellyfin.vollminlab.com → http://jellyfin.mediastack.svc.cluster.local:8096`.
- Security gate: Jellyfin built-in auth only. No Cloudflare Access policy (native apps cannot complete browser auth challenge). Public signup disabled; accounts managed manually.
- Hardware transcoding deferred — CPU only. See roadmap for follow-up.

**Deferred follow-ups:**

- Hardware transcoding (`/dev/dri` device mount) — requires evaluating Kyverno `hostPath` audit policy impact
- Jellyfin metrics / Grafana dashboard (parallel to Tautulli work in 3.5)

### 3.5 Tautulli / Plex Metrics Dashboard

**Status:** `done`

Tautulli deployed in `mediastack`. Metrics dashboard complete.

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
| Velero scoped MinIO access key | Replaced root credentials with a least-privilege `velero-svc` MinIO key (PR #362) |
| Flux upgrade v2.4 → v2.8 | Two-hop upgrade via PRs #423, #426, #428; 9 OCIRepository files migrated to v1; bootstrap deadlock fix documented |
| Plex in-cluster + Cloudflare Tunnel | Plex migrated from TrueNAS (PRs #439, #440, #442); outbound-only tunnel, no open ports, Plex auth as sole gate |
