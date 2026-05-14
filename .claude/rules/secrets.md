---
description: SealedSecrets workflow — how to create, seal, and manage secrets in k8s-vollminlab-cluster
---

# Secrets Rules

## Hard rules — enforced by CI (gitleaks) and must never be violated

- **Never commit a plain `kind: Secret`** — only `SealedSecret` (bitnami.com/v1alpha1)
- **Never commit API keys, passwords, tokens, or any credential** in any file — YAML, shell script, markdown, or otherwise
- **Never put a secret value in a ConfigMap** — use `secretKeyRef` to reference it from a SealedSecret
- **Never log or echo a secret value** in a CI step or script

The CI runs gitleaks on every PR as a required check ("Secret Scanning"). If it fires, the PR cannot merge. If you generated a value that was accidentally committed, treat it as compromised and rotate it immediately.

Credentials belong in **1Password** (Homelab vault). Kubernetes secrets belong in **SealedSecrets**.

## Creating a sealed secret

```bash
# 1. Fetch the current sealing certificate
kubeseal --fetch-cert \
  --controller-namespace sealed-secrets \
  --controller-name sealed-secrets-controller > pub-cert.pem

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

- `metadata.name`: `{app-name}-{purpose}` — never use `-secret` as a suffix (it's redundant; the kind already says Secret)
- Filename: `{metadata.name}-sealedsecret.yaml` — the filename base **must exactly equal** `metadata.name`
- Common purpose suffixes: `-credentials`, `-token`, `-apikey`, `-config`, `-env-vars`

Examples: `harbor-db-credentials`, `renovate-token`, `alertmanager-pushover-config`

Wrong: `harbor-admin-sealedsecret.yaml` containing `metadata.name: harbor-admin-credentials` — the base (`harbor-admin`) doesn't match the name (`harbor-admin-credentials`).
