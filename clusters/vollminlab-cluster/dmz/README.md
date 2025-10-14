# DMZ Namespace

Secure namespace for hosting externally-accessible services on dedicated DMZ node(s).

## Overview

The DMZ namespace is designed for services that need to be accessible from the internet (e.g., game servers, public APIs) while maintaining strong security isolation from the rest of the cluster.

## Node Configuration

**DMZ Node**: `k8sworker05`
- **Label**: `role=dmz`
- **Taint**: `dmz=true:NoSchedule`
- **IP**: `192.168.152.15`

## Security Model

### 1. Automatic Enforcement (Kyverno)

#### Node Placement (Auto-Applied)
- **Policy**: `dmz-enforce-node-placement` (ClusterPolicy)
- **Action**: Automatically adds `nodeSelector` and `tolerations` to all DMZ pods
- **Benefit**: Developers don't need to remember node placement configuration
- **Result**: All DMZ pods automatically run **only** on k8sworker05

#### External Access Restriction (Validation)
- **Policy**: `dmz-restrict-external-access` (ClusterPolicy)
- **Action**: Blocks `external-access: "true"` and `internet-egress: "true"` labels outside DMZ namespace
- **Benefit**: Prevents accidental or malicious external exposure of internal workloads
- **Result**: Only DMZ namespace can host externally-accessible services

### 2. Default Deny (Network Policies)
All traffic is denied by default via `networkpolicy-default-deny.yaml`

### 3. Selective Allow Policies (Network Policies)

#### DNS Resolution
- **Policy**: `networkpolicy-allow-dns.yaml`
- **Allows**: UDP/TCP port 53 to kube-dns in kube-system namespace
- **Required for**: Service discovery, external domain resolution

#### External Ingress
- **Policy**: `networkpolicy-allow-external-ingress.yaml`
- **Allows**: All ingress traffic from any source (0.0.0.0/0)
- **Applies to**: Pods with label `external-access: "true"`
- **Use for**: NodePort services, LoadBalancer services

#### Internet Egress
- **Policy**: `networkpolicy-allow-internet-egress.yaml`
- **Allows**: Egress to internet (excluding private networks)
- **Applies to**: Pods with label `internet-egress: "true"`
- **Blocks**: RFC 1918 private networks, link-local, loopback
- **Use for**: Downloading updates, external API calls

## Deploying Services

### Example: Minecraft Server

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: minecraft-server
  namespace: dmz
  labels:
    app: minecraft
    env: production
    category: gaming
    external-access: "true"    # Allow external ingress
    internet-egress: "true"    # Allow internet egress
spec:
  # Note: nodeSelector and tolerations are automatically added by Kyverno!
  # You don't need to specify them - the dmz-enforce-node-placement policy
  # will automatically add:
  #   nodeSelector:
  #     role: dmz
  #   tolerations:
  #     - key: dmz
  #       operator: Exists
  #       effect: NoSchedule
  containers:
    - name: minecraft
      image: itzg/minecraft-server:latest
      ports:
        - containerPort: 25565
          protocol: TCP
      env:
        - name: EULA
          value: "TRUE"
---
apiVersion: v1
kind: Service
metadata:
  name: minecraft
  namespace: dmz
  labels:
    app: minecraft
    env: production
    category: gaming
spec:
  type: NodePort
  selector:
    app: minecraft
  ports:
    - port: 25565
      targetPort: 25565
      nodePort: 30565        # Accessible at k8sworker05:30565
      protocol: TCP
```

## Storage

Use the `longhorn-dmz` StorageClass for DMZ-specific persistent storage:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minecraft-data
  namespace: dmz
spec:
  storageClassName: longhorn-dmz
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

## Required Labels

All pods must have the following labels (enforced by Kyverno):
- `app`: Application name
- `env`: Environment (e.g., production, staging)
- `category`: Category (e.g., gaming, api)

## Network Policy Labels

| Label | Purpose | Required For |
|-------|---------|--------------|
| `external-access: "true"` | Allow ingress from internet | NodePort/LoadBalancer services |
| `internet-egress: "true"` | Allow egress to internet | Services needing external API/updates |

## Defense in Depth Layers

The DMZ namespace implements multiple security layers:

1. **Physical Isolation**: k8sworker05 is network-isolated in DMZ
2. **Node Taint**: `dmz=true:NoSchedule` prevents accidental scheduling
3. **Kyverno Mutation**: Auto-adds nodeSelector + tolerations (enforces placement)
4. **Kyverno Validation**: Blocks external access labels outside DMZ (prevents misuse)
5. **Network Policies**: Control ingress/egress at pod level (default deny)
6. **Namespace Labels**: Pod Security Standards enforcement (baseline+)
7. **Storage Isolation**: `longhorn-dmz` StorageClass keeps data on DMZ node

## Best Practices

1. **Minimal Privileges**: Only add `external-access` or `internet-egress` labels when absolutely necessary
2. **Resource Limits**: Always set CPU/memory limits
3. **Health Checks**: Implement liveness and readiness probes
4. **Security Context**: Run as non-root user when possible
5. **Image Scanning**: Use trusted, scanned images
6. **Secrets Management**: Use Sealed Secrets for sensitive data
7. **Labels Required**: All pods must have `app`, `env`, and `category` labels (enforced by Kyverno)

## Monitoring

- Monitor pod status: `kubectl get pods -n dmz`
- Check network policies: `kubectl get networkpolicies -n dmz`
- View events: `kubectl get events -n dmz --sort-by='.lastTimestamp'`

## Troubleshooting

### Pod not scheduled
- Check node taints: `kubectl describe node k8sworker05`
- Verify tolerations in pod spec

### No network connectivity
- Verify pod has correct labels (`external-access`, `internet-egress`)
- Check network policies: `kubectl describe networkpolicy -n dmz`

### DNS not resolving
- DNS is allowed by default via `allow-dns` policy
- Check kube-dns is running: `kubectl get pods -n kube-system -l k8s-app=kube-dns`

