# Flux Health Check

Check the reconciliation state of the entire cluster. Run these in parallel and report any resources that are not Ready, have errors, or are suspended.

```bash
flux get kustomizations -A
flux get helmreleases -A
flux get sources git -A
flux get sources helm -A
```

For any resource that is not Ready or shows an error, get more detail:

```bash
flux describe kustomization [name] -n [namespace]
# or
flux describe helmrelease [name] -n [namespace]
```

Report:
1. A summary table of all Kustomizations and HelmReleases with their status
2. Any failures or warnings, with the error message
3. Any resources that are suspended
4. Suggested remediation for failures (e.g., `flux reconcile`, checking HelmRepository, checking source)
