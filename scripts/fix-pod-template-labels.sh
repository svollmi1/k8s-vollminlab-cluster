#!/bin/bash
set -euo pipefail

echo "🔧 Adding required labels to pod templates for all deployments..."

# Kyverno namespace
echo "Patching kyverno namespace deployments..."
kubectl patch deployment kyverno-admission-controller -n kyverno --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"kyverno","env":"production","category":"security"}}}}}'
kubectl patch deployment kyverno-background-controller -n kyverno --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"kyverno","env":"production","category":"security"}}}}}'
kubectl patch deployment kyverno-cleanup-controller -n kyverno --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"kyverno","env":"production","category":"security"}}}}}'
kubectl patch deployment kyverno-reports-controller -n kyverno --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"kyverno","env":"production","category":"security"}}}}}'
kubectl patch deployment policy-reporter -n kyverno --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"policy-reporter","env":"production","category":"security"}}}}}'
kubectl patch deployment policy-reporter-ui -n kyverno --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"policy-reporter","env":"production","category":"security"}}}}}'

# Longhorn namespace
echo "Patching longhorn-system namespace deployments..."
kubectl patch deployment csi-attacher -n longhorn-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"longhorn","env":"production","category":"storage"}}}}}'
kubectl patch deployment csi-provisioner -n longhorn-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"longhorn","env":"production","category":"storage"}}}}}'
kubectl patch deployment csi-resizer -n longhorn-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"longhorn","env":"production","category":"storage"}}}}}'
kubectl patch deployment csi-snapshotter -n longhorn-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"longhorn","env":"production","category":"storage"}}}}}'
kubectl patch deployment longhorn-driver-deployer -n longhorn-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"longhorn","env":"production","category":"storage"}}}}}'
kubectl patch deployment longhorn-ui -n longhorn-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"longhorn","env":"production","category":"storage"}}}}}'

# Patch DaemonSets in longhorn-system
kubectl patch daemonset engine-image-ei-db6c2b6f -n longhorn-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"longhorn","env":"production","category":"storage"}}}}}'
kubectl patch daemonset longhorn-csi-plugin -n longhorn-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"longhorn","env":"production","category":"storage"}}}}}'
kubectl patch daemonset longhorn-manager -n longhorn-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"longhorn","env":"production","category":"storage"}}}}}'

# Mediastack namespace
echo "Patching mediastack namespace deployments..."
kubectl patch deployment overseerr -n mediastack --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"overseerr","env":"production","category":"media"}}}}}'
kubectl patch deployment prowlarr -n mediastack --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"prowlarr","env":"production","category":"media"}}}}}'
kubectl patch deployment radarr -n mediastack --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"radarr","env":"production","category":"media"}}}}}'
kubectl patch deployment sabnzbd -n mediastack --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"sabnzbd","env":"production","category":"media"}}}}}'
kubectl patch deployment sonarr -n mediastack --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"sonarr","env":"production","category":"media"}}}}}'

# Metallb namespace
echo "Patching metallb-system namespace deployments..."
kubectl patch deployment metallb-controller -n metallb-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"metallb","env":"production","category":"networking"}}}}}'

# Patch DaemonSet in metallb-system
kubectl patch daemonset metallb-speaker -n metallb-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"metallb","env":"production","category":"networking"}}}}}'

# Sealed-secrets namespace
echo "Patching sealed-secrets namespace deployments..."
kubectl patch deployment sealed-secrets-controller -n sealed-secrets --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"sealed-secrets","env":"production","category":"security"}}}}}'

# Homepage namespace
echo "Patching homepage namespace deployments..."
kubectl patch deployment homepage -n homepage --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"homepage","env":"production","category":"dashboard"}}}}}'

# Flux-system namespace
echo "Patching flux-system namespace deployments..."
kubectl patch deployment capacitor -n flux-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"flux","env":"production","category":"gitops"}}}}}'
kubectl patch deployment helm-controller -n flux-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"flux","env":"production","category":"gitops"}}}}}'
kubectl patch deployment kustomize-controller -n flux-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"flux","env":"production","category":"gitops"}}}}}'
kubectl patch deployment notification-controller -n flux-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"flux","env":"production","category":"gitops"}}}}}'
kubectl patch deployment source-controller -n flux-system --type merge -p '{"spec":{"template":{"metadata":{"labels":{"app":"flux","env":"production","category":"gitops"}}}}}'

echo "✅ All pod template labels patched!"
