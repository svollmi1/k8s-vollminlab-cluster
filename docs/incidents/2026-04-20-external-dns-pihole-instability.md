# Incident Postmortem — 2026-04-20
## external-dns Crash Loop Caused by Pi-hole API Session Exhaustion, FTL Restarts, and DB Corruption

**Severity:** P2 — DNS automation degraded, no active record loss  
**Duration:** Ongoing intermittently before investigation; active remediation on 2026-04-20  
**Status:** Resolved

---

## Executive Summary

`external-dns` in the `external-dns` namespace was repeatedly crashing with a fatal Pi-hole provider error. Initial suspicion was an `external-dns` image/provider bug, but live debugging showed the real issue was on the Pi-hole side.

Three separate Pi-hole-side problems were contributing:

1. Pi-hole API sessions were exhausting the configured seat limit, returning `429 Too Many Requests` with `api_seats_exceeded`.
2. `pihole1` was running a cron healthcheck that restarted `pihole-FTL` whenever a simplistic status check failed, creating a brief but real API outage that `external-dns` treated as fatal.
3. Both `pihole1` and `pihole2` had corrupted `pihole-FTL.db` databases, and `pihole1` also showed gravity-table related errors in logs before repair.

The final fix was not a Kubernetes change alone. We upgraded `external-dns` to `v0.21.0`, tuned Pi-hole API session settings on both Pi-holes, repaired the corrupted Pi-hole databases, and replaced the healthcheck script on both nodes with a safer version that only restarts FTL after consecutive confirmed failures and enforces a cooldown.

---

## Timeline

| Time (UTC) | Event |
|---|---|
| Before 2026-04-20 | `external-dns` pod repeatedly restarts on `v0.20.0`, with liveness probe failures and fatal Pi-hole provider exits. |
| 2026-04-20 00:00:45 | Previous `external-dns` container logs show fatal parse error: `failed to unmarshal error response: invalid character 'E' looking for beginning of value`. |
| 2026-04-20 00:26–00:27 | PR #364 created and merged for Kyverno hook pod audit-noise suppression discovered during initial warning review. |
| 2026-04-20 00:59 | `external-dns` upgraded to `v0.21.0` and rolls out to a new pod (`external-dns-6bf4cffbcb-*`). |
| 2026-04-20 01:00:51 | New `v0.21.0` pod still crashes with the same fatal parse error, proving the upgrade alone does not fix the issue. |
| 2026-04-20 01:08:39 | Direct API testing against `pihole1` returns `429 Too Many Requests` and JSON error `api_seats_exceeded`. |
| 2026-04-20 01:15:01 | `external-dns` logs `connect: connection refused` to `http://192.168.100.2/api/auth`. |
| 2026-04-20 01:15:01 | `journalctl` on `pihole1` shows `pihole-healthcheck.sh` invoked by cron and restarting `pihole-FTL` exactly at the same time. |
| 2026-04-20 01:27–01:35 | Investigation of `pihole1` logs reveals repeated SQLite corruption in `pihole-FTL.db` and gravity-related table errors in logs. |
| 2026-04-20 01:36 | `pihole1` repaired: `gravity.db` recovered with `pihole -g -r recover`, `pihole-FTL.db` rebuilt, integrity checks pass. |
| 2026-04-20 01:50 | `pihole2` checked and found to have the same `pihole-FTL.db` corruption pattern. |
| 2026-04-20 01:50+ | `pihole2` repaired by rebuilding `pihole-FTL.db`; integrity checks pass. |
| 2026-04-20 02:00+ | Safer `pihole-healthcheck.sh` installed on both Pi-holes. |

---

## Root Cause Analysis

### Root Cause 1 — Pi-hole API session exhaustion

Direct testing of the Pi-hole API on `pihole1` showed intermittent responses of:

- HTTP `429 Too Many Requests`
- error key `api_seats_exceeded`
- hint `increase webserver.api.max_sessions`

This showed the API was not simply “down” or returning random garbage. Pi-hole was enforcing a concurrent API session limit. Because `external-dns` syncs every minute and uses the Pi-hole v6 API, session accumulation was enough to exhaust available seats. This made API access unreliable even when FTL was otherwise healthy.

Pi-hole’s defaults were too low for the observed usage pattern, so `webserver.api.max_sessions` was increased and `webserver.session.timeout` was reduced to make stale sessions expire sooner.

### Root Cause 2 — FTL restarts from an over-aggressive healthcheck

`pihole1` had a cron entry running every 15 minutes:

```cron
*/15 * * * * /usr/local/bin/pihole-healthcheck.sh
```

The original healthcheck script only checked whether `pihole status` contained `FTL is listening`. If not, it immediately executed:

```bash
systemctl restart pihole-FTL
```

At `2026-04-19 21:15:01 EDT` (`2026-04-20 01:15:01 UTC`), this script restarted `pihole-FTL` on `pihole1`. `external-dns` attempted to call `http://192.168.100.2/api/auth` during that restart window and received `connect: connection refused`, then exited fatally. This made the healthcheck itself part of the incident.

### Root Cause 3 — Corrupted Pi-hole query databases

Both Pi-holes had corrupted `/etc/pihole/pihole-FTL.db` databases. `pihole1` logs showed recurring SQLite corruption such as:

- `database disk image is malformed`
- `wrong # of entries in index ...`
- `row ... missing from index ...`

and intermittent missing-table errors involving gravity-related tables. This indicated local persistent-state corruption, not just a transient network glitch or an `external-dns` bug.

The corrupted `pihole-FTL.db` was rebuilt on both nodes. On `pihole1`, `gravity.db` was also proactively repaired with Pi-hole’s built-in recovery flow.

### Contributing factor — external-dns exits on transient Pi-hole API failure

Even after upgrading `external-dns` from `v0.20.0` to `v0.21.0`, the pod still exited on transient Pi-hole API failures. This did not cause the incident, but it amplified Pi-hole instability into repeated pod restarts. The upgrade was still worth keeping, but it was not the root-cause fix.

---

## Impact

| Component | Impact |
|---|---|
| `external-dns` | Repeated pod restarts, DNS automation degraded |
| Pi-hole API | Session exhaustion and restart windows caused API failures |
| Pi-hole FTL | Repeated corruption errors on both nodes; unstable health on `pihole1` before repair |
| Cluster DNS records | No confirmed data loss during this incident |
| Headlamp / event stream | Repeated liveness and warning noise from the crash loop |

---

## Resolution Steps

### 1. Upgrade external-dns to latest tested image

PR #366 pinned:

```yaml
image:
  tag: v0.21.0
```

in:

`clusters/vollminlab-cluster/external-dns/external-dns/app/configmap.yaml`

This confirmed the running deployment was on `v0.21.0`, but did not by itself stop the crash loop.

### 2. Prove Pi-hole API session exhaustion

Tested direct auth calls to `pihole1`:

```bash
curl -i -sS -X POST http://192.168.100.2/api/auth \
  -H 'Content-Type: application/json' \
  --data '{"password":"..."}'
```

Observed:

- HTTP `200 OK` with valid session
- followed by HTTP `429 Too Many Requests`
- JSON error `api_seats_exceeded`

### 3. Tune Pi-hole API session configuration on both nodes

Applied on both `pihole1` and `pihole2`:

```bash
sudo pihole-FTL --config webserver.api.max_sessions 64
sudo pihole-FTL --config webserver.session.timeout 300
```

This increased API seat headroom and reduced stale session lifetime.

### 4. Repair `pihole1`

Back up Pi-hole state:

```bash
sudo cp -a /etc/pihole /etc/pihole.backup.$(date +%F-%H%M%S)
```

Recover gravity DB:

```bash
sudo pihole -g -r recover
```

Rebuild query / long-term DB:

```bash
sudo systemctl stop pihole-FTL
sudo mv /etc/pihole/pihole-FTL.db /etc/pihole/pihole-FTL.db.corrupt.$(date +%F-%H%M%S)
sudo mv /etc/pihole/pihole-FTL.db-wal /etc/pihole/pihole-FTL.db-wal.corrupt.$(date +%F-%H%M%S) 2>/dev/null || true
sudo mv /etc/pihole/pihole-FTL.db-shm /etc/pihole/pihole-FTL.db-shm.corrupt.$(date +%F-%H%M%S) 2>/dev/null || true
sudo systemctl start pihole-FTL
```

Verify:

```bash
sudo pihole-FTL sqlite3 /etc/pihole/pihole-FTL.db "PRAGMA integrity_check;"
sudo pihole-FTL sqlite3 /etc/pihole/gravity.db "PRAGMA integrity_check;"
```

Expected and observed:

```text
ok
ok
```

### 5. Repair `pihole2`

Back up Pi-hole state:

```bash
sudo cp -a /etc/pihole /etc/pihole.backup.$(date +%F-%H%M%S)
```

`gravity.db` was already healthy, so only `pihole-FTL.db` was rebuilt:

```bash
sudo systemctl stop pihole-FTL
sudo mv /etc/pihole/pihole-FTL.db /etc/pihole/pihole-FTL.db.corrupt.$(date +%F-%H%M%S)
sudo mv /etc/pihole/pihole-FTL.db-wal /etc/pihole/pihole-FTL.db-wal.corrupt.$(date +%F-%H%M%S) 2>/dev/null || true
sudo mv /etc/pihole/pihole-FTL.db-shm /etc/pihole/pihole-FTL.db-shm.corrupt.$(date +%F-%H%M%S) 2>/dev/null || true
sudo systemctl start pihole-FTL
```

Verify while stopped:

```bash
sudo systemctl stop pihole-FTL
sudo pihole-FTL sqlite3 /etc/pihole/pihole-FTL.db "PRAGMA integrity_check;"
sudo pihole-FTL sqlite3 /etc/pihole/gravity.db "PRAGMA integrity_check;"
sudo systemctl start pihole-FTL
```

Expected and observed:

```text
ok
ok
```

### 6. Replace the healthcheck script on both Pi-holes

The old script immediately restarted FTL on a single failed `pihole status` check. It was replaced with a safer version that:

- checks both `systemctl is-active pihole-FTL` and local API reachability
- requires `2` consecutive failures before restart
- enforces a `30m` restart cooldown
- logs the exact failure condition

The cron schedule was kept, but the action taken on failure is now much safer.

### 7. Verify external-dns stabilizes

Useful checks:

```bash
kubectl get pod -n external-dns
kubectl logs -n external-dns deployment/external-dns --previous --tail=100
kubectl logs -n external-dns deployment/external-dns --tail=100
```

After Pi-hole repairs, the expectation is that `external-dns` no longer restarts due to Pi-hole API instability.

---

## What We Are Preventing Going Forward

### Prevention 1 — Pi-hole API session limits sized for automation

Pi-hole v6 API defaults were too low for the observed mix of automation and UI/API clients. `webserver.api.max_sessions` and `webserver.session.timeout` were tuned on both nodes to prevent seat exhaustion under normal automation.

### Prevention 2 — Healthchecks should confirm failure, not flap the service

The original healthcheck was effectively a restart trigger. The new version requires consecutive failures, validates the API locally, and enforces cooldowns so transient issues do not become outages.

### Prevention 3 — Backup nodes should still be healthy

Even if `pihole2` is “just the backup,” it must not carry silent DB corruption. The same DB integrity and healthcheck standards now apply to both nodes.

### Prevention 4 — external-dns upgrades help, but Pi-hole remains the critical dependency

Upgrading `external-dns` to `v0.21.0` was a good proactive step, but it did not solve the root cause. Pi-hole availability and API behavior remain the critical dependency for this integration.

---

## Post-Incident Action Items

| Action | Status | Notes |
|---|---|---|
| Upgrade `external-dns` image to `v0.21.0` | Done | PR #366, merged |
| Tune Pi-hole API session settings on `pihole1` | Done | `max_sessions=64`, `timeout=300` |
| Tune Pi-hole API session settings on `pihole2` | Done | `max_sessions=64`, `timeout=300` |
| Repair `pihole1` DBs | Done | `gravity.db` recovered, `pihole-FTL.db` rebuilt |
| Repair `pihole2` query DB | Done | `pihole-FTL.db` rebuilt |
| Replace healthcheck on `pihole1` | Done | Safer restart policy installed |
| Replace healthcheck on `pihole2` | Done | Safer restart policy installed |
| Monitor `external-dns` restart count after repairs | Open | Confirm stability over time |

---

## Lessons Learned

1. A brittle local healthcheck can be as damaging as the service issue it is trying to correct. Immediate restarts on shallow checks are risky for shared infrastructure dependencies.
2. DB corruption on “secondary” nodes is still production risk. Silent corruption will matter the moment failover or recovery depends on that node.
3. Provider integrations should always be debugged from both ends. The Kubernetes symptom looked like an `external-dns` bug at first, but the decisive evidence came from the Pi-hole API and FTL logs.
4. Upgrades are good hygiene, not proof of causality. The `external-dns` image bump was worth shipping, but the live evidence showed the true failures were upstream.
