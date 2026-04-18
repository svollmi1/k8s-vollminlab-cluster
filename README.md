# Vollminlab Kubernetes Cluster

GitOps-managed bare-metal Kubernetes cluster. All workloads are defined as code in this repository and reconciled continuously by Flux CD.

> **Full configuration reference:** [docs/cluster-reference.md](docs/cluster-reference.md) — versions, resource limits, network policies, storage layout, and every configured value in excruciating detail.

---

## Architecture Overview

| Layer | Tool | Role |
|---|---|---|
| Orchestration | Kubernetes (kubeadm) | Cluster control plane |
| CNI | Calico v3.29.1 | Pod networking, BGP, IPIP |
| GitOps | Flux CD | Continuous reconciliation from `main` |
| Helm management | Flux HelmRelease | All app deployments |
| Secret management | Sealed Secrets | Encrypted secrets committed to Git |
| Policy enforcement | Kyverno | Admission control (enforce mode) |
| Ingress | ingress-nginx | HTTP/HTTPS routing |
| Certificates | cert-manager | TLS automation |
| Load balancing | MetalLB | Bare-metal LoadBalancer services |
| Block storage | Longhorn | Distributed RWO + RWX volumes |
| File storage | SMB CSI Driver | SMB/CIFS network shares |
| CI | GitHub Actions | Manifest validation + policy checks |

---

## Repository Structure

```
bootstrap/                              # Manual bootstrap only — NOT Flux-managed
  calico/                               # Calico CNI install reference (apply before Flux)
  coredns/                              # CoreDNS config reference
  sealed-secrets/                       # Sealing key disaster recovery guide

clusters/vollminlab-cluster/            # Everything Flux reconciles
  flux-system/
    repositories/                       # 24 HelmRepositories + 1 GitRepository
    flux-kustomizations/                # Flux Kustomization CRs (one per app/namespace)
  actions-runner-system/                # GitHub Actions self-hosted runners
  cert-manager/                         # TLS certificate automation
  clusterwide/                          # PersistentVolumes, StorageClasses, RBAC
  dmz/                                  # Internet-exposed workloads (Minecraft)
  elastic-system/                       # ECK Operator
  flux-system/                          # Flux controllers + sync config
  homepage/                             # Homepage dashboard
  ingress-nginx/                        # Ingress controller
  kube-system/                          # metrics-server, smb-csi-driver
  kyverno/                              # Policy engine + 12 ClusterPolicies + policy-reporter
  local-path-storage/                   # Node-local storage provisioner
  longhorn-system/                      # Distributed block storage
  mediastack/                           # Sonarr, Radarr, Bazarr, Prowlarr, SABnzbd, Overseerr, Tautulli
  metallb-system/                       # Bare-metal load balancer
  monitoring/                           # Monitoring stack (in progress)
  portainer/                            # Container management UI
  sealed-secrets/                       # Sealed secrets controller

scripts/                                # Utility scripts
```

---

## Deployed Applications

### Core Infrastructure

| App | Namespace | Chart Version | Purpose |
|---|---|---|---|
| Flux CD | flux-system | — | GitOps reconciliation |
| Capacitor | flux-system | latest | Flux UI dashboard |
| Kyverno | kyverno | v3.4.1 | Policy enforcement |
| Policy Reporter | kyverno | ~v16 | Policy violation reporting |
| ingress-nginx | ingress-nginx | v4.12.0 | Ingress controller |
| cert-manager | cert-manager | v1.16.3 | TLS certificates |
| MetalLB | metallb-system | — | LoadBalancer IPs |
| Sealed Secrets | sealed-secrets | — | Git-safe secrets |
| metrics-server | kube-system | v3.12.2 | Resource metrics API |
| ECK Operator | elastic-system | v2.16.1 | Elasticsearch on K8s |

### Storage

| App | Namespace | Purpose |
|---|---|---|
| Longhorn | longhorn-system | Distributed block storage (RWO + RWX) |
| SMB CSI Driver | kube-system | v1.17.0 — SMB/CIFS network shares |
| Local Path Provisioner | local-path-storage | Node-local ephemeral storage |

### Applications

| App | Namespace | Purpose |
|---|---|---|
| Homepage | homepage | v2.1.0 — Cluster dashboard |
| Portainer | portainer | Container management UI |
| Overseerr | mediastack | Media request management |
| Sonarr | mediastack | TV series automation |
| Radarr | mediastack | Movie automation |
| Bazarr | mediastack | Subtitle management |
| Prowlarr | mediastack | Indexer aggregation |
| SABnzbd | mediastack | Usenet downloader |
| Tautulli | mediastack | Plex monitoring |
| Minecraft | dmz | Game server (internet-exposed, DMZ isolated) |

### CI/CD

| App | Namespace | Purpose |
|---|---|---|
| Actions Runner Controller | actions-runner-system | v0.23.7 — Self-hosted GitHub Actions runners |

---

## Cluster Bootstrap Order

For a full cluster rebuild, follow this order exactly:

```
1. Install Kubernetes control plane (kubeadm)
2. Install Calico CNI             → see bootstrap/calico/README.md
3. Restore sealed-secrets key     → see bootstrap/sealed-secrets/README.md
4. Bootstrap Flux CD              → flux bootstrap github ...
5. Everything else                → Flux reconciles automatically
```

**Steps 2 and 3 must happen before Flux bootstraps.** Calico is required for pod networking; the sealing key must exist before the sealed-secrets controller starts, or all SealedSecrets become permanently unreadable.

---

## Network Configuration

| Parameter | Value |
|---|---|
| Pod CIDR | `172.18.0.0/16` |
| CNI | Calico (IPIP encapsulation, BGP enabled) |
| Dataplane | iptables |
| Control plane replicas | 3 |
| DMZ nodes | `k8sworker05`, `k8sworker06` (taint: `dmz=true:NoSchedule`) |

---

## Security Model

### Kyverno Policies (enforce mode)

| Policy | Action | Rule |
|---|---|---|
| restrict-default | Block | No workloads in `default` namespace |
| require-labels | Block | All pods need `app`, `env`, `category` labels |
| require-resources | Block | CPU/memory requests and limits required |
| inject-resource-requirements | Mutate | Auto-inject default limits |
| restrict-privileged | Block | No privileged containers |
| restrict-hostpath | Block | No hostPath volumes |
| restrict-latest-tag | Block | No `:latest` image tags |
| inject-namespace-labels | Mutate | Auto-label namespaces |
| dmz-enforce-node-placement | Mutate | DMZ pods auto-targeted to DMZ node |
| dmz-restrict-external-access | Block | External access labels only allowed in `dmz/` |

### DMZ Isolation

The `dmz/` namespace is a security boundary for internet-exposed workloads. See [clusters/vollminlab-cluster/dmz/README.md](clusters/vollminlab-cluster/dmz/README.md) for the full security model.

- Dedicated nodes (`k8sworker05`, `k8sworker06`) with `dmz=true:NoSchedule` taint
- Kyverno auto-enforces node placement for all dmz pods
- Default-deny NetworkPolicy with explicit allow rules only
- Dedicated `longhorn-dmz` StorageClass for node-local storage isolation

### Secret Management

All secrets are encrypted as `SealedSecret` resources before committing to Git. The sealing key is cluster-specific and backed up in 1Password (`Sealed Secrets Sealing Key`). See [bootstrap/sealed-secrets/README.md](bootstrap/sealed-secrets/README.md).

---

## Making Changes

```
1. Create a branch from main
2. Make changes
3. Push — CI runs automatically (manifest validation, Kyverno checks, Trivy scan)
4. Open a PR — requires CI to pass + 1 review
5. Merge to main — Flux reconciles within 10 minutes
```

Direct pushes to `main` are blocked. Branch protection is enforced via GitHub repository settings.

---

## Adding a New Application

1. Create the namespace directory: `clusters/vollminlab-cluster/[namespace]/`
2. Add `namespace.yaml` and `kustomization.yaml`
3. Create the app directory: `[namespace]/[app-name]/app/`
4. Add `kustomization.yaml`, `helmrelease.yaml`, `configmap.yaml`
5. Add a HelmRepository to `flux-system/repositories/` if needed
6. Add a Flux Kustomization CR to `flux-system/flux-kustomizations/`
7. Ensure all pod labels include `app`, `env: production`, and a valid `category`
8. Secrets must be SealedSecrets — never plain `Secret` objects

---

## Useful Commands

```bash
# Flux reconciliation state
flux get kustomizations -A
flux get helmreleases -A

# Force reconciliation
flux reconcile kustomization [name] --with-source

# Check Kyverno violations
kubectl get policyreport -A
kubectl get clusterpolicyreport

# Sealed secrets key check
kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key

# Calico status (NOT Flux-managed — check manually)
kubectl get tigerastatus
kubectl get pods -n calico-system
```
