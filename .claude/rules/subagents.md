---
description: When and how to use parallel subagents when working in k8s-vollminlab-cluster
---

# Subagent Parallelization

## When to spawn parallel agents

This repo has many independent namespaces and files. Use parallel Explore agents aggressively for:

- **Cross-namespace queries** — e.g., "what version of chart X is deployed?" → spawn one agent per namespace or HelmRelease simultaneously
- **Multi-app version audits** — checking all HelmReleases for outdated charts
- **Comparing before/after** — reading the current state of N files before editing
- **Independent concerns in one PR** — e.g., update chart version in namespace A while also updating ingress in namespace B

## When NOT to parallelize

- When step B depends on the output of step A (seal a secret → then commit it)
- Simple single-file edits
- When you need the cluster's live state (kubectl commands are sequential by nature)

## Subagent types to use

| Task | Agent type |
|------|-----------|
| Find files, search code | `Explore` |
| Plan a multi-step implementation | `Plan` |
| Research chart versions, Helm values docs | `general-purpose` |

## Example: auditing all HelmRelease chart versions

Spawn one Explore agent per namespace (`mediastack`, `shlink`, `dmz`, `cert-manager`, etc.) simultaneously, each reading `helmrelease.yaml` and returning the chart name + version. Collect results, then act.

## Reminder

The global `~/.claude/CLAUDE.md` also has parallelization guidance. The principle: if two things don't depend on each other, do them at the same time.
