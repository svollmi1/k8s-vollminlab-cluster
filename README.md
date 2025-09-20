# Kubernetes Vollminlab Cluster

A GitOps-managed Kubernetes cluster configuration using Flux CD for automated deployment and management.

## 🏗️ Architecture

This repository contains the complete configuration for a Kubernetes cluster managed with:

- **Flux CD** - GitOps toolkit for continuous delivery
- **GitHub Actions** - CI/CD pipeline with comprehensive validation
- **Terraform** - Infrastructure as Code for GitHub branch protection
- **Kustomize** - Kubernetes native configuration management

## 📁 Repository Structure

```
clusters/vollminlab-cluster/
├── actions-runner-system/     # GitHub Actions runners
├── clusterwide/               # Cluster-wide resources (PVs, StorageClasses, RBAC)
├── elastic-system/           # Elastic Stack (ECK Operator)
├── flux-system/             # Flux CD configuration
├── homepage/                # Homepage dashboard
├── kube-system/            # Core Kubernetes components
├── kyverno/                 # Policy engine and policies
├── longhorn-system/         # Longhorn storage
├── mediastack/             # Media applications (Sonarr, Radarr, etc.)
├── metallb-system/         # MetalLB load balancer
├── monitoring/             # Monitoring stack
├── op-connect/             # 1Password Connect
└── sealed-secrets/         # SealedSecrets encryption
```

## 🔧 Key Components

### CI/CD Pipeline
- **Kubernetes manifest validation** - Validates all YAML files
- **Security scanning** - Trivy vulnerability scanning
- **RBAC validation** - Ensures proper permissions
- **Branch protection** - Requires CI to pass and PR reviews

### GitOps with Flux CD
- **Automated reconciliation** - Continuous deployment from Git
- **Helm releases** - Managed application deployments
- **Kustomization** - Configuration management
- **Source management** - Git and Helm repository integration

### Security & Compliance
- **Kyverno policies** - Policy enforcement
- **SealedSecrets** - Encrypted secrets in Git
- **RBAC** - Role-based access control
- **Network policies** - Network segmentation

## 🚀 Getting Started

### Prerequisites
- Kubernetes cluster (1.24+)
- Flux CD installed
- kubectl configured

### Deployment
1. **Clone the repository**
   ```bash
   git clone https://github.com/svollmi1/k8s-vollminlab-cluster.git
   cd k8s-vollminlab-cluster
   ```

2. **Bootstrap Flux CD**
   ```bash
   flux bootstrap github \
     --owner=svollmi1 \
     --repository=k8s-vollminlab-cluster \
     --branch=main \
     --path=clusters/vollminlab-cluster
   ```

3. **Verify deployment**
   ```bash
   flux get all
   kubectl get pods -A
   ```

## 🔒 Security Features

- **Branch Protection** - Enforced via Terraform
- **CI/CD Validation** - All changes must pass CI
- **Policy Enforcement** - Kyverno policies for compliance
- **Secret Management** - SealedSecrets for encrypted storage
- **RBAC** - Comprehensive role-based access control

## 📊 Monitoring & Observability

- **Homepage** - Centralized dashboard
- **Elastic Stack** - Log aggregation and analysis
- **Longhorn** - Persistent storage monitoring
- **MetalLB** - Load balancer status

## 🛠️ Development

### Making Changes
1. Create a feature branch
2. Make your changes
3. Ensure CI passes
4. Create a Pull Request
5. Get required approvals
6. Merge to main

### CI Pipeline
The CI pipeline validates:
- Kubernetes manifest syntax
- RBAC permissions
- Security vulnerabilities
- Policy compliance
- Helm chart validation

## 📚 Documentation

- [Flux CD Documentation](https://fluxcd.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kyverno Policies](https://kyverno.io/policies/)
- [SealedSecrets](https://github.com/bitnami-labs/sealed-secrets)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure all CI checks pass
5. Submit a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
- Create an issue in this repository
- Check the CI pipeline logs
- Review the Flux CD status

---

**Built with ❤️ using Flux CD, Kubernetes, and GitOps principles**