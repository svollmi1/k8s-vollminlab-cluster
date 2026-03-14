# Kubernetes Vollminlab Cluster

A GitOps-managed Kubernetes cluster configuration using Flux CD for automated deployment and management.

## Architecture

This repository contains the complete configuration for a Kubernetes cluster managed with:

- **Flux CD** - GitOps toolkit for continuous delivery
- **GitHub Actions** - CI/CD pipeline with comprehensive validation
- **Terraform** - Infrastructure as Code for GitHub branch protection
- **Kustomize** - Kubernetes native configuration management

## Repository Structure

```
├── bootstrap/                        # Manual bootstrap reference (not Flux-managed)
│   ├── calico/                       # Calico CNI — apply before Flux bootstraps
│   └── coredns/                      # CoreDNS config reference
├── clusters/vollminlab-cluster/
│   ├── actions-runner-system/        # GitHub Actions self-hosted runners
│   ├── cert-manager/                 # Certificate management
│   ├── clusterwide/                  # Cluster-wide resources (PVs, StorageClasses, RBAC)
│   ├── dmz/                          # DMZ workloads (Minecraft)
│   ├── elastic-system/               # ECK Operator
│   ├── flux-system/                  # Flux CD — HelmRepositories and Kustomizations
│   ├── homepage/                     # Homepage dashboard
│   ├── ingress-nginx/                # Ingress controller
│   ├── kube-system/                  # metrics-server, smb-csi-driver
│   ├── kyverno/                      # Policy engine, policies, policy-reporter
│   ├── local-path-storage/           # Local path provisioner
│   ├── longhorn-system/              # Distributed block storage
│   ├── mediastack/                   # Sonarr, Radarr, Bazarr, Prowlarr, SABnzbd, Overseerr, Tautulli
│   ├── metallb-system/               # Bare-metal load balancer
│   ├── monitoring/                   # Monitoring stack (planned)
│   ├── portainer/                    # Container management UI
│   └── sealed-secrets/               # Encrypted secrets in Git
├── scripts/                          # Utility scripts
└── terraform/                        # GitHub branch protection
```

## Bootstrap Order

For a full cluster rebuild, components must be applied in this order:

1. **Kubernetes control plane** — kubeadm
2. **Calico CNI** — must exist before any pods can communicate; see `bootstrap/calico/`
3. **Flux CD** — bootstraps from this repository
4. **Everything else** — Flux reconciles all remaining workloads automatically

## Key Components

### Storage
- **Longhorn** — distributed block storage (RWO + RWX)
- **SMB CSI Driver** — SMB/CIFS volume mounts
- **Local Path Provisioner** — local node storage

### Networking
- **Calico** — CNI with BGP and IPIP encapsulation
- **MetalLB** — bare-metal load balancer
- **ingress-nginx** — ingress controller
- **cert-manager** — TLS certificate automation

### Security & Policy
- **Kyverno** — policy enforcement (enforce mode)
- **SealedSecrets** — encrypted secrets committed to git
- **RBAC** — role-based access control throughout

### CI/CD
- **Flux CD** — GitOps reconciliation from main branch
- **GitHub Actions** — manifest validation, Kyverno policy checks, security scanning
- **Actions Runner Controller** — self-hosted runners for CI

## Making Changes

1. Create a feature branch from `main`
2. Make changes and push
3. CI runs: manifest validation, Kyverno policy checks, Trivy security scan
4. Create a Pull Request — requires CI to pass
5. Merge to `main` — Flux reconciles within 10 minutes

## Security

- **Branch protection** — enforced via Terraform, CI required before merge
- **Kyverno policies** — block default namespace, restrict privileged containers, require labels, restrict LoadBalancer services
- **SealedSecrets** — secrets encrypted with cluster-specific key, safe to commit
- **Network segmentation** — DMZ workloads isolated via Kyverno NetworkPolicy policies
