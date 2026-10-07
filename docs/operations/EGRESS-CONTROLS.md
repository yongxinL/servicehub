---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: EGRESS-CONTROLS
title: ServiceHub Container Egress Controls
version: "1.4"
status: Draft
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-05
updated: 2026-10-07
tags:
  - servicehub
  - operations
  - security
  - egress
  - firewall
related_documents:
  - ADR-009
  - ARCHITECTURE
  - SERVICE-INVENTORY
  - MONITORING-ALERTING
---

# ServiceHub Container Egress Controls

[ADR-009 §5](../adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) restricts container outbound traffic on the host. Two layers are enforced, both inside the Docker `DOCKER-USER` chain (container traffic only — the host's own outbound traffic is unaffected):

The per-service list lives in `egress-policies.conf`. The repository copy, [`scripts/egress-policies.conf`](../../scripts/egress-policies.conf), is only the **seed**: `scripts/setup.sh` copies it once to **`${APPS_DATA}/egress-policies.conf`**, and that runtime copy is the one `apply` reads (override the path with `EGRESS_POLICIES=<path>`). It sits under `APPS_DATA` deliberately — a deploy's rsync never touches that directory, so operator edits survive, and the weekly full backup archive covers it. **Make policy changes on the server, in `${APPS_DATA}/egress-policies.conf`**; editing the repository copy has no effect on a host that has already been seeded.

1. **Per-service policy** — the policy file lists a Compose service and its policy:
   - `restricted` — RFC1918 destinations (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, i.e. PostgreSQL, Authentik, Stalwart SMTP, Traefik, Docker DNS, the host) **plus the host's own public IP** are allowed; everything else is logged (`egress-restricted: ` prefix) and dropped. The public-IP rule covers hairpin access back into Traefik when public names (`login.<domain>`, …) resolve to the host's public address — without it, a restricted container's OIDC calls to Authentik are dropped. The address is detected at `apply` time from cloud instance metadata (Oracle IMDS), can be pinned with `EGRESS_SELF_IP=<ipv4>`, and is skipped with a warning when it cannot be determined.
   - `allow-blocked` — full internet including Atlassian (overrides layer 2).
   - `internet` — the default for every container not listed: full internet minus layer 2.
   - `allow-domain <name>` — standing, service-scoped exception listed in the policies file (e.g. `devopsrunner allow-domain data.forgejo.org`, required by the Forgejo runner for action downloads). On every `apply` the name is re-resolved and one `ACCEPT` per address is rebuilt at the **top** of `DOCKER-USER`, keyed to the service's current address — so it survives container address changes (with `watch` running) and still takes effect if a stale `restricted` jump is misattributed to that service. It works with any policy, including services not otherwise listed; unresolvable names are skipped with a warning. **Do not list your own domain** — `restricted` containers already reach it through the host-public-IP `RETURN`, which matches by address rather than name, so every present and future subdomain is covered without an entry here.
   - `block-domain <name>` — the inverse: the service may **not** reach `<name>`. Resolved on every `apply` and installed at the very top of `DOCKER-USER`, so a block always wins over a standing `allow` or `allow-domain` for the same address. Intended for services on the default `internet` policy, which are otherwise unrestricted. Unresolvable names are skipped with a warning. **It matches addresses, not names** — if the name resolves to a shared or CDN address, that address is blocked for the service too, and it only holds while the name resolves to the same addresses; re-`apply` after DNS changes.
2. **Global block** — every container's traffic to the CIDRs listed in `EGRESS_BLOCK_URL` (read from `.env`) is logged (`egress-blocked: ` prefix) and dropped. The ranges are held in one `ipset` (`blocked`), so the whole block is a single rule.

Containers are resolved by their Compose service label (`com.docker.compose.service`), so project-prefixed names such as `servicehub-webappconf-1` do not matter. DNS resolution is unaffected (the Docker resolver sits on a private address), so blocked external names may still resolve; the connection is what gets dropped.

## Requirements

- **Docker Engine** — the enforcement point is Docker's `DOCKER-USER` chain. Podman/netavark does not traverse it, so a podman deployment would need nftables rules instead.
- `iptables` with the same backend Docker uses (`iptables -V`); rules are IPv4-only — the stack runs without IPv6 networking, so mirror with `ip6tables` if that ever changes.
- `ipset` and `python3` for the global block (missing either leaves layer 1 active and prints a warning).
- `EGRESS_BLOCK_URL` — the CIDR feed(s) the global block reads. Several may be listed, whitespace-separated; all their CIDRs merge into the single `blocked` ipset, and every feed must fetch or the existing set is kept intact. Not baked into the script: `egress-guard.sh` loads it from `<repo>/.env` (add it by running `scripts/setup.sh`, which merges new `env.example` variables into an existing `.env`), and an exported `EGRESS_BLOCK_URL` takes precedence. `EGRESS_ENV_FILE` points at a different file, as `EGRESS_POLICIES` does for the policy file. Neither unit needs an `Environment=` line. Unset means `blocked-refresh` refuses to run and `watch` only warns, leaving layer 1 active.
- `getent` (glibc or BusyBox) for hostname destinations — `allow`/`revoke` arguments and `allow-domain` lines; explicit CIDR/IPv4 forms never resolve anything.

## Install and run

One-off (immediate rules for running containers):

```bash
scripts/egress-guard.sh apply
```

Persistent — `watch` applies at start, re-applies when a listed container's address changes (every `docker compose up -d` or daemon restart), and refreshes the blocked set at startup:

**Do not rely on a one-shot `apply`.** Every rule is keyed to container IP addresses, which change whenever a container is recreated. Without `watch` running nothing re-keys them, and a stale `restricted` jump stays pointed at the old address — whichever container inherits it then gets treated as Confluence (incident, 2026-10-06: a recreated runner inherited the address, its CI downloads were logged and dropped, and the guard had to be removed; the `watch` unit had never been installed). Install the unit as below, or re-run `apply` after every container recreate.

```ini
# /etc/systemd/system/servicehub-egress-guard.service
[Unit]
Description=ServiceHub container egress controls (ADR-009)
After=docker.service
Requires=docker.service

[Service]
ExecStart=/bin/sh <repo>/scripts/egress-guard.sh watch
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Daily refresh of the blocklist ranges (they change over time):

```ini
# /etc/systemd/system/servicehub-egress-refresh.service
[Unit]
Description=Refresh ServiceHub egress blocklist
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/bin/sh <repo>/scripts/egress-guard.sh blocked-refresh

# /etc/systemd/system/servicehub-egress-refresh.timer
[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now servicehub-egress-guard
sudo systemctl enable --now servicehub-egress-refresh.timer
```

## Commands

| Command | Effect |
|---|---|
| `scripts/egress-guard.sh apply` | Rebuild all policy rules and the global block now (exceptions are preserved) |
| `scripts/egress-guard.sh watch` | Apply, then re-apply on container address changes; refresh the set at startup |
| `scripts/egress-guard.sh status` | Policies, addresses, installed rules, set size, drop counters |
| `scripts/egress-guard.sh blocked-refresh` | Fetch the feed from `EGRESS_BLOCK_URL` (environment, else `<repo>/.env`) into the `blocked` ipset (atomic swap; on fetch failure or a missing URL the existing set is kept) |
| `scripts/egress-guard.sh allow <service> <dest>` | Time-boxed exception for one service and destination; `<dest>` is a CIDR, IPv4 address, or hostname — a hostname is resolved at grant time to every A record (one rule per address). **Held in `iptables` only: not written to any file, so a reboot clears it** — see [Time-boxed exception procedure](#time-boxed-exception-procedure) |
| `scripts/egress-guard.sh revoke <service> <dest>` | Remove that exception; `<dest>` may be a hostname too, re-resolved the same way at revoke time |
| `scripts/egress-guard.sh remove` | Strip every installed egress rule — restricted jumps, the global block and exceptions; Docker's own `RETURN` in `DOCKER-USER` is untouched and the policies file is kept |
| `scripts/egress-guard.sh selftest` | Offline rule-logic check (no root, Docker, or ipset needed) |

## Disable

To turn the controls off completely:

1. Stop persistence, if the units are installed:

   ```bash
   sudo systemctl disable --now servicehub-egress-guard servicehub-egress-refresh.timer
   ```

2. Strip every installed rule:

   ```bash
   scripts/egress-guard.sh remove
   ```

3. Verify: `scripts/egress-guard.sh status` reports `no egress rules installed`.

A running `watch` reinstalls the rules on the next container address change or restart — stop it first (step 1). Note that emptying `${APPS_DATA}/egress-policies.conf` removes only the per-service layer on the next `apply`; the global block is independent of that file, so `remove` is the complete off switch.

## Verify

```bash
scripts/egress-guard.sh status
```

Expected: the policy list (including any `allow-domain` lines), the resolved container addresses, the host's public IP, one `-j EGRESS_RESTRICTED` jump per `restricted` container, the global `-m set --match-set blocked dst … DROP` rule, the helper chain's host-public-IP and three RFC1918 `RETURN` rules ahead of its `LOG`/`DROP` pair, and — where `allow-domain` lines are configured — matching `egress-allow-domain … ACCEPT` rules at the top of `DOCKER-USER`.

Functional check — attempt an outbound call from a `restricted` container (e.g. `curl -m3 -sSI https://example.com` if `curl` is present) and confirm:

```bash
scripts/egress-guard.sh status   # DROP counter increases
sudo dmesg | grep -E 'egress-restricted: |egress-blocked: ' | tail
```

Both log prefixes are rate-limited to 20 lines per minute.

## Time-boxed exception procedure

Temporary outbound access MAY be granted for marketplace app install/upgrade, data migration, or approved maintenance, and SHALL be revoked as soon as the activity completes:

```bash
scripts/egress-guard.sh allow webappconf 192.0.2.10/32        # grant one destination
scripts/egress-guard.sh allow webappconf updates.example.com  # or a hostname: every A record
scripts/egress-guard.sh revoke webappconf 192.0.2.10/32       # remove it (revoke takes a hostname too)
```

Rules for exceptions:

- Record the requestor, destination, start time, and revoke time in the change record; set a revoke deadline before granting.
- Exceptions sit above every other rule in the chain and survive `apply`, but they are keyed to the container's current address, so they are void after a recreate — grant again rather than relying on a stale rule.
- **`allow` is not saved anywhere.** It writes the rule straight into `iptables` and nothing else, so it survives `apply` but **not a host reboot** — on boot the chain is empty and `apply` rebuilds only what `${APPS_DATA}/egress-policies.conf` describes. `scripts/egress-guard.sh remove` deletes it too. Re-grant after a reboot, or use the standing form below.
- `allow`/`revoke` resolve a hostname at call time only. If the name's addresses change between grant and revoke, revoke by explicit CIDR/IPv4 instead of the name, so no rule is left behind.
- A single `allow` covers the service's first running replica; grant per address if the service is scaled.
- For a permanent dependency, do not keep re-granting: add `<service> allow-domain <name>` to `${APPS_DATA}/egress-policies.conf` instead — it is rebuilt with current addresses on every `apply` (e.g. `devopsrunner allow-domain data.forgejo.org`). That file, not `allow`, is what survives a reboot: `watch` re-reads it at boot. Despite the name, the argument goes through the same resolver as `allow`, so a bare IPv4 address or a CIDR works as well (e.g. `webappconf allow-domain 192.0.2.10/32`) — record permanent IP allowances there, not as repeated `allow` calls. The file is runtime state rather than tracked in git, so keep a copy in the daily `cfgBK` backup ([backup and restore](BACKUP-RESTORE.md)) and note significant changes in the change record.
- Never widen the RFC1918 returns to make an exception permanent without an ADR change.

## Evidence and limitations

- `scripts/egress-guard.sh selftest` — offline check of the produced rules (restricted jump and helper chain, global block DROP/LOG, `allow-blocked` exception, standing-exception preservation, host-public-IP allowance and its unknown-IP fallback, full `remove` including exceptions, atomic set swap, refusal to refresh without `EGRESS_BLOCK_URL`, the `.env` fallback for `EGRESS_BLOCK_URL`, multiple feeds merged into one set, `block-domain` dropping every address of a name, `remove` stripping those rules, no set rules when the set is absent, hostname `allow`/`revoke` resolving to one rule per A record, and `allow-domain` rebuilt as a top-of-chain standing exception with the stale rule removed first).
- Stale-jump incident on the OCI host (2026-10-06): a one-shot `apply` with no `watch` unit installed left a `restricted` jump keyed to Confluence's address; after a stack recreate the Forgejo runner inherited that address, and kernel logs show `egress-restricted:` drops of the runner's HTTPS to `data.forgejo.org` (the `actions/checkout` download), breaking deploy workflows. An `allow` granted against the wrong service name had no effect; `remove` restored the runner. `servicehub-egress-guard` was never installed (`not-found`) and `ipset` is absent on the host, so only layer 1 was ever active. Remediation: install `watch` before using `apply`, and a standing `allow-domain` entry for the runner.
- Integration test through a real iptables-forwarded path (two network namespaces on a bridge, Linux VM): 21 checks covering label-based resolution, restricted blocking with private destinations open, the default `internet` policy staying open, kernel log output, exception grant/re-apply/revoke with correct rule ordering, flush when containers are gone, and egress restoration.
- Installation on the OCI host is owner-run (2026-10-06): enabling the guard broke Confluence login, and granting the host's own public IP (`allow webappconf <ip>/32`) restored it — which demonstrates live enforcement on that host. Kernel-log and counter verification are not yet recorded.
- The VM has no `ipset`, so the global block layer was exercised only by the offline check (including the "set absent" path the VM also exercises); counter and populated-`ipset` verification on the deployed Docker host remain outstanding.
- The Atlassian ranges feed itself is reachable and JSON-formatted as expected, but the populated `ipset` has not yet been verified on a production host.
