# Non-GitOps Cluster Objects Inventory

Objects that exist in the cluster but are **not managed by Flux**. These require manual apply/delete
during bootstrap, DR, or maintenance. If any of these accumulate drift, this doc is the source of truth.

---

## CNI — Calico / Tigera

**Namespaces:** `calico-system`, `calico-apiserver`, `tigera-operator`

| What | How managed |
|------|-------------|
| Tigera Operator | `kubectl apply` from upstream manifest (see `bootstrap/calico/README.md`) |
| Calico Installation CR | `kubectl apply -f bootstrap/calico/installation.yaml` |
| Calico APIServer CR | `kubectl apply -f bootstrap/calico/apiserver.yaml` |
| Namespace labels | `kubectl label namespace ...` (see `bootstrap/calico/README.md` Step 4) |

**Kyverno:** `exceptions-calico` PolicyException permanently exempts these namespaces.  
**Why not GitOps:** CNI must exist before Flux bootstraps. Flux cannot manage its own network layer.

---

## Kube-system

**Namespace:** `kube-system`

Managed entirely by kubeadm. No Flux Kustomization targets it. Any objects deployed here
(metrics-server, etc.) should be through a Flux Kustomization (see `kube-system-kustomization.yaml`).

---

## Bookstack

**Namespace:** `bookstack`

Fully manually deployed. Not in this GitOps repo at all.

| What | Status |
|------|--------|
| Namespace | Manual — has correct labels (app: bookstack, env: production, category: apps) |
| Deployment / Service | Manual |
| Ingress `bookstack-ingress` | Manual — missing required `app`/`env`/`category` labels (Kyverno audit violation) |

**Action needed:** Either bring bookstack under GitOps management (create `clusters/vollminlab-cluster/bookstack/`) or add a PolicyException for its Ingress. Currently generating audit violations; won't be blocked until `require-standard-labels` is promoted to Enforce.

---

## inject-required-labels-fixed (ClusterPolicy)

**Resource:** `ClusterPolicy/inject-required-labels-fixed` (cluster-scoped)

Manually applied with `kubectl apply`. Not in GitOps. Has **invalid categories** (`gitops`, `management`, `dashboard`) that are not in the valid category list.

**Status:** Superseded by the fixed `inject-namespace-labels` policy (which now correctly handles all namespaces without exclusions).

**Action required after PR #221 merges and injection is verified:**
```bash
kubectl delete clusterpolicy inject-required-labels-fixed
```

Verify injection is working first: `kubectl get policyreport -A` should show zero Deployment-level violations for upstream namespaces (longhorn, metallb, cert-manager, etc.).

---

## Manually-applied Ingresses (now fixed)

These were previously manually applied but are now under GitOps management:

| Ingress | Namespace | Status |
|---------|-----------|--------|
| `portainer-ingress` | `portainer` | Fixed — PR #221 adds `portainer/portainer/app/ingress.yaml` |

---

## Policy Modes — Current State and Roadmap

| Policy | Current Mode | Target | Condition |
|--------|-------------|--------|-----------|
| `require-standard-labels` | **Audit** | Enforce | After injection fix is verified (zero violations for controlled namespaces) |
| `restrict-latest-tag` | **Enforce** (PR #221) | — | Done |
| `restrict-loadbalancer-services` | **Enforce** (PR #221) | — | Done |
| `require-resources` | Audit | Enforce | After confirming inject-resource-requirements covers all Longhorn workloads |
| `restrict-privileged` | Audit | Enforce | Needs full audit — MetalLB speaker requires privileged mode (check exclude list) |
| `restrict-hostpath-usage` | Audit | Enforce | Verify no monitoring node-exporter hostPath violations first |
| `dmz-enforce-node-placement` | Audit | Stay Audit | Mutating policies should not use Enforce mode |

**To promote `require-standard-labels` to Enforce:**
1. Merge PR #221 and wait one reconciliation cycle (10 min)
2. Run `kubectl get policyreport -A` — only calico/bookstack/kube-system violations should remain
3. Confirm those are covered by exceptions or acceptable
4. Open a separate PR changing `validationFailureAction: Audit` → `Enforce` in `require-labels.yaml`
