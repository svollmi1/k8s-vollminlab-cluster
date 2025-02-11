#!/bin/bash

# Set base directory for repo output
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$REPO_DIR/clusters/vollminlab-cluster"

# Ensure output directories exist
mkdir -p $OUTPUT_DIR/{apps,system,storage,crds,operators,helm-releases}

echo "🔍 Extracting all applications including Helm and non-Helm deployments..."

# Extracting all deployments (both Helm and non-Helm) in the cluster
kubectl get deployments -A --no-headers | awk '{print $1, $2}' | while read ns name; do 
    APP_DIR="$OUTPUT_DIR/apps/$name"
    mkdir -p "$APP_DIR"

    # Get the deployment YAML
    kubectl get deployment "$name" -n "$ns" -o yaml > "$APP_DIR/deployment.yaml"

    # Get the service YAML for the deployment (if it exists)
    SERVICE_YAML=$(kubectl get service -n "$ns" | grep "$name" | awk '{print $1}' | while read service; do
        kubectl get service "$service" -n "$ns" -o yaml
    done)

    if [ -n "$SERVICE_YAML" ]; then
        echo "$SERVICE_YAML" > "$APP_DIR/service.yaml"
    fi

    # Get the ingress YAML for the deployment (if it exists)
    INGRESS_YAML=$(kubectl get ingress -n "$ns" | grep "$name" | awk '{print $1}' | while read ingress; do
        kubectl get ingress "$ingress" -n "$ns" -o yaml
    done)

    if [ -n "$INGRESS_YAML" ]; then
        echo "$INGRESS_YAML" > "$APP_DIR/ingress.yaml"
    fi

    # Log success
    echo "✅ Extracted resources for $name in namespace $ns"
done

echo "🔍 Extracting Helm Releases..."

# Extracting Helm releases
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

