# Incident Runbook

## When to write a postmortem

Write a postmortem for any incident that meets one or more of these criteria:

- Any outage affecting infrastructure DNS, networking, or cluster-wide availability
- Any Kyverno webhook block that prevents pod creation or HelmRelease upgrades
- Any data-loss or near-miss event (DNS records wiped, PVC deleted, secret overwritten)
- Any incident requiring manual intervention to recover (not self-healing)
- Any incident that recurred or compounded (root cause not caught the first time)

Minor issues (single app restart, brief HelmRelease drift, single Kyverno audit violation) do not require a postmortem.

## Postmortem format

Files go in `docs/incidents/YYYY-MM-DD-short-description.md`.

Required sections:
- **Executive Summary** — what broke, how long, resolved or not
- **Timeline** — UTC timestamps, key events in order
- **Root Cause Analysis** — one section per independent root cause, explain the mechanism in full technical detail
- **Impact** — table of what was affected and how
- **Resolution Steps** — ordered, runnable commands, not just prose
- **What We Are Preventing Going Forward** — specific rules or runbook additions
- **Post-Incident Action Items** — table with status and PR links
- **Lessons Learned** — numbered, focused on systemic issues not individual mistakes

## After writing a postmortem

- Update or create files in `.claude/rules/` to capture operational procedures discovered during the incident
- Update memory if the incident revealed non-obvious architecture or operational constraints

## Existing incidents

| Date | File | Summary |
|---|---|---|
| 2026-04-05 | [2026-04-05-external-dns-kyverno-outage.md](../incidents/2026-04-05-external-dns-kyverno-outage.md) | external-dns `policy: sync` wiped all Pi-hole DNS records; Kyverno autogen broke fail-closed webhook and blocked all cluster mutations for ~2 hours |
