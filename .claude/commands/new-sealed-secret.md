# Create a New Sealed Secret

Guide for creating a SealedSecret to store sensitive values safely in Git.

## Usage

`/project:new-sealed-secret [secret-name] [namespace]`

## Why SealedSecrets

Plain Kubernetes `Secret` objects must never be committed to this repo. SealedSecrets encrypt the secret with the cluster's public key — only the sealed-secrets controller can decrypt it. The sealing key is backed up in 1Password ("Sealed Secrets Sealing Key").

## Steps

### 1. Fetch the cluster's public certificate

```bash
kubeseal --fetch-cert \
  --controller-namespace sealed-secrets \
  --controller-name sealed-secrets \
  > pub-cert.pem
```

### 2. Create and seal the secret

For literal key/value pairs:
```bash
kubectl create secret generic [secret-name] \
  -n [namespace] \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  --dry-run=client -o yaml | \
  kubeseal --cert pub-cert.pem --format yaml \
  > [secret-name]-sealedsecret.yaml
```

For a file (e.g., a credentials file):
```bash
kubectl create secret generic [secret-name] \
  -n [namespace] \
  --from-file=credentials.json \
  --dry-run=client -o yaml | \
  kubeseal --cert pub-cert.pem --format yaml \
  > [secret-name]-sealedsecret.yaml
```

### 3. Add to the app's kustomization.yaml

```yaml
resources:
  - helmrelease.yaml
  - configmap.yaml
  - [secret-name]-sealedsecret.yaml   # add this line
```

### 4. Reference in HelmRelease (if needed)

```yaml
spec:
  valuesFrom:
    - kind: Secret
      name: [secret-name]
      valuesKey: key1
      targetPath: some.helm.value
```

## Important

- Never commit `pub-cert.pem` or the unseal plain secret to Git
- The `.gitignore` should prevent accidental commits of plain secrets — verify if uncertain
- SealedSecrets are namespace-scoped by default — a secret sealed for `mediastack` cannot be used in `dmz`
- If the sealing key is ever lost, restore it from 1Password before redeploying sealed-secrets (see `bootstrap/sealed-secrets/README.md`)
