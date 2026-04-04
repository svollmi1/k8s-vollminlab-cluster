---
description: Flux CD conventions, repo layout, HelmRelease patterns, and reconciliation commands for k8s-vollminlab-cluster
---

# Flux CD Rules

## Repo layout

```
bootstrap/                        # NOT Flux-managed — manual DR reference only
clusters/vollminlab-cluster/
  flux-system/
    repositories/                 # HelmRepository + GitRepository CRDs (one file each)
    flux-kustomizations/          # Flux Kustomization CRs (one per namespace/app group)
  [namespace]/
    namespace.yaml
    kustomization.yaml            # Aggregates all resources in this namespace
    [app]/app/                    # Per-app: helmrelease.yaml, configmap.yaml, ingress.yaml, etc.
```

## App file structure (every app)

```
helmrelease.yaml       # Required — HelmRelease CR
configmap.yaml         # Required — Helm values via valuesFrom ConfigMap
kustomization.yaml     # Required — lists all resources in this dir
ingress.yaml           # Optional
pvc-*.yaml             # Optional
*-sealedsecret.yaml    # Optional (never plain Secret)
networkpolicy.yaml     # Optional (required in dmz/)
```

To add a new app, also create a Flux Kustomization CR in `flux-system/flux-kustomizations/`.

## HelmRelease template

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: [app-name]
  namespace: [namespace]
  labels:
    app: [app-name]
    env: production
    category: [category]          # see kyverno.md for valid categories
spec:
  interval: 10m
  chart:
    spec:
      chart: [chart-name]
      version: [pinned-semver]    # never * or floating ranges
      sourceRef:
        kind: HelmRepository
        name: [repo-name]         # named after the app, not the chart author
        namespace: flux-system
  valuesFrom:
    - kind: ConfigMap
      name: [app-name]-values
```

## HelmRepository convention

- File named `[app-name]-helmrepository.yaml`
- `metadata.name: [app-name]-repo` — always suffix with `-repo`, no exceptions
- Named after the **app being deployed**, not the chart author — e.g. `shlink-repo`, `longhorn-repo`, `cert-manager-repo` — not `christianhuth`, `rancher`, `jetstack`
- `sourceRef.name` in every HelmRelease must match the HelmRepository `metadata.name` exactly (i.e. always include the `-repo` suffix)

## Required labels — all resource kinds

Every resource in this repo must have these three labels. Kyverno enforces on pods; we apply them consistently to all kinds for uniformity.

| Kind | Required labels |
|------|----------------|
| HelmRelease | `app`, `env: production`, `category` |
| HelmRepository / OCIRepository | `app`, `env: production`, `category` |
| Namespace | `app`, `env: production`, `category` |
| Ingress | `app`, `env: production`, `category` |
| Flux Kustomization CR | `app`, `env: production`, `category` |
| ConfigMap (values) | `app`, `env: production`, `category` |

See `kyverno.md` for valid `category` values.

## Critical rules

- **Never manually apply** manifests under `clusters/` — Flux reconciles from `main` within 10 minutes.
- **Never push directly to `main`** — branch protection enforced via Terraform, PR required.
- **Never use `:latest`** chart version ranges or image tags.
- `bootstrap/` is for DR reference only; changes there have no effect on the cluster.

## Useful commands

```bash
# Check reconciliation state
flux get kustomizations -A
flux get helmreleases -A

# Force reconciliation
flux reconcile kustomization [name] --with-source

# Check a specific HelmRelease
flux get helmrelease [name] -n [namespace]

# Debug events
kubectl describe helmrelease [name] -n [namespace]
kubectl get events -n [namespace] --sort-by=.lastTimestamp
```
