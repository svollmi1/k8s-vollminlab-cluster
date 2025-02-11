#!/bin/bash

# Set base directory for repo output
# Set base directory relative to the script location
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/clusters/vollminlab-cluster"

# Ensure output directories exist
mkdir -p $OUTPUT_DIR/{apps,system,storage,crds,operators,helm-releases}

echo "🔍 Extracting non-Helm Deployments..."
kubectl get deployments -A --no-headers | awk '{print $1, $2}' | while read ns name; do 
    if ! helm list -A | grep -q "$name"; then 
        APP_DIR="$OUTPUT_DIR/apps/$name"
        mkdir -p "$APP_DIR"
        kubectl get deployment "$name" -n "$ns" -o yaml > "$APP_DIR/deployment.yaml"
        kubectl get service "$name" -n "$ns" -o yaml > "$APP_DIR/service.yaml" 2>/dev/null
        kubectl get ingress "$name" -n "$ns" -o yaml > "$APP_DIR/ingress.yaml" 2>/dev/null
        echo "✅ Extracted $name in namespace $ns"
    fi 
done

echo "🔍 Extracting Helm Releases..."
helm list -A -o json | jq -c '.[]' | while read obj; do
    name=$(echo $obj | jq -r '.name')
    ns=$(echo $obj | jq -r '.namespace')
    chart=$(echo $obj | jq -r '.chart' | cut -d'-' -f1)
    version=$(echo $obj | jq -r '.app_version')
    RELEASE_FILE="$OUTPUT_DIR/helm-releases/$name.yaml"

    cat <<EOF > "$RELEASE_FILE"
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: $name
  namespace: $ns
spec:
  interval: 10m
  chart:
    spec:
      chart: $chart
      version: $version
      sourceRef:
        kind: HelmRepository
        name: $chart
        namespace: flux-system
  values:
EOF

    helm get values "$name" -n "$ns" -o yaml >> "$RELEASE_FILE"
    echo "✅ Extracted HelmRelease for $name in namespace $ns"
done

echo "🔍 Extracting Persistent Volumes (PVs) and Persistent Volume Claims (PVCs)..."
kubectl get pv -o yaml > "$OUTPUT_DIR/storage/pvs.yaml"
kubectl get pvc -A -o yaml > "$OUTPUT_DIR/storage/pvcs.yaml"

echo "🔍 Extracting Custom Resource Definitions (CRDs)..."
kubectl get crds -o yaml > "$OUTPUT_DIR/crds/all-crds.yaml"

echo "🔍 Extracting ConfigMaps & Secrets..."
kubectl get configmaps -A -o yaml > "$OUTPUT_DIR/system/configmaps.yaml"
kubectl get secrets -A -o yaml > "$OUTPUT_DIR/system/secrets.yaml"

echo "🔍 Extracting System Components..."
kubectl get all -n kube-system -o yaml > "$OUTPUT_DIR/system/kube-system.yaml"

echo "✅ All resources extracted! Now commit and push to Git."

