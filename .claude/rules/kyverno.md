---
description: Kyverno policy rules, required labels, DMZ constraints, and enforcement modes for k8s-vollminlab-cluster
---

# Kyverno Rules

## Enforce-mode policies (will block pod creation)

| Policy | Rule |
|--------|------|
| Required labels | Every pod must have `app`, `env`, and `category` labels |
| No default namespace | Pods may not run in the `default` namespace |
| DMZ placement | DMZ pods must run on `k8sworker05` (injected automatically) |

## Audit-mode policies (violations logged, not blocked)

- Resource limits required (CPU + memory requests/limits)
- No `:latest` image tags
- No privileged containers
- No `hostPath` volumes

## Valid `category` label values

Every HelmRelease and pod must use one of:

| Category | Apps |
|----------|------|
| `core` | Flux, Capacitor, Kyverno |
| `security` | cert-manager, sealed-secrets, Kyverno policy-reporter |
| `storage` | Longhorn, local-path-provisioner, smb-csi-driver |
| `networking` | ingress-nginx, MetalLB |
| `observability` | metrics-server, ECK (Elasticsearch/Kibana) |
| `apps` | homepage, portainer, shlink, renovate |
| `media` | Radarr, Sonarr, Bazarr, Overseerr, Prowlarr, SABnzbd, Tautulli |
| `gaming` | Minecraft (dmz namespace only) |
| `ci` | actions-runner-system (GitHub ARC runners) |

## DMZ namespace rules

- Workloads live in `dmz/` namespace only
- Dedicated node: `k8sworker05`, taint `dmz=true:NoSchedule`
- Kyverno auto-injects `nodeSelector` and `tolerations` — do not set manually
- Default-deny NetworkPolicy; all ingress/egress requires explicit allow rules
- Use `longhorn-dmz` StorageClass for persistent volumes (node-isolated)
- Full details: `clusters/vollminlab-cluster/dmz/README.md`

## Checking violations

```bash
kubectl get policyreport -A
kubectl describe policyreport -n [namespace]
```

## CI enforcement

The same Kyverno policies run in CI (`kyverno-cli test`) before any PR can merge. A manifest that passes CI should pass in-cluster.
