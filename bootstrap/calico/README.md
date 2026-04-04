# Calico CNI — Bootstrap Reference

**NOT managed by Flux.** These manifests exist for disaster recovery reference and version tracking only.
Flux has no Kustomization pointing at this directory and will never reconcile it.

## Versions

| Component | Version |
|---|---|
| Tigera Operator | v1.36.2 |
| Calico | v3.29.1 |

## Bootstrap order

Calico must be installed **before** Flux bootstraps. Pods cannot communicate without a CNI.

```
1. Install Kubernetes control plane
2. Install Tigera Operator (step below)
3. Apply Installation and APIServer CRs (step below)
4. Wait for calico-system pods to be Ready
5. Bootstrap Flux
```

## Step 1 — Install Tigera Operator

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
```

## Step 2 — Apply CRs from this directory

```bash
kubectl apply -f installation.yaml
kubectl apply -f apiserver.yaml
```

## Step 3 — Verify

```bash
kubectl get tigerastatus
kubectl get pods -n calico-system
```

Wait until all pods are Running and `calico` tigerastatus shows `AVAILABLE: True`.

## Upgrading Calico

1. Update the operator manifest URL version in this README
2. Update the version table above
3. Open a PR — the diff is the upgrade record
4. After merge: apply the new operator manifest manually, then verify tigerastatus

## Step 4 — Apply Kyverno compliance labels

Kyverno's `require-standard-labels` policy requires `app`, `env`, and `category` labels
on all namespaces. Calico namespaces are created by the tigera-operator and cannot be
labelled via GitOps. Apply these after Step 3 is complete:

```bash
kubectl label namespace calico-system   app=calico-system   env=production category=networking --overwrite
kubectl label namespace calico-apiserver app=calico-apiserver env=production category=networking --overwrite
kubectl label namespace tigera-operator  app=tigera-operator  env=production category=networking --overwrite
```

A `PolicyException` (kyverno/exceptions-calico.yaml) permanently exempts Calico pods from
label and resource-limits enforcement. These labels are only required on the Namespace objects.

## Network configuration

- IP pool CIDR: `172.18.0.0/16`
- Encapsulation: IPIP
- BGP: Enabled
- Dataplane: Iptables
- Control plane replicas: 2
