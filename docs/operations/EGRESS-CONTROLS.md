---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: EGRESS-CONTROLS
title: ServiceHub Container Egress Controls
version: "1.1"
status: Draft
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-05
updated: 2026-10-06
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

1. **Per-service policy** — [`scripts/egress-policies.conf`](../../scripts/egress-policies.conf) lists a Compose service and its policy:
   - `restricted` — RFC1918 destinations (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, i.e. PostgreSQL, Authentik, Stalwart SMTP, Traefik, Docker DNS, the host) **plus the host's own public IP** are allowed; everything else is logged (`egress-restricted: ` prefix) and dropped. The public-IP rule covers hairpin access back into Traefik when public names (`login.<domain>`, …) resolve to the host's public address — without it, a restricted container's OIDC calls to Authentik are dropped. The address is detected at `apply` time from cloud instance metadata (Oracle IMDS), can be pinned with `EGRESS_SELF_IP=<ipv4>`, and is skipped with a warning when it cannot be determined.
   - `allow-atlassian` — full internet including Atlassian (overrides layer 2).
   - `internet` — the default for every container not listed: full internet minus layer 2.
2. **Global Atlassian block** — every container's traffic to the CIDRs published at <https://ip-ranges.atlassian.com/> is logged (`egress-atlassian: ` prefix) and dropped. The ranges are held in one `ipset` (`atlassian`), so the whole block is a single rule.

Containers are resolved by their Compose service label (`com.docker.compose.service`), so project-prefixed names such as `servicehub-webappconf-1` do not matter. DNS resolution is unaffected (the Docker resolver sits on a private address), so blocked external names may still resolve; the connection is what gets dropped.

## Requirements

- **Docker Engine** — the enforcement point is Docker's `DOCKER-USER` chain. Podman/netavark does not traverse it, so a podman deployment would need nftables rules instead.
- `iptables` with the same backend Docker uses (`iptables -V`); rules are IPv4-only — the stack runs without IPv6 networking, so mirror with `ip6tables` if that ever changes.
- `ipset` and `python3` for the Atlassian block (missing either leaves layer 1 active and prints a warning).

## Install and run

One-off (immediate rules for running containers):

```bash
scripts/egress-guard.sh apply
```

Persistent — `watch` applies at start, re-applies when a listed container's address changes (every `docker compose up -d` or daemon restart), and refreshes the Atlassian set at startup:

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

Daily refresh of the Atlassian ranges (the ranges change over time):

```ini
# /etc/systemd/system/servicehub-egress-refresh.service
[Unit]
Description=Refresh ServiceHub Atlassian egress blocklist
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/bin/sh <repo>/scripts/egress-guard.sh atlassian-refresh

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
| `scripts/egress-guard.sh atlassian-refresh` | Reload `https://ip-ranges.atlassian.com/` into the `atlassian` ipset (atomic swap; on fetch failure the existing set is kept) |
| `scripts/egress-guard.sh allow <service> <cidr>` | Time-boxed exception for one service and destination |
| `scripts/egress-guard.sh revoke <service> <cidr>` | Remove that exception |
| `scripts/egress-guard.sh selftest` | Offline rule-logic check (no root, Docker, or ipset needed) |

## Verify

```bash
scripts/egress-guard.sh status
```

Expected: the policy list, the resolved container addresses, the host's public IP, one `-j EGRESS_RESTRICTED` jump per `restricted` container, the global `-m set --match-set atlassian dst … DROP` rule, and the helper chain's host-public-IP and three RFC1918 `RETURN` rules ahead of its `LOG`/`DROP` pair.

Functional check — attempt an outbound call from a `restricted` container (e.g. `curl -m3 -sSI https://id.atlassian.com` if `curl` is present) and confirm:

```bash
scripts/egress-guard.sh status   # DROP counter increases
sudo dmesg | grep -E 'egress-restricted: |egress-atlassian: ' | tail
```

Both log prefixes are rate-limited to 20 lines per minute.

## Time-boxed exception procedure

Temporary outbound access MAY be granted for marketplace app install/upgrade, data migration, or approved maintenance, and SHALL be revoked as soon as the activity completes:

```bash
scripts/egress-guard.sh allow webappconf 192.0.2.10/32   # grant one destination
scripts/egress-guard.sh revoke webappconf 192.0.2.10/32  # remove it
```

Rules for exceptions:

- Record the requestor, destination, start time, and revoke time in the change record; set a revoke deadline before granting.
- Exceptions sit above every other rule in the chain and survive `apply`, but they are keyed to the container's current address, so they are void after a recreate — grant again rather than relying on a stale rule.
- A single `allow` covers the service's first running replica; grant per address if the service is scaled.
- Never widen the RFC1918 returns to make an exception permanent without an ADR change.

## Evidence and limitations

- `scripts/egress-guard.sh selftest` — offline check of the produced rules (restricted jump and helper chain, global Atlassian DROP/LOG, `allow-atlassian` exception, standing-exception preservation, atomic set swap, no set rules when the set is absent).
- Integration test through a real iptables-forwarded path (two network namespaces on a bridge, Linux VM): 21 checks covering label-based resolution, restricted blocking with private destinations open, the default `internet` policy staying open, kernel log output, exception grant/re-apply/revoke with correct rule ordering, flush when containers are gone, and egress restoration.
- Installation on the OCI host is owner-run (2026-10-06): enabling the guard broke Confluence login, and granting the host's own public IP (`allow webappconf <ip>/32`) restored it — which demonstrates live enforcement on that host. Kernel-log and counter verification are not yet recorded.
- The VM has no `ipset`, so the Atlassian layer was exercised only by the offline check (including the "set absent" path the VM also exercises); counter and populated-`ipset` verification on the deployed Docker host remain outstanding.
- The Atlassian ranges feed itself is reachable and JSON-formatted as expected, but the populated `ipset` has not yet been verified on a production host.
