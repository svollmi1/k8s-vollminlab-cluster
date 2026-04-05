# Incident Postmortem — 2026-04-05
## external-dns DNS Wipe + Kyverno Webhook Full Cluster Block

**Severity:** P1 — Full infrastructure DNS outage, all cluster mutations blocked  
**Duration:** ~6 hours (approx. 19:00 → 01:30 UTC)  
**Status:** Resolved  

---

## Executive Summary

Two independent but compounding failures occurred on 2026-04-05:

1. `external-dns` was misconfigured with `policy: sync`, causing it to delete all manually-managed Pi-hole DNS A records for infrastructure hosts (vCenter, ESXi, TrueNAS, k8s nodes, haproxy, etc.) that it did not create. Infrastructure hosts became unreachable by DNS name.

2. A Kyverno `ClusterPolicy` was modified to target bare `Pod` objects alongside controller kinds (`Deployment`, `StatefulSet`, `DaemonSet`) in the same rule. Kyverno's autogen feature generated a broken controller variant of the Pod rule that referenced a non-existent field (`request.object.spec.template.metadata.namespace`). This caused the fail-closed mutating webhook (`mutate.kyverno.svc-fail`) to deny all cluster mutations — blocking HelmRelease upgrades, pod creation, and Flux reconciliation.

The two failures interacted: the fix for external-dns (a HelmRelease upgrade) could not be applied because the Kyverno webhook was blocking all Deployment mutations.

---

## Timeline

| Time (UTC) | Event |
|---|---|
| ~19:00 | `external-dns` HelmRelease upgraded with `policy: sync` in ConfigMap. Pi-hole DNS records begin being deleted. |
| ~19:10 | Infrastructure hosts (vcenter, esxi nodes, truenas, k8s nodes) become unreachable by name. DNS records wiped for first time. |
| ~19:30 | DNS records manually restored via pihole-flask-api. external-dns scaled to 0. |
| ~20:00 | `inject-namespace-labels` ClusterPolicy modified to also target `Pod` kind alongside `Deployment/StatefulSet/DaemonSet`. Kyverno autogen activates. |
| ~20:09 | Last successful Helm upgrade (external-dns rev 3) with old `policy: sync` values — the fix was not yet in. |
| ~01:24 | external-dns HelmRelease upgrade to rev 4 (with `upsert-only`) attempted — blocked by `mutate.kyverno.svc-fail` webhook. |
| ~01:30 | DNS records wiped a second time by external-dns. |
| ~02:00 | Recovery session begins. |
| ~02:15 | Both broken ClusterPolicies deleted (`inject-namespace-labels`, `inject-pod-labels`). |
| ~02:20 | Kyverno admission controller pods restarted to clear in-memory policy cache. |
| ~02:25 | `helm rollback external-dns` clears Helm failure state (rev 4 failed → rev 5 rollback to 3). |
| ~02:26 | `flux reconcile helmrelease external-dns` succeeds. HelmRelease upgrades to rev 6 with `policy: upsert-only`. |
| ~02:27 | `--policy=upsert-only` confirmed in external-dns logs. external-dns scaled to 1. No DELETE log lines. |
| ~02:28 | 55 DNS records restored to both pihole1 (192.168.100.2) and pihole2 (192.168.100.3) via pihole-flask-api. Key records verified via nslookup. |
| ~02:35 | Fix committed: `pod-policies.kyverno.io/autogen-controllers: none` added to both ClusterPolicies. PR #271 opened and merged. |
| ~02:40 | `flux resume kustomization kyverno-policies` — Flux takes ownership of policies from main. All 13 ClusterPolicies Ready. |
| ~02:45 | All HelmReleases True. Cluster fully recovered. |

---

## Root Cause Analysis

### Root Cause 1 — external-dns `policy: sync` on a shared DNS backend

**What happened:**

The `external-dns` Helm values ConfigMap was updated to use `policy: sync`. With this policy, external-dns treats itself as the authoritative source for all DNS records matching its `--domain-filter` (`vollminlab.com`). Any A record in Pi-hole that external-dns did not create is considered stale and deleted.

Pi-hole is a **shared** DNS backend — it holds both records that external-dns manages (ingress hostnames) and records that are manually managed (infrastructure hosts: vCenter, ESXi nodes, k8s nodes, TrueNAS, haproxy VIPs, etc.). external-dns has no awareness of the manual records. `policy: sync` deleted them all.

**Why `upsert-only` is required for Pi-hole:**

`policy: upsert-only` means external-dns will only add or update records it owns — it will never delete records it didn't create. This is the only safe policy for any shared DNS backend.

`policy: sync` is designed for DNS backends where external-dns has **exclusive ownership** of the zone (Route53, CloudFlare zones, etc.) and is the single writer. Pi-hole is not that.

**Contributing factor:** The Pi-hole provider (`PiholeApiVersion: 6`) does not support ownership records (TXT registry). external-dns was configured with `--registry=noop`, meaning it cannot distinguish records it created from records created by other means. With `policy: sync` and `registry: noop`, every non-ingress record is invisible to external-dns and gets deleted on the next sync cycle.

---

### Root Cause 2 — Kyverno autogen generating a broken controller rule from a Pod-targeting rule

**Background on Kyverno autogen:**

Kyverno's autogen feature automatically generates additional policy rules to cover pod controllers (Deployment, StatefulSet, DaemonSet, Job, CronJob) when a policy targets bare `Pod` objects. The intent is to catch violations at the controller level before the pod is even created. autogen rewrites the rule to match the controller kind and adjusts field paths — for example, `spec.containers` becomes `spec.template.spec.containers`.

**What happened:**

The `inject-namespace-labels` ClusterPolicy was modified to also target `Pod` objects. This triggered autogen to generate an `autogen-inject-namespace-labels-pods` rule that matched `Deployment/StatefulSet/DaemonSet`. The autogen rule rewrote the apiCall URL in the context:

**Original rule (written by hand, targeting Pod):**
```
/api/v1/namespaces/{{ request.object.metadata.namespace }}
```

**Autogen-generated rule (targeting Deployment/StatefulSet/DaemonSet):**
```
/api/v1/namespaces/{{ request.object.spec.template.metadata.namespace }}
```

`request.object.spec.template.metadata.namespace` does not exist on Deployment objects. The `namespace` field is not part of the pod template spec — it is inherited at runtime from the Deployment's own namespace. Kyverno's autogen blindly applied the same field-path rewriting rules it uses for `spec.containers` → `spec.template.spec.containers`, but this does not apply to `metadata.namespace`.

**Why this blocked everything:**

The Kyverno mutating webhook for the `inject-namespace-labels` policy is registered as `mutate.kyverno.svc-fail` — fail-closed (`failurePolicy: Fail`). When the autogen rule failed to evaluate (JMESPath error: `Unknown key "namespace" in path`), Kyverno returned an admission denial instead of a partial success. Every Deployment mutation in the cluster was blocked.

**Why deleting the policy didn't immediately fix it (two-layer cache problem):**

After deleting the ClusterPolicy object, the Kyverno admission controller pods continued to deny requests. This happened for two reasons:

1. **Kyverno in-memory cache:** The admission controller compiles policies into an in-memory cache on startup and on policy change events. Deletion of a policy should trigger cache invalidation, but the running pods still held the compiled rule in memory. A `kubectl rollout restart deployment/kyverno-admission-controller` was required to force a clean reload from etcd with the policy gone.

2. **Helm release failure state in etcd:** Even after the Kyverno cache was cleared, the external-dns HelmRelease continued to report the old webhook denial error. This was because Flux's HelmRelease controller was retrying a Helm upgrade that had already been recorded as failed (revision 4 = failed) in the Helm release history stored in etcd. Flux replays the stored failure reason in its status. The HelmRelease was stuck in an upgrade-retry loop replaying a stale failure, not issuing a live webhook call. `helm rollback external-dns` was required to move the Helm release to a clean `deployed` state (revision 5 = rollback to 3), which allowed Flux to treat the next reconcile as a fresh upgrade attempt.

**The fix:**

Adding `pod-policies.kyverno.io/autogen-controllers: none` to the annotations of both policies disables autogen entirely for those policies. No autogen rules are generated. The `inject-namespace-labels` rule explicitly targets `Deployment/StatefulSet/DaemonSet` and already patches `spec.template.metadata.labels` directly — autogen would be redundant and was never needed. The `inject-pod-labels` rule targets bare `Pod` only and requires no controller variants.

---

## Impact

| Component | Impact |
|---|---|
| Infrastructure DNS | All non-ingress A records deleted twice. Hosts unreachable by name for ~15–20 minutes each wipe. |
| vCenter | Unreachable by DNS during outage windows |
| ESXi nodes (3) | Unreachable by DNS during outage windows |
| TrueNAS | Unreachable by DNS during outage windows |
| k8s nodes (9) | Unreachable by DNS during outage windows |
| All cluster mutations | Blocked for ~2 hours — no pod creation, no HelmRelease upgrades, no Flux reconciliation |
| CNPG shlink-db | Cluster stuck in "Setting up primary" — initdb pod could not be created during Kyverno block |
| external-dns HelmRelease | Stuck in upgrade-failed state for ~1 hour |

---

## Resolution Steps (Ordered)

The order matters — step 2 cannot succeed until step 1 is complete.

### 1. Clear the Kyverno webhook block

```bash
# Delete the broken ClusterPolicies (the in-cluster objects, not git)
kubectl delete clusterpolicy inject-namespace-labels
kubectl delete clusterpolicy inject-pod-labels

# Restart Kyverno admission controller to clear in-memory policy cache
kubectl rollout restart deployment/kyverno-admission-controller -n kyverno
kubectl rollout status deployment/kyverno-admission-controller -n kyverno --timeout=120s

# Verify webhook is now passing mutations (expected: only validate webhook fires, not mutate)
kubectl create deployment test-webhook --image=nginx:1.25 -n default --dry-run=server 2>&1
# Should see: "blocked due to restrict-default-namespace" (validate, expected)
# Should NOT see: "mutate.kyverno.svc-fail denied" (mutate block = still broken)
```

### 2. Clear the Helm release failure state and upgrade

```bash
# Check Helm release history to understand current revision state
helm history external-dns -n external-dns

# If a revision is in "failed" state, roll back to the last "deployed" revision
helm rollback external-dns -n external-dns   # rolls back to last good revision

# Force Flux to reconcile fresh (not replay cached failure)
flux reconcile source helm external-dns-repo -n flux-system
flux reconcile helmrelease external-dns -n external-dns

# Verify upgrade succeeded
flux get helmrelease external-dns -n external-dns
# Should show: READY=True, MESSAGE="Helm upgrade succeeded"

# Verify policy is correct in running pod
kubectl logs -n external-dns deployment/external-dns --tail=20 | grep "Policy:"
# Must show: Policy:upsert-only
# Must NOT show any DELETE log lines
```

### 3. Restore infrastructure DNS records

Authoritative record list: `c:/git/homelab-infrastructure/hosts/pihole1/configs/pihole/pihole.toml`, `dns.hosts` array, lines 102–158.

```bash
TOKEN=$(op read "op://Homelab/Recordimporter/credential")

# POST to both Pi-holes
# Body: {"domain":"<fqdn>","ip":"<ip>"}
# Header: Authorization: Bearer $TOKEN
# Endpoint: POST http://192.168.100.2:5001/add-a-record
#           POST http://192.168.100.3:5001/add-a-record
# HTTP 200/201/409 = success (409 = already exists, safe to ignore)

# Verify key records after restore
nslookup vcenter.vollminlab.com 192.168.100.2    # must return 192.168.151.5
nslookup esxi01.vollminlab.com 192.168.100.2     # must return 192.168.151.2
nslookup truenas.vollminlab.com 192.168.100.2    # must return 192.168.152.2
```

### 4. Fix and re-enable the Kyverno policies

```bash
# Edit both policy files to add autogen-disable annotation:
# clusters/vollminlab-cluster/kyverno/kyverno/policies/inject-namespace-labels.yaml
# clusters/vollminlab-cluster/kyverno/kyverno/policies/inject-pod-labels.yaml

# Add under metadata.annotations:
#   pod-policies.kyverno.io/autogen-controllers: none

# Apply directly to cluster to verify no autogen rules are generated
kubectl apply -f clusters/vollminlab-cluster/kyverno/kyverno/policies/inject-namespace-labels.yaml
kubectl apply -f clusters/vollminlab-cluster/kyverno/kyverno/policies/inject-pod-labels.yaml

# Verify: only the original rules, no autogen-* variants
kubectl get clusterpolicy inject-namespace-labels -o jsonpath='{.spec.rules[*].name}'
# Must output: inject-namespace-labels  (only one rule, no autogen-*)

# Test mutation works end-to-end
kubectl patch deployment external-dns -n external-dns --type=json \
  -p='[{"op":"replace","path":"/spec/replicas","value":1}]'
# Must succeed without webhook denial

# Commit, PR, merge
# Then resume kyverno-policies Kustomization:
flux resume kustomization kyverno-policies -n flux-system
```

### 5. Verify full recovery

```bash
# All Kyverno policies Ready
kubectl get clusterpolicy

# No autogen rules in either inject policy
kubectl get clusterpolicy inject-namespace-labels -o jsonpath='{.spec.rules[*].name}'
kubectl get clusterpolicy inject-pod-labels -o jsonpath='{.spec.rules[*].name}'

# All Flux Kustomizations green (none suspended except intentional)
flux get kustomizations -A | grep -v "True$"

# All HelmReleases green
flux get helmreleases -A | grep -v "True$"

# external-dns: upsert-only, no deletes
kubectl logs -n external-dns deployment/external-dns --tail=10 | grep -i "Policy\|DELETE"

# DNS spot checks
nslookup vcenter.vollminlab.com 192.168.100.2
nslookup k8scp01.vollminlab.com 192.168.100.2
nslookup homepage.vollminlab.com 192.168.100.2
```

---

## What We Are Preventing Going Forward

### Prevention 1 — `policy: sync` is permanently forbidden for Pi-hole external-dns

See `.claude/rules/external-dns.md`. Pi-hole is a shared DNS backend with records external-dns did not create. `policy: sync` will always delete them. `upsert-only` is the only safe policy. This is enforced in the Helm values ConfigMap and documented as a hard constraint.

### Prevention 2 — Kyverno autogen must be disabled on all label-injection policies

See `.claude/rules/kyverno.md` (updated). Any policy that uses an `apiCall` context with a namespace lookup must have `pod-policies.kyverno.io/autogen-controllers: none` to prevent autogen from rewriting the URL with non-existent field paths. This constraint is documented with the specific failure mode.

### Prevention 3 — Never mix Pod and controller kinds in the same Kyverno rule

A single rule that matches both `Pod` and `Deployment` (or any controller) triggers autogen in unpredictable ways. Pod rules and controller rules must always be in separate ClusterPolicies. This is now documented in kyverno.md.

### Prevention 4 — Kyverno failurePolicy runbook

The immediate unblock procedure (delete policy → restart admission controller → verify with dry-run) is now documented in this incident and in `.claude/rules/kyverno.md`. The key insight: webhook cache is separate from etcd — deleting the policy object is not enough; the pods must be restarted.

### Prevention 5 — Helm release failure state runbook

When a HelmRelease is stuck replaying a stale failure (READY=False but the underlying cause is fixed), the procedure is: `helm history` → `helm rollback` → `flux reconcile`. This is now in `.claude/rules/flux.md`.

---

## Post-Incident Action Items

| Item | Status | PR |
|---|---|---|
| Set `policy: upsert-only` in external-dns ConfigMap | Done | Was already on main before incident |
| Add `pod-policies.kyverno.io/autogen-controllers: none` to inject-namespace-labels and inject-pod-labels | Done | #271 |
| Document external-dns Pi-hole constraint | Done | This PR |
| Update kyverno.md with autogen rules and failurePolicy runbook | Done | This PR |
| Update flux.md with Helm release failure-state runbook | Done | This PR |
| Add incident tracking rule | Done | This PR |
| Fix CNPG shlink-db-credentials missing `username` key | Done | #240 |

---

## Lessons Learned

1. **Shared DNS backends require read-only-safe policies.** external-dns `policy: sync` is dangerous in any multi-writer DNS environment. The Pi-hole provider's lack of TXT registry support compounds this — there is no ownership tracking at all, so every non-ingress record looks stale.

2. **Kyverno autogen is powerful and dangerous.** It silently generates rules that may not behave the same as the hand-written rule. apiCall context variables that reference `request.object.metadata.*` are safe for Pod rules but get rewritten to `request.object.spec.template.metadata.*` in autogen variants — and those fields don't always exist. Always check generated rules with `kubectl get clusterpolicy <name> -o yaml` after applying.

3. **Fail-closed webhooks amplify policy bugs.** A single broken policy in Kyverno's fail-closed mutating webhook blocks the entire cluster. The blast radius of a policy bug is proportional to how broadly the webhook is configured. This is a fundamental Kyverno design tradeoff — fail-closed is correct for security enforcement, but recovery procedures must be known in advance.

4. **Two separate caches must be cleared during recovery.** Kyverno has an in-memory policy cache (cleared by pod restart) and Helm has a release state in etcd (cleared by rollback). Both must be cleared in sequence before a reconcile attempt will succeed. Retrying the reconcile between these steps produces misleading output that looks like the webhook is still broken.

5. **DNS record backups must be in a form that is scriptable.** The pihole.toml `dns.hosts` array served as the authoritative backup and the pihole-flask-api enabled automated restore. Without both of these, manual re-entry of 55 records would have extended the outage significantly.
