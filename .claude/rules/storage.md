# Storage Rules

## HARD CONSTRAINT — verify Longhorn capacity before setting PVC sizes

**Before committing any PVC size in a new app, check that Longhorn can actually schedule it.**

Longhorn uses replica-based storage. The default replica count is **3**. This means a 50Gi PVC requires ~150Gi of free space across the cluster (spread across replica nodes). A PVC that appears small can be unschedulable if free space is fragmented or insufficient.

**Never set a PVC size based on defaults or what "seems reasonable" without verifying.**

### How to check available capacity

```bash
# Check schedulable space per node (look at "schedulable" column)
kubectl get nodes -o custom-columns=\
'NAME:.metadata.name,SCHEDULABLE:.metadata.annotations.node\.longhorn\.io/longhorn-schedulable-storage'

# Or check in the Longhorn UI: Storage → Nodes → available column
# Each node must have free space >= PVC size for a replica to land there
# With 3 replicas, need 3 nodes each with >= PVC size free
```

### What happened on 2026-04-09

Harbor was provisioned with a 50Gi registry PVC (chart default). The cluster did not have 150Gi of free Longhorn space (50Gi × 3 replicas). The PVC sat Pending, which cascaded into stale iSCSI mount errors on k8sworker01 and blocked Harbor, Radarr, and other pods for hours.

Fix: reduced to 25Gi (PR #293). Always size PVCs based on actual need + available capacity, not chart defaults.

### Sizing guidelines for this cluster

| Use case | Reasonable size |
|----------|----------------|
| App config/data (arr stack, small apps) | 1–5Gi |
| Database (CNPG) | 5–20Gi |
| Container registry (Harbor) | 25Gi (expand via Longhorn online resize if needed) |
| Media/download staging | check free space first |

### Longhorn online resize

If a PVC turns out to be too small after the fact, Longhorn supports online expansion:
1. Edit the PVC: `kubectl patch pvc <name> -n <ns> --type=merge -p '{"spec":{"resources":{"requests":{"storage":"<new-size>"}}}}'`
2. Longhorn expands the volume without downtime.

**Start conservative. Expand later. Never provision speculatively large.**

## Multipath must be blacklisted on all worker nodes

Longhorn iSCSI volumes conflict with `multipathd` on Ubuntu 24.04 (multipath is enabled by default). This causes `exit status 32` stale mount failures. Every worker node — including DMZ workers — must have Longhorn devices blacklisted in `/etc/multipath.conf`.

**Apply this to every new worker node before it joins the cluster.**

Full procedure: `docs/runbooks/longhorn-multipath-blacklist.md`
