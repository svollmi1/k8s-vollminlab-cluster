---
description: When and how to use parallel subagents when working in k8s-vollminlab-cluster
---

# Subagent Parallelization

## Always plan before acting

**Before starting any task that involves editing files, running commands, or making changes — spawn a Plan agent first.** Do not begin work inline.

The only exceptions are:
- A single-word or single-line fix where the location is already known and unambiguous
- Answering a pure question (no edits, no commands)

The Plan agent should return:
- Which files need to be read or changed
- The order of operations and any sequential dependencies
- Any risks or constraints (Kyverno labels, sealed secret workflow, etc.)

Once you have the plan, act on it — using parallel Explore agents for reads, then editing directly.

## Always delegate file exploration to subagents

Any task that requires reading files you haven't already seen in this session MUST use an Explore agent, not inline Read/Grep/Glob. The Explore agent runs in a separate context window and keeps the main session clean.

Only use Read/Grep/Glob directly in the main context for a single, targeted file you are certain is correct (e.g. re-reading something already identified by a prior agent).

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
