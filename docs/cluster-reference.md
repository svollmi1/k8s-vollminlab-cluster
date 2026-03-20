# Vollminlab Cluster Reference

Comprehensive configuration reference for the vollminlab Kubernetes cluster. This document tracks what is actually deployed and configured — versions, values, network rules, storage, resource limits, and security policies. Update this when making changes.

---

## Table of Contents

1. [Cluster Overview](#cluster-overview)
2. [Network Configuration](#network-configuration)
3. [Bootstrap Components](#bootstrap-components)
4. [Cluster-Wide Resources](#cluster-wide-resources)
5. [Security & Policy](#security--policy)
6. [GitOps — Flux CD](#gitops--flux-cd)
7. [Ingress & Certificates](#ingress--certificates)
8. [Storage](#storage)
9. [Infrastructure Services](#infrastructure-services)
10. [Media Stack](#media-stack)
11. [Applications](#applications)
12. [DMZ — Isolated Workloads](#dmz--isolated-workloads)
13. [CI/CD](#cicd)

---

## Cluster Overview

| Property | Value |
|---|---|
| Kubernetes distribution | kubeadm |
| CNI | Calico v3.29.1 (Tigera Operator v1.36.2) |
| GitOps | Flux CD |
| GitOps source | `main` branch, 1-minute pull interval |
| Pod CIDR | `172.18.0.0/16` |
| MetalLB IP pool | `192.168.152.244–192.168.152.254` |
| Control plane replicas | 2 |
| Node update strategy | RollingUpdate (maxUnavailable: 1) |

### Nodes

| Node | Role | Notes |
|---|---|---|
| (control plane nodes) | control-plane | kubeadm-managed |
| k8sworker05 | DMZ worker | Taint: `dmz=true:NoSchedule`, label: `role=dmz` |
| (other workers) | general workloads | Standard scheduling |

---

## Network Configuration

### Calico CNI

Managed manually via `bootstrap/calico/`. **Not Flux-managed.** See [bootstrap/calico/README.md](../bootstrap/calico/README.md).

| Parameter | Value |
|---|---|
| Variant | Calico |
| CNI type | Calico |
| IPAM | Calico |
| BGP | Enabled |
| Dataplane | iptables |
| IPv4 pool CIDR | `172.18.0.0/16` |
| Encapsulation | IPIP |
| NAT outgoing | Enabled |
| Block size | `/26` |
| Node selector | `all()` |
| Allowed uses | Workload, Tunnel |
| Host ports | Enabled |
| Windows dataplane | Disabled |
| Multi-interface mode | None |
| CNI log max size | 100Mi |
| CNI log max count | 10 |
| CNI log max age | 30 days |

### CoreDNS

Custom config applied via `bootstrap/coredns/coredns-configmap.yaml`. Not Flux-managed.

| Parameter | Value |
|---|---|
| Domain | `cluster.local` |
| Cache TTL | 30s |
| Max concurrent forwards | 1000 |
| Prometheus metrics | Port 9153 |
| Plugins | errors, health, ready, kubernetes, prometheus, forward, cache, loop, reload, loadbalance |

### MetalLB

| Parameter | Value |
|---|---|
| Chart version | v0.14.9 |
| Helm repo | https://metallb.universe.tf |
| IP pool name | `metallb-pool` |
| IP range | `192.168.152.244–192.168.152.254` |
| Mode | L2 (L2Advertisement) |
| Auto-assign | true |
| Speaker tolerations | `dmz=Exists:NoSchedule`, `dmz=Exists:NoExecute` |
| Controller resources | req: 50m/64Mi, limits: 200m/128Mi |
| Speaker resources | req: 50m/64Mi, limits: 200m/128Mi |

---

## Bootstrap Components

These are applied manually before Flux bootstraps. They are never reconciled by Flux.

### Sealed Secrets Sealing Key

The cluster sealing key is backed up in 1Password as **"Sealed Secrets Sealing Key"**.

Must be restored **before** Flux bootstraps on a new cluster. Full procedure: [bootstrap/sealed-secrets/README.md](../bootstrap/sealed-secrets/README.md).

```bash
# Restore key before Flux bootstrap
kubectl apply -f <exported-yaml-from-1password>
```

### Bootstrap Order

```
1. Install Kubernetes control plane (kubeadm)
2. Install Calico CNI              → bootstrap/calico/README.md
3. Apply CoreDNS custom config     → bootstrap/coredns/coredns-configmap.yaml
4. Restore sealed-secrets key      → bootstrap/sealed-secrets/README.md
5. Bootstrap Flux CD               → flux bootstrap github ...
6. All apps                        → Flux reconciles automatically
```

---

## Cluster-Wide Resources

Located in `clusters/vollminlab-cluster/clusterwide/`.

### PersistentVolumes (SMB-backed)

All volumes are `ReadWriteMany`, `100Gi`, backed by SMB shares at `192.168.150.2`. UID/GID: `568`.

| PV | SMB Share | Used By |
|---|---|---|
| `pv-movies` | `//192.168.150.2/movies` | mediastack/radarr |
| `pv-tv` | `//192.168.150.2/tv` | mediastack/sonarr |
| `pv-completed-downloads` | `//192.168.150.2/completed-downloads` | mediastack/sabnzbd |
| `pv-incomplete-downloads` | `//192.168.150.2/incomplete-downloads` | mediastack/sabnzbd |

### StorageClasses

**`longhorn-dmz`** — Longhorn storage scoped to DMZ node only:

| Parameter | Value |
|---|---|
| Provisioner | `driver.longhorn.io` |
| Replicas | 2 |
| Node selector | `dmz` |
| Data locality | `best-effort` |
| Stale replica timeout | 30s |
| fsType | ext4 |
| Volume binding mode | `WaitForFirstConsumer` |

**`smb`** — SMB CSI driver for network share mounts:

| Parameter | Value |
|---|---|
| Provisioner | `smb.csi.k8s.io` |
| dir_mode | `0755` |
| file_mode | `0755` |
| uid/gid | `568` |
| Mount options | `mfsymlinks, cache=strict, noserverino` |
| Volume binding mode | `Immediate` |

### RBAC

**`capacitor`** ClusterRole — grants the Capacitor dashboard read access to: pods, ingresses, deployments, services, secrets, events, configmaps, and all Flux resources (patch).

**`disk-cleanup`** ClusterRole — grants the maintenance CronJob: read nodes/pods, delete pods, read deployments/daemonsets/replicasets.

**Kyverno webhook patch** ClusterRole — grants Kyverno permission to patch `mutatingwebhookconfigurations` and `validatingwebhookconfigurations`.

### Disk Cleanup CronJob

| Parameter | Value |
|---|---|
| Namespace | kube-system |
| Schedule | `0 2 * * *` (2 AM daily) |
| Image | `alpine/k8s:1.30.3` |
| Tasks | Delete evicted pods; delete completed/failed pods older than 1 hour |
| CPU | req: 50m, limits: 200m |
| Memory | req: 64Mi, limits: 128Mi |

---

## Security & Policy

### Kyverno

| Parameter | Value |
|---|---|
| Chart version | v3.4.1 |
| Helm repo | https://kyverno.github.io/kyverno/ |
| Replicas | 3 |
| Admission controller replicas | 3 |
| Admission failure policy | Ignore (30s timeout) |
| Excluded namespaces | kyverno, kube-system, flux-system |

**Admission Controller** — req: 500m/512Mi, limits: 1000m/1Gi
**Background Controller** — req: 100m/128Mi, limits: 200m/256Mi
**Cleanup Controller** — req: 100m/128Mi, limits: 200m/256Mi
**Reports Controller** — req: 100m/128Mi, limits: 200m/256Mi

### ClusterPolicies

| Policy | Mode | Action | Rule |
|---|---|---|---|
| `restrict-default` | enforce | validate | Block all workloads in `default` namespace |
| `restrict-privileged` | audit | validate | Block privileged containers; exempts: kube-system, calico-system, longhorn-system, metallb-system, csi-driver, tigera-operator, ingress-nginx |
| `restrict-hostpath-usage` | audit | validate | Block hostPath volumes; exempts: kube-system, calico-system, longhorn-system, monitoring, tigera-operator |
| `restrict-latest-tag` | audit | validate | Block `:latest` image tags on Deployment/StatefulSet/DaemonSet |
| `restrict-loadbalancer-services` | audit | validate | LoadBalancer type only allowed in `ingress-nginx` and `dmz` namespaces |
| `require-standard-labels` | audit | validate | Require `app`, `env`, `category` labels on Deployments, StatefulSets, DaemonSets, Pods, Namespaces, Services; exempts: kube-system, default |
| `require-resources` | audit | validate | Require CPU/memory requests and limits on all containers; exempts Flux deployments |
| `dmz-enforce-node-placement` | enforce | mutate | Auto-inject `nodeSelector: role=dmz` and toleration `dmz=Exists:NoSchedule` on all pods in `dmz` namespace |
| `dmz-restrict-external-access` | enforce | validate | Block `external-access=true` and `internet-egress=true` labels outside `dmz` namespace |
| `inject-namespace-labels` | — | mutate | Auto-copy `app`, `env`, `category` labels from namespace to workloads; exempts: longhorn-system, flux-system, monitoring |
| `inject-resource-requirements` | — | mutate | Auto-inject resource limits for Longhorn sidecar containers (CSI attacher, provisioner, resizer, snapshotter, UI, manager, driver) |
| `force-rescan-on-rollout` | — | mutate | Annotate Deployments/StatefulSets/DaemonSets with `policy.kyverno.io/kyverno-force-rescan` |

**PolicyException: `ignore-flux-core`** — Exempts all Flux controllers and the `kyverno` HelmRelease from all policies.

### Policy Reporter

| Parameter | Value |
|---|---|
| Chart version | v3.1.3 |
| Helm repo | https://kyverno.github.io/policy-reporter/ |
| Ingress | `policyreporter.vollminlab.com` |
| TLS | wildcard-tls |
| UI resources | req: 50m/64Mi, limits: 100m/128Mi |
| Reporter resources | req: 50m/64Mi, limits: 100m/128Mi |

### Sealed Secrets Controller

| Parameter | Value |
|---|---|
| Chart version | v2.17.1 |
| Release name | `sealed-secrets-controller` |
| Helm repo | https://sealed-secrets.dev |
| Image | `bitnami/sealed-secrets-controller:0.28.0` |
| CPU | req: 50m, limits: 100m |
| Memory | req: 32Mi, limits: 64Mi |
| readOnlyRootFilesystem | true |
| runAsNonRoot | true |
| runAsUser | 1001 |
| fsGroup | 65534 |
| Reconcile interval | 15m |

---

## GitOps — Flux CD

### Sync Configuration

| Parameter | Value |
|---|---|
| GitRepository | `https://github.com/svollmi1/k8s-vollminlab-cluster.git` |
| Branch | `main` |
| Pull interval | 1 minute |
| Auth | SSH key via `flux-system-sealedsecret` |
| Reconcile interval | 10 minutes (all Kustomizations) |
| Prune | enabled (all Kustomizations) |

### Flux Kustomizations

All Kustomizations use `interval: 10m`, `prune: true`, source `flux-system` GitRepository.

| Kustomization | Path | Notes |
|---|---|---|
| `actions-runner-system` | `./clusters/vollminlab-cluster/actions-runner-system` | |
| `actions-runner-system-patch` | patch only | Webhook patches |
| `capacitor` | `flux-system/capacitor` | dependsOn: flux-system |
| `cert-manager` | `./clusters/vollminlab-cluster/cert-manager` | |
| `clusterwide` | `./clusters/vollminlab-cluster/clusterwide` | |
| `dmz` | `./clusters/vollminlab-cluster/dmz` | |
| `elastic-system` | `./clusters/vollminlab-cluster/elastic-system` | |
| `homepage` | `./clusters/vollminlab-cluster/homepage` | |
| `ingress-nginx` | `./clusters/vollminlab-cluster/ingress-nginx` | |
| `kube-system` | `./clusters/vollminlab-cluster/kube-system` | |
| `kyverno` | `./clusters/vollminlab-cluster/kyverno` | Health checks on 4 deployments |
| `kyverno-policies` | `./clusters/vollminlab-cluster/kyverno/kyverno/policies` | dependsOn: kyverno |
| `kyverno-webhooks-patch` | patch only | |
| `local-path-storage` | `./clusters/vollminlab-cluster/local-path-storage` | |
| `longhorn-system` | `./clusters/vollminlab-cluster/longhorn-system` | |
| `mediastack` | `./clusters/vollminlab-cluster/mediastack` | |
| `metallb-system` | `./clusters/vollminlab-cluster/metallb-system` | |
| `monitoring` | `./clusters/vollminlab-cluster/monitoring` | Placeholder — not deployed |
| `policy-reporter` | `./clusters/vollminlab-cluster/kyverno` | |
| `policy-reporter-patch` | patch only | |
| `portainer` | `./clusters/vollminlab-cluster/portainer` | |
| `sealed-secrets` | `./clusters/vollminlab-cluster/sealed-secrets` | |

### Capacitor (Flux UI Dashboard)

| Parameter | Value |
|---|---|
| Image | `ghcr.io/gimlet-io/capacitor:v0.4.8` |
| Chart | onechart v0.73.0 (gimlet.io) |
| Ingress | `capacitor.vollminlab.com` |
| TLS | wildcard-tls |
| Port | 9000 |
| CPU | req: 100m, limits: 200m |
| Memory | req: 256Mi, limits: 512Mi |
| Security | runAsNonRoot, runAsUser=100, readOnlyRootFilesystem, drop=ALL, seccompProfile=RuntimeDefault |

### HelmRepositories

| Name | Type | URL |
|---|---|---|
| arc-repo | HelmRepository | https://actions-runner-controller.github.io/actions-runner-controller |
| capacitor-repo | HelmRepository | https://gimlet.io/onechart/ |
| cert-manager-repo | HelmRepository | https://charts.jetstack.io |
| elastic-repo | HelmRepository | https://helm.elastic.co |
| homepage-repo | HelmRepository | https://jameswynn.github.io/helm-charts/ |
| ingress-nginx-repo | HelmRepository | https://kubernetes.github.io/ingress-nginx |
| kyverno-repo | HelmRepository | https://kyverno.github.io/kyverno/ |
| kyverno-policyreporter-repo | HelmRepository | https://kyverno.github.io/policy-reporter/ |
| local-path-provisioner-repo | GitRepository | https://github.com/rancher/local-path-provisioner (tag: v0.0.30) |
| longhorn-repo | HelmRepository | https://charts.longhorn.io |
| metallb-repo | HelmRepository | https://metallb.universe.tf |
| metrics-server-repo | HelmRepository | https://kubernetes-sigs.github.io/metrics-server/ |
| minecraft-repo | HelmRepository | https://itzg.github.io/minecraft-server-charts/ |
| overseerr-repo | OCIRepository | — |
| portainer-repo | HelmRepository | https://portainer.io/helm |
| prowlarr-repo | OCIRepository | — |
| radarr-repo | OCIRepository | — |
| sabnzbd-repo | OCIRepository | — |
| sealed-secrets-repo | HelmRepository | https://sealed-secrets.dev |
| smb-csi-driver-repo | HelmRepository | https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts |
| sonarr-repo | OCIRepository | — |
| tautulli-repo | HelmRepository | — |
| bazarr-repo | HelmRepository | — |
| bitnami-repo | HelmRepository | — |
| minecraft-repo | HelmRepository | https://itzg.github.io/minecraft-server-charts/ |

---

## Ingress & Certificates

### ingress-nginx

| Parameter | Value |
|---|---|
| Chart version | v4.12.0 |
| Helm repo | https://kubernetes.github.io/ingress-nginx |
| Default SSL certificate | `cert-manager/wildcard-tls` |

### cert-manager

| Parameter | Value |
|---|---|
| Chart version | v1.16.3 |
| Helm repo | https://charts.jetstack.io |
| DNS01 recursive nameservers only | true |
| DNS01 recursive nameservers | `10.96.0.10:53` |

### Ingress Hostnames

All ingresses use `ingressClassName: nginx`, TLS termination via `wildcard-tls`, ssl-redirect enabled.

| Hostname | Backend | Port | Namespace |
|---|---|---|---|
| `homepage.vollminlab.com` | homepage | 3000 | homepage |
| `capacitor.vollminlab.com` | capacitor | 9000 | flux-system |
| `longhorn.vollminlab.com` | longhorn-frontend | 80 | longhorn-system |
| `policyreporter.vollminlab.com` | policy-reporter-ui | 8080 | kyverno |
| `radarr.vollminlab.com` | radarr | 7878 | mediastack |
| `sonarr.vollminlab.com` | sonarr | 8989 | mediastack |
| `sabnzbd.vollminlab.com` | sabnzbd | 10097 | mediastack |
| `prowlarr.vollminlab.com` | prowlarr | 9696 | mediastack |
| `bazarr.vollminlab.com` | bazarr | 6767 | mediastack |
| `overseerr.vollminlab.com` | overseerr | 5055 | mediastack |
| `tautulli.vollminlab.com` | tautulli | 8181 | mediastack |

---

## Storage

### Longhorn

| Parameter | Value |
|---|---|
| Chart version | v1.8.1 |
| Helm repo | https://charts.longhorn.io |
| Default replica count | 3 |
| Default data path | `/var/lib/longhorn` |
| Taint toleration | `dmz=true:NoSchedule;dmz=true:NoExecute` |
| Manager/driver tolerations | `dmz=true:NoSchedule`, `dmz=true:NoExecute` |
| Ingress | `longhorn.vollminlab.com` |

### SMB CSI Driver

| Parameter | Value |
|---|---|
| Chart version | v1.17.0 |
| Helm repo | https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts |
| NAS address | `192.168.150.2` |
| SMB shares | movies, tv, completed-downloads, incomplete-downloads |
| Mount uid/gid | 568 |

### Local Path Provisioner

| Parameter | Value |
|---|---|
| Chart source | GitRepository (rancher/local-path-provisioner tag v0.0.30) |
| Chart path | `deploy/chart/local-path-provisioner` |
| Values | defaults only |

### PVC Inventory

| PVC | Namespace | Size | StorageClass | Access |
|---|---|---|---|---|
| `pvc-movies` | mediastack | 100Gi | smb (bound to pv-movies) | RWX |
| `pvc-tv` | mediastack | 100Gi | smb (bound to pv-tv) | RWX |
| `pvc-completed-downloads` | mediastack | 100Gi | smb | RWX |
| `pvc-incomplete-downloads` | mediastack | 100Gi | smb | RWX |
| `pvc-radarr-config` | mediastack | 5Gi | longhorn | RWO |
| `pvc-sonarr-config` | mediastack | 5Gi | longhorn | RWO |
| `pvc-sabnzbd-config` | mediastack | 5Gi | longhorn | RWO |
| `pvc-prowlarr-config` | mediastack | 5Gi | longhorn | RWO |
| `pvc-bazarr-config` | mediastack | 5Gi | longhorn | RWO |
| `pvc-overseerr-config` | mediastack | 5Gi | longhorn | RWO |
| `pvc-tautulli-config` | mediastack | 1Gi | longhorn | RWO |
| `pvc-minecraft-datadir` | dmz | 20Gi | longhorn-dmz | RWX |
| `portainer` | portainer | 10Gi | local-path | RWO |

---

## Infrastructure Services

### metrics-server

| Parameter | Value |
|---|---|
| Chart version | v3.12.2 |
| Helm repo | https://kubernetes-sigs.github.io/metrics-server/ |
| kubelet-insecure-tls | true |
| kubelet preferred address types | InternalIP, Hostname, InternalDNS |
| Metric resolution | 15s |
| CPU | req: 50m, limits: 200m |
| Memory | req: 64Mi, limits: 128Mi |

### ECK Operator (Elasticsearch)

| Parameter | Value |
|---|---|
| Chart version | v2.16.1 |
| Helm repo | https://helm.elastic.co |
| Webhook | enabled |
| Log verbosity | 1 |

### Shlink (URL Shortener)

| Parameter | Value |
|---|---|
| Namespace | shlink |
| Backend chart | shlink-backend v11.0.5 (christianhuth) |
| Backend app version | Shlink 5.0.1 |
| Web client chart | shlink-web v1.11.0 (christianhuth) |
| Web client app version | shlink-web-client 4.7.0 |
| Helm repo | https://charts.christianhuth.de |
| Short domain | `go.vollminlab.com` |
| Management UI | `shlink.vollminlab.com` |
| Database | PostgreSQL (Bitnami subchart, bundled in shlink-backend) |
| DB credentials | SealedSecret: `shlink-credentials` |
| Backend CPU | req: 100m, limits: 500m |
| Backend memory | req: 256Mi, limits: 512Mi |
| PostgreSQL CPU | req: 100m, limits: 500m |
| PostgreSQL memory | req: 256Mi, limits: 512Mi |
| Web client CPU | req: 10m, limits: 100m |
| Web client memory | req: 32Mi, limits: 64Mi |
| Redirect on 404 | `https://homepage.vollminlab.com` |
| Redirect status | 302 |

**Short links inventory** (`go.vollminlab.com/<slug>` → destination):

| Slug | Destination |
|---|---|
| homepage | https://homepage.vollminlab.com |
| capacitor | https://capacitor.vollminlab.com |
| longhorn | https://longhorn.vollminlab.com |
| policyreporter | https://policyreporter.vollminlab.com |
| radarr | https://radarr.vollminlab.com |
| sonarr | https://sonarr.vollminlab.com |
| sabnzbd | https://sabnzbd.vollminlab.com |
| prowlarr | https://prowlarr.vollminlab.com |
| bazarr | https://bazarr.vollminlab.com |
| overseerr | https://overseerr.vollminlab.com |
| tautulli | https://tautulli.vollminlab.com |
| portainer | https://portainer.vollminlab.com |
| shlink | https://shlink.vollminlab.com |
| pihole | https://pihole.vollminlab.com |
| npm | https://npm.vollminlab.com |
| plex | https://plex.vollminlab.com |
| truenas | https://truenas.vollminlab.com |
| udm | https://udm.vollminlab.com |
| vcenter | https://vcenter.vollminlab.com |
| haproxy | https://haproxy.vollminlab.com |
| bluemap | https://bluemap.vollminlab.com |

> Short links are configured via the Shlink web UI at `shlink.vollminlab.com` — they are not stored in Git.

---

### Actions Runner Controller

| Parameter | Value |
|---|---|
| Chart version | v0.23.7 |
| Helm repo | https://actions-runner-controller.github.io/actions-runner-controller |
| Auth | GitHub App (sealed secret: `arc-githubapp-secret`) |
| Sync period | 1m |
| Leader election | enabled |
| Manager replicas | 3 |
| Manager resources | req: 50m/64Mi, limits: 200m/128Mi |
| Container mode | kubernetes |
| Anti-affinity | preferred (weight 100) |

**RunnerDeployments** — 3 pools, 2 replicas each:

| Runner label | Repository | Image | CPU | Memory |
|---|---|---|---|---|
| vollminlab-1 | svollmi1/k8s-vollminlab-cluster | summerwind/actions-runner:ubuntu-22.04 | req 500m / limits 2000m | req 512Mi / limits 2Gi |
| vollminlab-2 | svollmi1/k8s-vollminlab-cluster | summerwind/actions-runner:ubuntu-22.04 | req 500m / limits 2000m | req 512Mi / limits 2Gi |
| vollminlab-3 | svollmi1/k8s-vollminlab-cluster | summerwind/actions-runner:ubuntu-22.04 | req 500m / limits 2000m | req 512Mi / limits 2Gi |

Runners are ephemeral (`RUNNER_EPHEMERAL=true`). `RUNNER_WAIT_FOR_DOCKERD_SECONDS=120`.

---

## Media Stack

All apps in the `mediastack` namespace. Shared SMB storage mounted at the namespace level. App configs stored on Longhorn (5Gi RWO each, except Tautulli at 1Gi).

### Sonarr (TV automation)

| Parameter | Value |
|---|---|
| Source | OCIRepository |
| Ingress | `sonarr.vollminlab.com` |
| Port | 8989 |
| Config PVC | 5Gi Longhorn RWO |
| Volumes | pvc-tv (RWX), pvc-completed-downloads (RWX) |

### Radarr (Movie automation)

| Parameter | Value |
|---|---|
| Source | OCIRepository |
| Ingress | `radarr.vollminlab.com` |
| Port | 7878 |
| Config PVC | 5Gi Longhorn RWO |
| Volumes | pvc-movies (RWX), pvc-completed-downloads (RWX) |

### SABnzbd (Usenet downloader)

| Parameter | Value |
|---|---|
| Source | OCIRepository |
| Ingress | `sabnzbd.vollminlab.com` |
| Port | 10097 |
| Config PVC | 5Gi Longhorn RWO |
| Volumes | pvc-completed-downloads (RWX), pvc-incomplete-downloads (RWX) |

### Prowlarr (Indexer aggregation)

| Parameter | Value |
|---|---|
| Source | OCIRepository |
| Ingress | `prowlarr.vollminlab.com` |
| Port | 9696 |
| Config PVC | 5Gi Longhorn RWO |

### Bazarr (Subtitle management)

| Parameter | Value |
|---|---|
| Chart version | v11.1.1 |
| Ingress | `bazarr.vollminlab.com` |
| Port | 6767 |
| Config PVC | 5Gi Longhorn RWO |
| Volumes | pvc-movies (RWX), pvc-tv (RWX) |

### Overseerr (Media requests)

| Parameter | Value |
|---|---|
| Source | OCIRepository |
| Ingress | `overseerr.vollminlab.com` |
| Port | 5055 |
| Config PVC | 5Gi Longhorn RWO |

### Tautulli (Plex monitoring)

| Parameter | Value |
|---|---|
| Chart version | v11.3.1 |
| Ingress | `tautulli.vollminlab.com` |
| Port | 8181 |
| Config PVC | 1Gi Longhorn RWO |

### Shared Secrets

| Secret | Contents |
|---|---|
| `smb-credentials` | SMB username/password for NAS mounts at `192.168.150.2` |

---

## Applications

### Homepage Dashboard

| Parameter | Value |
|---|---|
| Chart version | v2.1.0 |
| Helm repo | https://jameswynn.github.io/helm-charts/ |
| Ingress | `homepage.vollminlab.com` |
| Port | 3000 |
| Mode | cluster |
| Theme | dark |
| CPU | req: 100m, limits: 500m |
| Memory | req: 256Mi, limits: 512Mi |
| Allowed hosts | `homepage.vollminlab.com, localhost, 127.0.0.1` |

**Service Groups configured:**

| Group | Services |
|---|---|
| Media Stack | Plex, Overseerr, Tautulli, Sonarr, Radarr, Prowlarr, SABnzbd |
| Infrastructure | Pi-hole, TrueNAS, vCenter, Portainer, Nginx Proxy Manager, UDM, HAProxy stats |
| Monitoring | Grafana, Prometheus |
| Documentation | BookStack, Homepage, GitHub repo, ChatGPT, Reddit, Chocolatey |
| Personal | Yahoo Fantasy Football, ESPN Fantasy Football, D.E. Shaw Access, GroupMe, MakerWorld |

**Widgets:** Google search, resource usage (CPU/memory), datetime, greeting, OpenWeatherMap (imperial, 5-min cache).

**Secret:** `homepage-env-vars` (SealedSecret) — API keys, weather coordinates, service credentials.

### Portainer

| Parameter | Value |
|---|---|
| Chart version | v1.0.59 |
| Helm repo | https://portainer.io/helm |
| Service type | ClusterIP |
| Config PVC | 10Gi local-path RWO |
| Edge agent | enabled (tunnel port 30776) |
| Security context | runAsUser=0 (root — required by Portainer) |
| CPU | req: 100m, limits: 100m |
| Memory | req: 128Mi, limits: 128Mi |

---

## DMZ — Isolated Workloads

The `dmz` namespace is a security boundary for internet-exposed workloads. Full model documented in [clusters/vollminlab-cluster/dmz/README.md](../clusters/vollminlab-cluster/dmz/README.md).

### Security Layers

| Layer | Mechanism |
|---|---|
| Physical isolation | Dedicated node `k8sworker05` |
| Node isolation | Taint `dmz=true:NoSchedule`, label `role=dmz` |
| Admission control | Kyverno `dmz-enforce-node-placement` — auto-injects nodeSelector + toleration |
| Admission control | Kyverno `dmz-restrict-external-access` — blocks external-access labels outside dmz |
| Network | Default-deny NetworkPolicy; explicit allow rules only |
| Pod security | Namespace-level: `enforce=baseline, audit=restricted, warn=restricted` |
| Storage | Dedicated `longhorn-dmz` StorageClass — nodes with `dmz` selector only |

### Network Policies

| Policy | Rule |
|---|---|
| `default-deny-all` | Block all ingress and egress |
| `allow-dns` | Allow egress to `10.96.0.10:53` UDP/TCP |
| `allow-external-ingress` | Allow ingress from `0.0.0.0/0` for pods labeled `external-access=true` |
| `allow-internet-egress` | Allow egress to internet (non-RFC1918, non-link-local, non-loopback) for pods labeled `internet-egress=true` |

### Minecraft Server

| Parameter | Value |
|---|---|
| Chart version | v4.0.0 |
| Helm repo | https://itzg.github.io/minecraft-server-charts/ |
| Image | `itzg/minecraft-server:java21` |
| Server type | PAPER |
| JVM memory | 6G |
| CPU | req: 2000m, limits: 4000m |
| Memory | req: 6Gi, limits: 8Gi |
| Config PVC | 20Gi `longhorn-dmz` RWX |
| View distance | 8 |
| Simulation distance | 6 |
| Max players | 20 |
| Difficulty | normal |
| Max world size | 29,999,984 |
| RCON | enabled (sealed secret: `minecraft-rcon-secret`) |
| Plugins | BlueMap v5.13 (spigot) |
| Service type | NodePort |
| Minecraft port | NodePort `32565` |
| BlueMap port | NodePort `32566` (container port 8100) |

**Allowed ingress:** HAProxy nodes `192.168.160.2/32` and `192.168.160.3/32` on ports 25565 (game) and 8100 (BlueMap).

**Allowed egress:** `0.0.0.0/0` on ports 80, 443 (downloads/updates) + DNS to `10.96.0.10:53`.

**Probes:**
- Readiness: initialDelay=30s, period=10s, failureThreshold=10
- Liveness: initialDelay=30s, period=5s, failureThreshold=10

---

## CI/CD

### GitHub Actions Workflows

| Workflow | Trigger | Jobs |
|---|---|---|
| `ci.yaml` | PR + push to main | kustomize build validation, Kyverno policy checks, Trivy security scan |
| `codeql.yml` | Schedule + push | CodeQL security analysis |
| `terraform-branch-protection.yaml` | Push | Apply GitHub branch protection via Terraform |

### Branch Protection (via Terraform)

| Rule | Value |
|---|---|
| Required reviews | 1 |
| Dismiss stale reviews | true |
| CI required | yes (ci.yaml must pass) |
| Admin enforcement | enabled |
| Require conversation resolution | true |
| Force push | blocked |
| Branch deletion | blocked |
| Config source | `terraform/github-branch-protection/` |

### Self-Hosted Runners (ARC)

CI runs on self-hosted runners in `actions-runner-system`. 3 pools × 2 replicas = 6 concurrent runners available. Jobs target runner labels `vollminlab-1`, `vollminlab-2`, `vollminlab-3`.
