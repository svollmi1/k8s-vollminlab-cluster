#!/bin/bash
set -euo pipefail

echo "🔧 Adding required labels to all deployments..."

# Kyverno namespace
echo "Patching kyverno namespace deployments..."
kubectl patch deployment kyverno-background-controller -n kyverno --type merge -p '{"metadata":{"labels":{"app":"kyverno","env":"production","category":"security"}}}'
kubectl patch deployment kyverno-cleanup-controller -n kyverno --type merge -p '{"metadata":{"labels":{"app":"kyverno","env":"production","category":"security"}}}'
kubectl patch deployment kyverno-reports-controller -n kyverno --type merge -p '{"metadata":{"labels":{"app":"kyverno","env":"production","category":"security"}}}'
kubectl patch deployment policy-reporter -n kyverno --type merge -p '{"metadata":{"labels":{"app":"policy-reporter","env":"production","category":"security"}}}'
kubectl patch deployment policy-reporter-ui -n kyverno --type merge -p '{"metadata":{"labels":{"app":"policy-reporter","env":"production","category":"security"}}}'

# Longhorn namespace
echo "Patching longhorn-system namespace deployments..."
kubectl patch deployment longhorn-ui -n longhorn-system --type merge -p '{"metadata":{"labels":{"app":"longhorn","env":"production","category":"storage"}}}'
kubectl patch deployment longhorn-driver-deployer -n longhorn-system --type merge -p '{"metadata":{"labels":{"app":"longhorn","env":"production","category":"storage"}}}'

# Mediastack namespace
echo "Patching mediastack namespace deployments..."
kubectl patch deployment overseerr -n mediastack --type merge -p '{"metadata":{"labels":{"app":"overseerr","env":"production","category":"media"}}}'
kubectl patch deployment prowlarr -n mediastack --type merge -p '{"metadata":{"labels":{"app":"prowlarr","env":"production","category":"media"}}}'
kubectl patch deployment radarr -n mediastack --type merge -p '{"metadata":{"labels":{"app":"radarr","env":"production","category":"media"}}}'
kubectl patch deployment sabnzbd -n mediastack --type merge -p '{"metadata":{"labels":{"app":"sabnzbd","env":"production","category":"media"}}}'
kubectl patch deployment sonarr -n mediastack --type merge -p '{"metadata":{"labels":{"app":"sonarr","env":"production","category":"media"}}}'

# Metallb namespace
echo "Patching metallb-system namespace deployments..."
kubectl patch deployment metallb-controller -n metallb-system --type merge -p '{"metadata":{"labels":{"app":"metallb","env":"production","category":"networking"}}}'

# Sealed-secrets namespace
echo "Patching sealed-secrets namespace deployments..."
kubectl patch deployment sealed-secrets-controller -n sealed-secrets --type merge -p '{"metadata":{"labels":{"app":"sealed-secrets","env":"production","category":"security"}}}'

# Actions-runner-system namespace
echo "Patching actions-runner-system namespace deployments..."
kubectl patch deployment actions-runner-controller -n actions-runner-system --type merge -p '{"metadata":{"labels":{"app":"actions-runner","env":"production","category":"ci"}}}'

# Homepage namespace
echo "Patching homepage namespace deployments..."
kubectl patch deployment homepage -n homepage --type merge -p '{"metadata":{"labels":{"app":"homepage","env":"production","category":"dashboard"}}}'

echo "✅ All deployments patched with required labels!"
