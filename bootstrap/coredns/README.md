# CoreDNS — Bootstrap Reference

**NOT managed by Flux.** This manifest exists as a git-tracked reference only.
Kubeadm owns the CoreDNS ConfigMap — Flux has no Kustomization pointing here.

## Notes

Standard CoreDNS config with `cache 30`. A previous non-standard configuration
disabled caching for `cluster.local` (`disable success` and `disable denial`),
likely added as a workaround for Kyverno webhook DNS resolution during restarts.
Restored to standard after the cluster proved stable.

## Applying after a cluster rebuild

CoreDNS is installed by kubeadm with a default Corefile. If customizations are
ever needed, apply this ConfigMap after kubeadm init:

```bash
kubectl apply -f coredns-configmap.yaml
```

CoreDNS detects ConfigMap changes via the `reload` plugin — no pod restart needed.
