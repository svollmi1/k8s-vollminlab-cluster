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

## Adding a new app — two explicit indexes MUST be updated

Both of these files are **explicit lists**, not globs. Flux will silently ignore any file not listed. Missing either one means the app never deploys.

### 1. `flux-system/flux-kustomizations/kustomization.yaml`
Add `- [app]-kustomization.yaml` to the `resources` list.
This is what causes Flux to pick up and reconcile the new Kustomization CR.

### 2. `flux-system/repositories/kustomization.yaml`
Add `- [app]-helmrepository.yaml` (or `-gitrepository.yaml`) to the `resources` list.
This is what causes Flux to sync the chart source. Without it the HelmRelease can never pull the chart.

**Both must be in the same PR as the app files. Never add an app without updating both.**

## HelmRelease templates

**Standard HTTP Helm registry** (use `spec.chart.spec.sourceRef` → `HelmRepository`):
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
        name: [app-name]-repo
        namespace: flux-system
  valuesFrom:
    - kind: ConfigMap
      name: [app-name]-values
```

**OCI registry** (use `spec.chartRef` → `OCIRepository`):
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: [app-name]
  namespace: [namespace]
  labels:
    app: [app-name]
    env: production
    category: [category]
spec:
  interval: 10m
  chartRef:
    kind: OCIRepository
    name: [app-name]-repo
    namespace: flux-system
  valuesFrom:
    - kind: ConfigMap
      name: [app-name]-values
```

Note: version is pinned in the `OCIRepository` `spec.ref.tag`, not in the HelmRelease.

## Source repository conventions

- File always named `[app-name]-helmrepository.yaml` regardless of kind
- `metadata.name: [app-name]-repo` — always suffix with `-repo`, no exceptions
- Named after the **app being deployed**, not the chart author

**HTTP Helm registry** → `kind: HelmRepository` (`source.toolkit.fluxcd.io/v1`):
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: [app-name]-repo
  namespace: flux-system
  labels:
    app: [app-name]
    env: production
    category: [category]
spec:
  interval: 1h
  url: https://[chart-repo-url]
```

**OCI registry** → `kind: OCIRepository` (`source.toolkit.fluxcd.io/v1beta2`). **Do not use `HelmRepository type: oci` — it is in maintenance mode.**
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: OCIRepository
metadata:
  name: [app-name]-repo
  namespace: flux-system
  labels:
    app: [app-name]
    env: production
    category: [category]
spec:
  interval: 1h
  url: oci://[registry]/[chart-name]
  ref:
    tag: "[pinned-semver]"
  layerSelector:
    mediaType: "application/vnd.cncf.helm.chart.content.v1.tar+gzip"
    operation: copy
```

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
