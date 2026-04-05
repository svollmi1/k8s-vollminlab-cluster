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

## Autogen rules — danger zone

Kyverno autogen automatically generates additional rules to cover pod controllers when a policy targets bare `Pod` objects. This can produce broken rules that block the entire cluster.

**Hard rules:**

1. **Never mix `Pod` and controller kinds (`Deployment`, `StatefulSet`, `DaemonSet`) in the same policy rule.** Pod rules and controller rules must be in separate ClusterPolicies. Mixing them causes autogen to generate a controller variant of the Pod rule with incorrect field paths.

2. **Any policy that uses an `apiCall` context with a namespace lookup must disable autogen.** Add this annotation:
   ```yaml
   annotations:
     pod-policies.kyverno.io/autogen-controllers: none
   ```
   Without this, autogen rewrites `request.object.metadata.namespace` to `request.object.spec.template.metadata.namespace` in the generated controller rule — a field that does not exist on Deployment objects. The fail-closed webhook then blocks all Deployment mutations cluster-wide.

3. **After applying any mutate policy, verify no autogen rules were generated:**
   ```bash
   kubectl get clusterpolicy <name> -o jsonpath='{.spec.rules[*].name}'
   # Should return only the hand-written rule name(s), no autogen-* variants
   ```

**Why this matters:** The `mutate.kyverno.svc-fail` webhook is fail-closed (`failurePolicy: Fail`). A single broken policy blocks every mutation in its match scope. On 2026-04-05, a broken autogen rule blocked all cluster mutations for ~2 hours.

## Emergency: Kyverno webhook blocking all mutations

Symptom: `admission webhook "mutate.kyverno.svc-fail" denied the request` on every pod/deployment operation.

**Recovery procedure (in order):**

```bash
# Step 1 — identify which policy is broken
# Look at the error message: "mutation policy <name> error: ..."
# The policy name is in the denial message.

# Step 2 — delete the broken ClusterPolicy
kubectl delete clusterpolicy <broken-policy-name>

# Step 3 — restart Kyverno admission controller to clear in-memory policy cache
# (deleting the policy object alone is not enough — the compiled rule stays in memory)
kubectl rollout restart deployment/kyverno-admission-controller -n kyverno
kubectl rollout status deployment/kyverno-admission-controller -n kyverno --timeout=120s

# Step 4 — verify webhook is unblocked
kubectl create deployment test-block --image=nginx:1.25 -n default --dry-run=server 2>&1
# SUCCESS: "blocked due to restrict-default-namespace" (validate webhook, expected)
# STILL BROKEN: "mutate.kyverno.svc-fail denied" (delete more policies, restart again)

# Step 5 — fix the policy in git, PR, merge
# Step 6 — resume kyverno-policies Kustomization if it was suspended
flux resume kustomization kyverno-policies -n flux-system
```

**If patching the webhook failurePolicy to Ignore seems easier:** Kyverno auto-restores it within seconds. Deleting the broken policy + restarting the admission controller is the reliable path.

## Checking violations

```bash
kubectl get policyreport -A
kubectl describe policyreport -n [namespace]
```

## CI enforcement

The same Kyverno policies run in CI (`kyverno-cli test`) before any PR can merge. A manifest that passes CI should pass in-cluster.
