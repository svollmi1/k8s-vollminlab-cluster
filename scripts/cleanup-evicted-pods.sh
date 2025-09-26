#!/bin/bash

# Script to clean up evicted and problematic pods
# This addresses the immediate disk pressure issues

echo "🧹 Starting pod cleanup..."

# Clean up evicted pods
echo "Cleaning up evicted pods..."
kubectl get pods --all-namespaces --field-selector=status.phase=Evicted -o name | xargs -r kubectl delete

# Clean up completed pods older than 1 hour
echo "Cleaning up old completed pods..."
kubectl get pods --all-namespaces --field-selector=status.phase=Succeeded -o json | \
jq -r '.items[] | select((.status.startTime | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) < (now - 3600)) | "\(.metadata.namespace) \(.metadata.name)"' | \
while read namespace name; do
  kubectl delete pod -n "$namespace" "$name" || true
done

# Clean up failed pods older than 1 hour
echo "Cleaning up old failed pods..."
kubectl get pods --all-namespaces --field-selector=status.phase=Failed -o json | \
jq -r '.items[] | select((.status.startTime | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) < (now - 3600)) | "\(.metadata.namespace) \(.metadata.name)"' | \
while read namespace name; do
  kubectl delete pod -n "$namespace" "$name" || true
done

# Show current status
echo "Current pod status:"
kubectl get pods --all-namespaces | grep -E "(Evicted|Completed|Failed)" || echo "✅ No problematic pods found"

echo "✅ Pod cleanup completed!"
