# CLAUDE.md — Vollminlab Kubernetes Cluster

GitOps-managed Kubernetes cluster using Flux CD. All workloads are Helm-based Flux resources under `clusters/vollminlab-cluster/`.

**Full configuration reference (versions, values, resource limits, network policies):** `docs/cluster-reference.md`

## Essential reading before working

- `.claude/rules/flux.md` — repo layout, HelmRelease conventions, reconciliation commands, stuck HelmRelease runbook
- `.claude/rules/kyverno.md` — required labels, enforce/audit policies, DMZ rules, autogen danger, webhook block recovery
- `.claude/rules/secrets.md` — SealedSecrets workflow, never plain Secrets
- `.claude/rules/subagents.md` — when to spawn parallel agents
- `.claude/rules/homepage.md` — auto-discovery via ingress annotations, widget support, credentials
- `.claude/rules/external-dns.md` — Pi-hole constraint: policy: upsert-only only, DNS restore procedure
- `.claude/rules/incidents.md` — when to write postmortems, format, existing incident index

## Hard constraints

- Never commit a plain `kind: Secret`. Use `SealedSecret` only.
- Never push directly to `main`. PR required (branch protection via Terraform).
- Never touch `bootstrap/calico/` with Flux. CNI changes are manual + verified.
- Never use `:latest` image or chart version tags. Kyverno blocks them.
- All pods require `app`, `env`, and `category` labels. Kyverno enforces in enforce mode.

## Bootstrap / DR

`bootstrap/` is **not** Flux-managed. It contains manual DR reference manifests:
- `bootstrap/calico/` — CNI, must be applied before Flux bootstrap
- `bootstrap/coredns/` — CoreDNS custom config
- `bootstrap/sealed-secrets/` — sealing key restore procedure

Sealing key is backed up in 1Password as **"Sealed Secrets Sealing Key"**.
