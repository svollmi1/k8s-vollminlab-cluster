---
description: SealedSecrets workflow — how to create, seal, and manage secrets in k8s-vollminlab-cluster
---

# Secrets Rules

## Hard rule: never commit plain Secrets

All secrets in this repo **must** be `SealedSecret` resources (kind: `SealedSecret`, apiVersion: `bitnami.com/v1alpha1`). A plain `kind: Secret` object must never be committed.

## Creating a sealed secret

```bash
# 1. Fetch the current sealing certificate
kubeseal --fetch-cert \
  --controller-namespace sealed-secrets \
  --controller-name sealed-secrets > pub-cert.pem

# 2. Create and seal (pipe, never write the plain secret to disk)
kubectl create secret generic my-secret -n my-namespace \
  --from-literal=key=value \
  --dry-run=client -o yaml | \
  kubeseal --cert pub-cert.pem --format yaml > my-secret-sealedsecret.yaml

# 3. Delete pub-cert.pem when done (it's public, but no need to keep it)
```

## Sealing key backup

The controller's sealing key is backed up in **1Password** as **"Sealed Secrets Sealing Key"** (Homelab vault). Must be restored before running Flux bootstrap on a rebuilt cluster. Procedure documented in `bootstrap/sealed-secrets/`.

## Referencing secrets in HelmRelease values

Use `valuesFrom` with a `Secret` kind — but the secret itself must be sealed:

```yaml
valuesFrom:
  - kind: Secret
    name: my-app-credentials
    valuesKey: helm-values.yaml
```

Or use `extraEnv` with `secretKeyRef` in the ConfigMap values:

```yaml
extraEnv:
  - name: MY_PASSWORD
    valueFrom:
      secretKeyRef:
        name: my-app-credentials
        key: password
```

## Naming convention

Sealed secret files: `[app-name]-[purpose]-sealedsecret.yaml`
Secret name matches: `[app-name]-[purpose]` or `[app-name]-credentials`
