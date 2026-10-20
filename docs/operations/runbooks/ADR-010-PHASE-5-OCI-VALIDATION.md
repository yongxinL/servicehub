---
project: ServiceHub
project_code: SVCHUB
document_type: RUNBOOK
document_id: RUNBOOK-ADR-010-PHASE-5
title: ADR-010 Phase 5 OCI Validation
version: "2.1"
status: Planned
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-18
updated: 2026-10-20
tags:
  - servicehub
  - runbook
  - observability
  - oci
related_documents:
  - DEPLOYMENT
  - MONITORING-ALERTING
  - LOG-TROUBLESHOOTING
  - ADR-010
---

# ADR-010 Phase 5 OCI Validation

This is the single authoritative Phase 5 runbook for ADR-010. It is executable gate by gate under owner supervision or manually by George on the OCI host. All Docker, Compose, Alloy, VictoriaMetrics, VictoriaLogs, Grafana, container, metric, log, dashboard, and alert commands are OCI-host actions. Do not execute them locally.

Local agent work is limited to Git inspection, editing, non-container static parsing, documentation checks, secret scans, and link checks.

Approved runtime scope:

- Grafana Alloy
- VictoriaMetrics
- VictoriaLogs
- Grafana
- Grafana-managed alerting
- OCI Monitoring as the external VM and total-stack watchdog

Runtime data flow:

```text
Grafana Alloy
    ├── Metrics ──> VictoriaMetrics
    ├── Logs ─────> VictoriaLogs
    └── Probes ───> VictoriaMetrics

VictoriaMetrics + VictoriaLogs ──> Grafana
Grafana ──> Dashboards + Grafana-managed alerts
```

Excluded runtime scope:

- LiteLLM
- `aiserv`
- Stalwart
- Bulwark
- `mailsv`
- all relocated mail-platform telemetry
- Prometheus server
- Loki
- vmagent
- vmalert
- Alertmanager
- Pyroscope
- a separate OpenTelemetry Collector
- Splunk or another SIEM
- Oracle APM as a Phase 5 core-acceptance requirement

## Status vocabulary

| Status | Meaning |
|---|---|
| Runtime verified | The matching gate passed and evidence was recorded. |
| Runtime verification pending | Configuration exists, but no OCI runtime evidence exists yet. |
| Failed | The gate ran and failed. Record output and stop. |
| Blocked | Required access, prerequisite, decision, or state is missing. |
| Deferred | Owner-approved work is intentionally postponed. |
| Outside scope | The capability is excluded by ADR-010 or this runbook. |

Never describe untested behavior as working, operational, healthy, or complete.

## Execution principle

Do not execute this runbook blindly.

```text
Gate passed -> record evidence -> continue
Gate failed -> stop -> diagnose -> correct -> repeat the gate
```

Do not accumulate failures across gates. Each gate must establish a known-good state for the next gate.

## Gate record template

Record one row per gate:

```text
Gate ID:
UTC start:
UTC finish:
OCI host:
Checkout path:
Commit:
Executor:
Purpose:
Commands:
Observed result:
Pass/fail/blocked:
Evidence paths or IDs:
Corrections:
Rollback action:
```

## Non-negotiable safety constraints

Phase 5 must never:

- run `docker compose down -v`
- delete `${APPS_DATA}/obsvce`
- run `git reset --hard` on a dirty or production checkout
- run `git clean -fd` on a dirty or production checkout
- overwrite or discard an unrelated mail-platform change
- deploy from an old dirty OCI checkout
- expose VictoriaMetrics or VictoriaLogs through Traefik or a public interface
- print `.env` values or credentials
- start LiteLLM, `aiserv`, Stalwart, Bulwark, or `mailsv`
- install an arbitrary Confluence JMX exporter
- implement Oracle APM as part of Phase 5 core acceptance
- delete telemetry data to force a validation result
- deliberately fill a filesystem
- stop a production service merely to trigger an alert
- force-push or rewrite published Git history

All destructive-risk actions require an owner-approved maintenance window and an explicit rollback point.

## Core acceptance requirements

Core acceptance may proceed only if:

- Alloy, VictoriaMetrics, VictoriaLogs, and Grafana are stable.
- Host and container metrics work.
- Filesystem and inode metrics work.
- Host journal and container logs work.
- Traefik metrics and access logs work.
- Readiness and TLS probes work.
- Authentik and oCIS telemetry work or have approved corrections.
- Grafana datasources work.
- All eight ServiceHub dashboards have no material failures.
- Alert rules are not unexpectedly stuck in Error or NoData.
- Excluded AI and mail services remain absent.
- Telemetry survives controlled service recreation.
- Evidence is recorded.

Permitted deferred items are notification delivery pending a contact point, Confluence JMX pending an approved exporter dependency, Oracle APM, final retention tuning, final threshold tuning, and capacity forecasting. Confluence JMX deferral must not block core acceptance.

## Pre-runtime validation record

The Project Owner approved the current Phase 5 validation revision on 2026-10-20.

| Capability | Status |
|---|---|
| Repository implementation through Phase 3 | Complete in repository |
| Local static validation | Passed with documented tool limitations |
| Integrated OCI runtime validation | Runtime verification pending |
| OCI APM | Deferred and excluded from Phase 5 core acceptance |
| Notification delivery | Deferred pending owner-approved contact point |
| Confluence JMX | Deferred pending approved exporter dependency |
| Archived/legacy mail documentation links | Corrected; five current-document references to archived mail documentation now resolve |

The implementation baseline is `6eb4c1e96cab58ba3f819c3b24e629b52fa4876d`. The approved validation revision is `58c8c6d4d606ee93dc43521b6deaef29fbbfa9fc`. The actual deployed commit remains to be recorded when Phase 5 starts on OCI. This record does not mark ADR-010 runtime verified.

---

## G01 — Preparation and clean Forgejo checkout

**Purpose:** establish the approved implementation baseline, approved validation revision, and clean Forgejo checkout without touching an unrelated checkout.

**Prerequisites:** OCI SSH access; implementation baseline commit `6eb4c1e96cab58ba3f819c3b24e629b52fa4876d`; approved validation revision `58c8c6d4d606ee93dc43521b6deaef29fbbfa9fc` or an explicitly approved later correction commit; Forgejo read access; approved clean checkout location.

**Commands:**

```bash
test ! -e "${HOME:?}/servicehub-adr010-phase5" || { echo 'BLOCKED: target exists'; exit 1; }
IMPLEMENTATION_COMMIT="6eb4c1e96cab58ba3f819c3b24e629b52fa4876d"
VALIDATION_COMMIT="58c8c6d4d606ee93dc43521b6deaef29fbbfa9fc"
APPROVED_REMOTE="https://git.lifamy.com/nexora/servicehub.git"
git clone --branch adr-010 https://git.lifamy.com/nexora/servicehub.git "${HOME}/servicehub-adr010-phase5"
cd "${HOME}/servicehub-adr010-phase5"
git status --short
git branch --show-current
git remote get-url origin
git rev-parse HEAD
test "$(git remote get-url origin)" = "${APPROVED_REMOTE}"
test "$(git rev-parse HEAD)" = "${VALIDATION_COMMIT}"
git merge-base --is-ancestor "${IMPLEMENTATION_COMMIT}" HEAD
git log --oneline "${IMPLEMENTATION_COMMIT}..HEAD"
```

Use an existing credential helper or deploy credential. Never embed or print credentials.

**Expected/pass:** clean checkout on `adr-010` at the approved validation revision; the approved Forgejo remote is configured; `6eb4c1e96cab58ba3f819c3b24e629b52fa4876d` is an ancestor of `HEAD`; every later change is reviewed; and the actual deployed commit is recorded in the Phase 5 evidence. If the owner approves a later correction commit, update `VALIDATION_COMMIT` to that commit before validation.

**Failure/stop:** clone failure, dirty checkout, remote mismatch, commit mismatch, missing implementation baseline ancestor, unreviewed implementation change after the approved validation revision, or missing deployed-commit record.

**Evidence:** checkout path, branch, actual commit, implementation-baseline ancestor check, later-commit list, remote URL, Git status, timestamp.

**Recovery:** remove only the newly created failed checkout. Do not alter an existing deployment checkout.

---

## G02 — Preserve existing checkout and runtime state

**Purpose:** protect unrelated changes and establish a rollback point.

**Prerequisites:** G01 passed; owner-approved maintenance window.

**Commands:**

```bash
OLD_PATH="${SERVICEHUB_DEPLOY_PATH:?set SERVICEHUB_DEPLOY_PATH}"
BACKUP_ROOT="/var/tmp/servicehub-adr010-phase5-$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 0700 "${BACKUP_ROOT}"
cd "${OLD_PATH}"
git status --porcelain=v1 | tee "${BACKUP_ROOT}/git-status.txt"
git rev-parse HEAD | tee "${BACKUP_ROOT}/git-head.txt"
git branch --show-current | tee "${BACKUP_ROOT}/git-branch.txt"
git diff --binary > "${BACKUP_ROOT}/tracked-worktree.patch"
git diff --cached --binary > "${BACKUP_ROOT}/staged-worktree.patch"
docker compose ps -a > "${BACKUP_ROOT}/compose-ps.txt"
docker compose images > "${BACKUP_ROOT}/compose-images.txt"
docker images --digests > "${BACKUP_ROOT}/docker-images.txt"
for service in obsvcevm obsvcevlogs obsvcealloy obsvcegrafana; do
  docker compose logs --no-color --timestamps "${service}" > "${BACKUP_ROOT}/${service}.log" 2>&1 || true
done
```

Do not print or copy `.env`, database passwords, tokens, private keys, or secret-bearing configuration.

**Expected/pass:** dirty state and runtime identities are preserved outside the deployment tree.

**Failure/stop:** dirty checkout cannot be preserved; `compose/mailsv.yml` change cannot be separated; runtime state cannot be captured.

**Evidence:** backup directory, Git state, image IDs, container IDs, log checksums.

**Recovery:** restore from `${BACKUP_ROOT}` on abort. Do not use destructive Git or Compose cleanup.

---

## G03 — Host prerequisites

**Purpose:** confirm Docker, Compose, storage, journald access inputs, and loopback port availability.

**Prerequisites:** G02 passed; privileged OCI shell access.

**Commands:**

```bash
docker version
docker compose version
docker info --format 'Docker root: {{.DockerRootDir}}'
docker info --format 'Logging driver: {{.LoggingDriver}}'
docker info --format 'Cgroup driver: {{.CgroupDriver}}'
docker info --format 'Cgroup version: {{.CgroupVersion}}'
df -T / /var/lib/docker "${APPS_DATA:?set APPS_DATA}"
df -i / /var/lib/docker "${APPS_DATA}"
findmnt -no TARGET,FSTYPE,OPTIONS / "${APPS_DATA}" /var/lib/docker
test -d /var/log/journal && echo 'Persistent journal exists' || echo 'Persistent journal absent'
test -d /run/log/journal && echo 'Runtime journal exists' || echo 'Runtime journal absent'
test -f /etc/machine-id && echo 'Machine ID exists' || echo 'Machine ID missing'
getent group systemd-journal
ss -ltnp | grep -E ':(8428|9428)\b' || true
```

Do not create a missing journal directory merely to satisfy a bind mount. If only `/run/log/journal` exists, record that the host uses volatile journal storage and obtain owner approval before changing configured mounts.

Record the numeric `systemd-journal` GID. Do not guess it. If Alloy cannot read journal files, the owner-approved correction is to add the actual GID to `obsvcealloy.group_add` in a separate repository commit and revalidate.

**Expected/pass:** Docker/Compose prerequisites are satisfied; Docker root, logging driver, cgroup driver/version, journal mode, filesystem, and actual listener state are recorded; ports 8428/9428 are available.

**Failure/stop:** missing Docker/Compose, insufficient disk/inodes, no usable journal source, or port conflict.

**Evidence:** versions, Docker root/logging/cgroup values, journal paths, filesystem details, free capacity, inodes, GID, listeners.

**Recovery:** no state changes. Resolve prerequisites before proceeding.

---

## G04 — OCI Compose resolution

**Purpose:** validate the complete Compose model before builds or startup.

**Prerequisites:** G03 passed; `.env` prepared on OCI.

**Commands:**

```bash
cd "${HOME}/servicehub-adr010-phase5"
git status --short
test -s .env || { echo 'BLOCKED: .env missing'; exit 1; }
chmod 600 .env
scripts/setup.sh
chmod 600 .env
docker compose config --quiet
docker compose config --services | sort | tee /tmp/servicehub-compose-services.txt
grep -Ei 'litellm|aiserv|stalwart|bulwark|mailsv' /tmp/servicehub-compose-services.txt && { echo 'FAIL: excluded service found'; exit 1; } || true
for name in APPS_DATA ENVIRONMENT DOMAIN_NAME IDENTITY_DOMAIN WORKSPACE_DOMAIN SOURCECODE_DOMAIN CLOUD_DOMAIN OBSERVABILITY_DOMAIN OBSERVABILITY_ADMIN_USER OBSERVABILITY_ADMIN_PASSWORD; do
  grep -q "^${name}=" .env && echo "${name}: present" || { echo "${name}: missing"; exit 1; }
done
docker compose config > /tmp/servicehub-resolved-compose.yml
chmod 600 /tmp/servicehub-resolved-compose.yml
rg -n '127\.0\.0\.1:(8428|9428):(8428|9428)' /tmp/servicehub-resolved-compose.yml
rg -n -i 'traefik.*(8428|9428)|(8428|9428).*traefik' /tmp/servicehub-resolved-compose.yml && { echo 'FAIL: backend exposed through Traefik'; exit 1; } || true
sed -n '/^[[:space:]]*obsvcealloy:/,/^[[:space:]]*[a-z]/p' /tmp/servicehub-resolved-compose.yml > /tmp/servicehub-alloy-service.yml
chmod 600 /tmp/servicehub-alloy-service.yml
```

Inspect the locally protected resolved Compose output for expected services `obsvcevm`, `obsvcevlogs`, `obsvcealloy`, `obsvcegrafanainit`, and `obsvcegrafana`. Verify Alloy has read-only `/`, `/proc`, `/sys`, cgroup, journal, and machine-ID mounts where present on the host. Record writable Docker socket access as the privileged security boundary. Do not cat the resolved Compose file if it could contain credentials.

**Expected/pass:** required services resolve; excluded services are absent; VM/VL host bindings are loopback-only; no Traefik route exposes them; Alloy mounts match the host journal mode.

**Failure/stop:** Compose error, missing required variable, unexpected service, excluded service, non-loopback backend binding, public Traefik exposure, or incorrect Alloy mount.

**Evidence:** command result, service list, variable-presence results, resolved bindings, Alloy mounts, commit, timestamp.

**Recovery:** do not start services. Correct environment outside Git or obtain an owner-approved repository correction.

---

## G05 — Alloy configuration validation

**Purpose:** validate Alloy syntax and references before startup.

**Prerequisites:** G04 passed.

**Commands:**

```bash
docker compose run --rm --no-deps --entrypoint alloy obsvcealloy validate /etc/alloy/config.alloy
docker compose run --rm --no-deps --entrypoint alloy obsvcealloy --help | sed -n '1,160p'
```

Also validate `shared/grafana/alloy/blackbox.yml` as blackbox-exporter YAML with an approved non-Alloy parser; do not invent an Alloy parse mode for it.

Review the validation result for the Unix host exporter, filesystem collector, cAdvisor, journal filters, Docker log source, blackbox probes, Authentik targets, oCIS target, PostgreSQL exporter handling, VM remote write, VictoriaLogs write, relabelling, secret filtering, and self-monitoring.

**Expected/pass:** Alloy validation exits 0 with no diagnostics; no included configuration is missing; absent PostgreSQL credentials do not make the configuration structurally invalid; no excluded AI/mail target exists.

**Failure/stop:** syntax error, unknown component, invalid reference, unsupported stability level, missing included file, or excluded target.

**Evidence:** exact command, Alloy version, validation output, image identity, timestamp.

**Recovery:** no service changes. Correct configuration by repository commit or record Blocked.

---

## G06 — Image builds and image identity

**Purpose:** build approved images and record reproducible identities.

**Prerequisites:** G05 passed; adequate OCI disk/network access.

**Commands:**

```bash
docker compose build obsvcevm obsvcevlogs obsvcealloy obsvcegrafana
for image in obsvcevm:latest obsvcevlogs:latest obsvcealloy:latest obsvcegrafana:latest; do
  docker image inspect "${image}" --format 'IMAGE={{.RepoTags}} ID={{.Id}} CREATED={{.Created}} ARCH={{.Architecture}} OS={{.Os}}'
  docker image inspect "${image}" --format 'IMAGE={{.RepoTags}} USER={{.Config.User}} ENTRYPOINT={{json .Config.Entrypoint}} CMD={{json .Config.Cmd}}'
done
docker compose images obsvcevm obsvcevlogs obsvcealloy obsvcegrafana
```

Capture product/version output during startup gates. VictoriaLogs must remain shell-less and pinned to the approved version and digest.

**Expected/pass:** all four images build and inspect successfully; image IDs, creation time, architecture, effective user, entrypoint, command, and product/version identity are recorded.

**Failure/stop:** build, pull, architecture, inspect, or shell installation failure.

**Evidence:** build log, complete image identity inventory, image IDs, creation timestamps, architecture, effective user, entrypoint, command, product/version.

**Recovery:** retain previous images from G02 until rollback evidence is complete.

---

## G07 — Persistent-storage preparation

**Purpose:** ensure persistent directories exist without deleting telemetry state.

**Prerequisites:** G06 passed; `${APPS_DATA}` known.

**Commands:**

```bash
install -d -m 0755 "${APPS_DATA}/obsvce/victoriametrics"
install -d -m 0755 "${APPS_DATA}/obsvce/victorialogs"
install -d -m 0755 "${APPS_DATA}/obsvce/grafana"
stat -c '%A %U:%G %n' "${APPS_DATA}/obsvce/victoriametrics" "${APPS_DATA}/obsvce/victorialogs" "${APPS_DATA}/obsvce/grafana"
du -sh "${APPS_DATA}/obsvce" 2>/dev/null || true
df -h "${APPS_DATA}/obsvce"
df -i "${APPS_DATA}/obsvce"
find "${APPS_DATA}/obsvce" -maxdepth 2 -printf '%M %u:%g %p\n' 2>/dev/null | sed -n '1,240p'
```

`obsvcegrafanainit` owns Grafana ownership. Do not recursively chown or chmod without first verifying the exact required container UID/GID from image inspect or a controlled one-shot command.

**Expected/pass:** directories exist and prior data, if any, remains intact.

**Failure/stop:** unsafe permission correction or unexpected missing storage.

**Evidence:** paths, ownership, sizes, capacity, inodes.

**Recovery:** never remove `${APPS_DATA}/obsvce`. Restore recorded ownership only with owner approval.

---

## G08 — VictoriaMetrics and VictoriaLogs startup

**Purpose:** establish storage health before collectors and dashboards.

**Prerequisites:** G07 passed.

**Commands:**

```bash
docker compose up -d --no-deps obsvcevm obsvcevlogs
sleep 10
docker compose ps obsvcevm obsvcevlogs
curl -fsS http://127.0.0.1:8428/health
curl -fsS http://127.0.0.1:9428/health
curl -fsS http://127.0.0.1:9428/-/healthy
curl -fsS http://127.0.0.1:9428/metrics >/dev/null
ss -ltnp | grep -E ':(8428|9428)\b'
docker compose logs --no-color --timestamps --tail=300 obsvcevm obsvcevlogs
```

Use host-side checks. Do not add a shell, curl, wget, or sidecar to VictoriaLogs.

**Expected/pass:** both services healthy, VictoriaLogs health/metrics endpoints respond, no restart loop, no storage permission/corruption error, and listeners are loopback-only.

**Failure/stop:** unhealthy state, startup error, public binding, data-path error, storage permission/corruption error, or shell-less image incompatibility.

**Evidence:** startup logs, health responses, listeners, versions, timestamps.

**Recovery:** stop only the affected service and revert to G02 image/configuration. Never delete data directories.

---

## G09 — Grafana initialization

**Purpose:** initialize Grafana persistence without exposing credentials.

**Prerequisites:** G08 passed.

**Commands:**

```bash
docker compose up --no-deps --abort-on-container-exit obsvcegrafanainit
docker compose ps -a obsvcegrafanainit
stat -c '%A %U:%G %n' "${APPS_DATA}/obsvce/grafana"
docker compose logs --no-color --timestamps obsvcegrafanainit
```

**Expected/pass:** initializer exits successfully, Grafana data directory is correctly owned and writable, and no secret value is printed.

**Failure/stop:** non-zero initialization exit, ownership error, or unrelated directory modification.

**Evidence:** logs, ownership, mode, timestamp.

**Recovery:** restore G07 ownership. Do not delete the Grafana database.

---

## G10 — Alloy startup and pipeline validation

**Purpose:** start the collector and verify metric, log, and probe pipelines.

**Prerequisites:** G08 and G09 passed.

**Commands:**

```bash
docker compose up -d --no-deps obsvcealloy
sleep 15
docker compose ps obsvcealloy
curl -fsS http://127.0.0.1:9080/health 2>/dev/null || true
docker compose logs --no-color --timestamps obsvcealloy
docker compose exec -T obsvcealloy curl -fsS http://localhost:9080/metrics > /tmp/alloy-metrics.txt
rg -n 'prometheus_remote_storage_(samples_failed|samples_pending|samples_dropped)_total|loki_source_docker|loki_source_journal|probe_' /tmp/alloy-metrics.txt | sed -n '1,240p'
```

Review startup logs for Unix exporter, filesystem/inode collection, cAdvisor, selective journal sources, Docker discovery, Traefik, Authentik, oCIS, blackbox, GeoIP, VM remote write, VictoriaLogs write, secret filtering, and self-metrics. If PostgreSQL credentials are absent, record that PostgreSQL is `Implemented in configuration; runtime prerequisite pending`; this must not prevent Alloy startup.

**Expected/pass:** Alloy loads configuration, remains healthy, has no repeated remote-write/log-write failures, and all approved pipelines start.

**Failure/stop:** configuration load failure, repeated write errors, unreadable journals, unsupported components, or Alloy startup failure caused by optional PostgreSQL prerequisites.

**Evidence:** startup logs, health output, selected self-metrics, error counters.

**Recovery:** stop only Alloy, correct configuration, and restart only Alloy.

---

## G11 — Grafana startup and provisioning

**Purpose:** verify Grafana, datasources, plugin, dashboards, and alerts.

**Prerequisites:** G10 passed.

**Commands:**

```bash
docker compose up -d --no-deps obsvcegrafana
sleep 20
docker compose ps obsvcegrafana
curl -fsS http://127.0.0.1:3000/api/health 2>/dev/null || true
docker compose logs --no-color --timestamps obsvcegrafana
grafana_domain="$(grep '^OBSERVABILITY_DOMAIN=' .env | cut -d= -f2- | tr -d '"')"
curl -fsSI "https://${grafana_domain}" | sed -n '1,20p'
```

From the UI or authenticated API inside the container, verify VictoriaMetrics UID `victoriametrics`, VictoriaLogs UID `victorialogs`, datasource tests, plugin installation, eight ServiceHub dashboards, Reference-only community dashboards, and 20 rules in `ServiceHub Alerts`.

Verify the public observability route redirects to Authentik as configured. Verify no LiteLLM dashboard is present.

**Expected/pass:** Grafana healthy; public route is Authentik-protected; all approved provisioning loads; LiteLLM dashboard is absent.

**Failure/stop:** provisioning error, missing plugin, datasource failure, duplicate UID, unauthenticated public access, missing auth redirect, or LiteLLM dashboard.

**Evidence:** logs, health output, public-route headers, datasource results, dashboard/alert inventory.

**Recovery:** stop only Grafana, inspect provisioning files, correct, and restart only Grafana.

---

## G12 — Metric validation

**Purpose:** verify representative host, container, edge, application, database, and observability metrics.

**Prerequisites:** G11 passed and scrape intervals elapsed.

**Commands:**

```bash
query_vm() {
  curl -fsSG 'http://127.0.0.1:8428/api/v1/query' --data-urlencode "query=$1"
}
query_vm 'up{project="servicehub"}'
query_vm 'node_filesystem_avail_bytes'
query_vm 'node_filesystem_files_free'
query_vm 'node_filesystem_readonly'
query_vm 'rate(node_cpu_seconds_total{mode="idle"}[5m])'
query_vm 'node_memory_MemAvailable_bytes'
query_vm 'rate(node_pressure_cpu_waiting_seconds_total[5m])'
query_vm 'rate(node_disk_read_bytes_total[5m])'
query_vm 'rate(node_network_receive_bytes_total[5m])'
query_vm 'container_cpu_usage_seconds_total'
query_vm 'container_memory_working_set_bytes'
query_vm 'container_oom_events_total'
query_vm 'traefik_service_requests_total'
query_vm 'traefik_service_request_duration_seconds_bucket'
query_vm 'authentik_tasks_queued'
query_vm 'probe_success{component="probe"}'
query_vm 'pg_up'
curl -fsS 'http://127.0.0.1:8428/api/v1/label/__name__/values' | jq -r '.data[]' | grep -E '^(traefik_|authentik_|ocis_)' | sort | tee /tmp/servicehub-discovered-metrics.txt
```

Inspect the discovered metric list before correcting dashboards and alerts. Do not assume Traefik's status label is `code`, or that router/service labels have a particular format. For each retained metric, query its actual series labels.

Record sample presence, labels, and timestamps. Record absent metrics as `metric absent`.

**Expected/pass:** approved host, container, filesystem, inode, Traefik, Authentik, oCIS, PostgreSQL, and observability metric families have current samples and labels consistent with runtime discovery.

**Failure/stop:** missing core infrastructure, filesystem, probe, or observability ingestion metrics. Application-specific gaps require owner-approved correction or deferral.

**Evidence:** redacted query outputs, discovered metric names, actual labels, timestamps, pass/fail.

**Recovery:** inspect Alloy/VM logs, correct scrape configuration, and restart only Alloy or the relevant service.

---

## G13 — Log validation

**Purpose:** verify selective journal, Docker, Traefik, application, and observability logs.

**Prerequisites:** G11 passed and ingestion has run.

**Commands:**

```bash
query_vl() {
  curl -fsS 'http://127.0.0.1:9428/select/logsql/query' --data-urlencode "query=$1" --data-urlencode 'limit=20'
}
query_vl '{project="servicehub"}'
query_vl '{project="servicehub",source="journal"}'
query_vl '{project="servicehub",source="journal",component="security"}'
query_vl '{project="servicehub",source="journal",component="system"}'
query_vl '{project="servicehub",source="journal",component="runtime"}'
query_vl '{project="servicehub",container_name="routetraefik"}'
query_vl '{project="servicehub",service="authentik"}'
query_vl '{project="servicehub",service="forgejo"}'
query_vl '{project="servicehub",service="forgejo",component="runner"}'
query_vl '{project="servicehub",service="ocis"}'
query_vl '{project="servicehub",service="confluence"}'
query_vl '{project="servicehub",container_name=~"obsvcealloy|obsvcevm|obsvcevlogs|obsvcegrafana"}'
docker inspect obsvcealloy --format 'LOG_DRIVER={{.HostConfig.LogConfig.Type}} LOG_OPTIONS={{json .HostConfig.LogConfig.Config}}'
```

For each relevant stream, record query syntax, stream labels, field names, container name, Compose service, source service, severity/level, client-IP field, GeoIP country, and GeoIP city. Update `docs/operations/LOG-TROUBLESHOOTING.md` when executed field names differ from documented recipes.

Record the effective Docker logging driver and log options. If local log rotation is unbounded or does not match the documented decision, classify Docker local log rotation as `Implemented in configuration; runtime prerequisite pending` and obtain owner approval before changing the daemon.

**Expected/pass:** journal, Docker, Traefik, Authentik, Confluence, Forgejo server, Forgejo Actions runner, oCIS, PostgreSQL, and observability logs are queryable.

**Failure/stop:** missing journal, Docker, Traefik access, or observability logs. Application gaps require owner-approved correction or deferral.

**Evidence:** query syntax, redacted samples, label/field mapping.

**Recovery:** correct Alloy stages or query syntax; restart only Alloy; do not delete log storage.

---

## G14 — Readiness and TLS probe validation

**Purpose:** verify internal readiness and public HTTPS/TLS behavior.

**Prerequisites:** G12 passed; DNS and certificates are production-valid.

**Commands:**

```bash
query_vm 'probe_success{component="probe"}'
query_vm 'probe_duration_seconds{component="probe"}'
query_vm 'probe_success{component="public-probe"}'
query_vm 'probe_duration_seconds{component="public-probe"}'
query_vm 'probe_ssl_earliest_cert_expiry{component="public-probe"} - time()'
for domain_name in DOMAIN_NAME IDENTITY_DOMAIN WORKSPACE_DOMAIN SOURCECODE_DOMAIN CLOUD_DOMAIN OBSERVABILITY_DOMAIN; do
  domain="$(grep "^${domain_name}=" .env | cut -d= -f2- | tr -d '"')"
  curl -fsSI "https://${domain}" | sed -n '1,20p'
done
```

Expected internal targets: Traefik, Authentik server/worker, Confluence, Forgejo, oCIS, Grafana, VictoriaMetrics, VictoriaLogs. Expected public targets: the six configured public ServiceHub HTTPS domains.

Confirm TLS verification is enabled, certificates are valid, DNS resolves from Alloy, and intentional authentication redirects are handled. Verify no internal health endpoint is exposed publicly solely for monitoring.

The Grafana public probe uses the `https_admin_restricted` blackbox module and
accepts either `200` (allowlisted source) or `403` (denied source) because
Grafana is protected by the Traefik `dashboard-whitelist` IP allowlist. This
is an intentional access-control response, not a failure. The probe still
requires valid HTTPS and TLS verification.

**Expected/pass:** probes return 1 and certificate expiry is positive.

**Failure/stop:** missing approved target, unresolved DNS, TLS failure, public internal health endpoint, unexpected authentication failure, or persistent probe 0.

**Evidence:** probe values, target names, durations, certificate expiry, DNS names.

**Recovery:** correct target, module, DNS, certificate, or firewall state. Never disable TLS verification.

---

## G15 — Dashboard-by-dashboard validation

**Purpose:** validate all eight authoritative ServiceHub dashboards.

**Prerequisites:** G12 and G13 passed.

Load each dashboard for a six-hour range and verify variables, panels, datasource resolution, errors, labels, and links.

| Dashboard | UID | Load | Datasources | Variables | Panels with data | NoData | Query errors | Label mismatches | Log links | Corrections |
|---|---|---|---|---|---|---|---|---|---|---|
| ServiceHub Overview | `servicehub-overview` | Record | Record | Record | Record | Record | Record | Record | Record | Record |
| Infrastructure | `servicehub-infrastructure` | Record | Record | Record | Record | Record | Record | Record | Not applicable | Record |
| Docker and Containers | `servicehub-docker-containers` | Record | Record | Record | Record | Record | Record | Record | Record | Record |
| Traffic and Edge | `servicehub-traffic-edge` | Record | Record | Record | Record | Record | Record | Record | Record | Record |
| Security | `servicehub-security` | Record | Record | Record | Record | Record | Record | Record | Record | Record |
| Applications | `servicehub-applications` | Record | Record | Record | Record | Record | Record | Record | Record | Record |
| Database | `servicehub-database` | Record | Record | Record | Record | Record | Record | Record | Not applicable | Record |
| Observability Health | `servicehub-observability-health` | Record | Record | Record | Record | Record | Record | Record | Record | Record |

Use this detailed result template for each dashboard:

```text
Dashboard:
UID:
Load status:
Datasource status:
Variables populated:
Panels with data:
NoData panels:
Query errors:
Label mismatches:
Log-link behavior:
Time-range behavior:
Service-filter behavior:
Corrections required:
```

**Expected/pass:** no material query error, datasource failure, or label mismatch. NoData may pass only with an explained expected condition.

**Failure/stop:** material failure in overview, infrastructure, Docker, traffic, security, or observability health. Application/database gaps require owner-approved correction or deferral.

**Evidence:** UIDs, screenshots/query outputs, variables, panel inventory, NoData rationale, corrections.

**Recovery:** correct dashboard JSON in Git and reload provisioning; do not treat a production dashboard edit as source of truth.

---

## G16 — Alert-rule validation

**Purpose:** validate all provisioned Grafana-managed rules safely.

**Prerequisites:** G11 passed; two evaluation intervals elapsed.

Permitted classifications:

| Classification | Use when |
|---|---|
| validated and enabled | expression, labels, and recovery are verified |
| valid but threshold tuning pending | expression/labels correct; tuning deferred |
| metric absent | expected metric does not exist |
| label mismatch | metric exists with different labels |
| intentionally disabled | owner approved disabling with reason |
| externally covered by OCI Monitoring | Grafana cannot observe the condition |

### Alert inventory template

| Rule UID | Rule | Expected signal | Observed state | Classification | Firing/recovery evidence | Correction |
|---|---|---|---|---|---|---|
| `servicehub-fs-critical` | Filesystem critically full | filesystem capacity | Record | Record | Record | Record |
| `servicehub-inode-critical` | Inode exhaustion imminent | inode capacity | Record | Record | Record | Record |
| `servicehub-fs-readonly` | Filesystem became read-only | readonly state | Record | Record | Record | Record |
| `servicehub-traefik-critical` | Traefik unavailable | readiness probe | Record | Record | Record | Record |
| `servicehub-authentik-critical` | Authentik unavailable | server/worker probe | Record | Record | Record | Record |
| `servicehub-confluence-critical` | Confluence unavailable | readiness probe | Record | Record | Record | Record |
| `servicehub-forgejo-critical` | Forgejo unavailable | readiness probe | Record | Record | Record | Record |
| `servicehub-ocis-critical` | oCIS unavailable | readiness probe | Record | Record | Record | Record |
| `servicehub-container-restart-loop` | Container restart loop | start-time changes | Record | Record | Record | Record |
| `servicehub-container-oom` | Container OOM event | OOM counter | Record | Record | Record | Record |
| `servicehub-telemetry-ingestion` | Telemetry remote-write failed | remote-write failures | Record | Record | Record | Record |
| `servicehub-postgresql-critical` | PostgreSQL unavailable | `pg_up` | Record | Record | Record | Record |
| `servicehub-fs-warning` | Filesystem approaching capacity | filesystem capacity | Record | Record | Record | Record |
| `servicehub-cpu-pressure` | Sustained CPU pressure | CPU PSI | Record | Record | Record | Record |
| `servicehub-memory-pressure` | Sustained memory pressure | memory PSI | Record | Record | Record | Record |
| `servicehub-io-pressure` | Sustained I/O pressure | I/O PSI | Record | Record | Record | Record |
| `servicehub-tls-expiry` | TLS certificate approaching expiry | certificate expiry | Record | Record | Record | Record |
| `servicehub-traefik-5xx` | Sustained Traefik HTTP 5xx rate | request counters | Record | Record | Record | Record |
| `servicehub-traefik-latency` | Sustained Traefik latency degradation | latency histogram | Record | Record | Record | Record |
| `servicehub-runner-warning` | Forgejo Actions Runner unavailable | cAdvisor last-seen | Record | Record | Record | Record |

### Safe validation procedure

1. Inspect datasource, expression, interval, `for`, no-data state, execution-error state, labels, and annotations.
2. Run the rule query in Explore and compare labels.
3. Verify current state and last evaluation error.
4. To prove a threshold, use a separate temporary test rule or safely modified temporary group. Never fill disks or stop production services.
5. Remove temporary rules and restore the repository-defined set.
6. Confirm no production rule is unexpectedly Error or NoData.

Use this result template for each tested rule:

```text
Alert name:
UID:
Classification:
Metric present:
Labels correct:
Pending tested:
Firing tested:
Recovery tested:
No-data behavior:
Execution-error behavior:
Threshold tuning required:
Notification tested:
```

For NoData behavior, use a dedicated test expression that returns no series. Do not interrupt production ingestion or remove a production datasource.

Notification delivery remains **Deferred** unless an owner-approved contact point is configured and tested. OCI Monitoring remains the external watchdog for VM/total-stack failure.

**Expected/pass:** every rule has a permitted classification and no unexpected Error/NoData.

**Failure/stop:** unevaluable expression, missing core metric, material label mismatch, or undeletable temporary rule.

**Evidence:** definitions, query outputs, states, classification, firing/recovery, notification status.

**Recovery:** restore rules from Git and reload Grafana provisioning. Do not retain temporary rules.

---

## G17 — PostgreSQL validation

**Purpose:** verify least-privilege PostgreSQL monitoring without committing credentials.

**Prerequisites:** G12 passed; owner available to create the role manually.

Review `docs/operations/services/postgresql.md`. The owner manually creates the role. Secrets stay in `.env` or the approved secret mechanism; never commit, print, or e-mail them.

**Commands:**

```bash
docker compose exec -T infrapgsql psql -U "${POSTGRES_EXPORTER_USER:?}" -d "${POSTGRES_EXPORTER_DATABASE:?}" -c 'SELECT current_user, pg_is_in_recovery();'
docker compose exec -T infrapgsql psql -U "${POSTGRES_EXPORTER_USER:?}" -d "${POSTGRES_EXPORTER_DATABASE:?}" -c "SELECT pg_has_role(current_user, 'pg_monitor', 'member') AS has_pg_monitor;"
docker compose exec -T infrapgsql psql -U "${POSTGRES_EXPORTER_USER:?}" -d "${POSTGRES_EXPORTER_DATABASE:?}" -c "SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolreplication FROM pg_roles WHERE rolname = current_user;"
for name in POSTGRES_EXPORTER_HOST POSTGRES_EXPORTER_PORT POSTGRES_EXPORTER_DATABASE POSTGRES_EXPORTER_USER POSTGRES_EXPORTER_PASSWORD; do
  grep -q "^${name}=" .env && echo "${name}: present" || echo "${name}: missing"
done
git grep -nE 'POSTGRES_EXPORTER_PASSWORD=.+' -- . ':!env.example' || true
grep '^POSTGRES_EXPORTER_HOST=' .env | cut -d= -f2- | tr -d '"' | sed 's/.*/POSTGRES_EXPORTER_HOST: recorded/'
```

Verify exporter metrics:

```bash
query_vm 'pg_up'
query_vm 'pg_stat_activity_count'
query_vm 'pg_stat_database_xact_commit'
query_vm 'pg_stat_database_xact_rollback'
query_vm 'pg_locks_count'
query_vm 'pg_stat_database_deadlocks'
query_vm 'pg_stat_activity_max_tx_duration'
query_vm 'pg_database_size_bytes'
query_vm 'pg_stat_database_temp_bytes'
query_vm 'sum by (state) (pg_stat_activity_count)'
query_vm 'max(pg_settings_max_connections)'
query_vm 'sum(rate(pg_stat_database_blks_hit[5m]))'
query_vm 'sum(rate(pg_stat_database_blks_read[5m]))'
```

### WAL collector runtime disposition (2026-10-20, OCI host)

Runtime verification recorded during Phase 5 continuation:

- `pg_catalog.pg_ls_waldir()` is owned by `dbservice`. Its ACL is `{dbservice=X/dbservice,pg_monitor=X/dbservice,svc_metrics=X/dbservice}`.
- `svc_metrics` is already an explicit ACL entry via its `pg_monitor` membership, so **no additional grant was applied**. `has_function_privilege('svc_metrics','pg_catalog.pg_ls_waldir()','EXECUTE')` returns `true`.
- Direct execution as `svc_metrics` succeeds: 3 WAL files, 50331648 aggregate bytes. No WAL filenames were recorded.
- The `wal` collector reports `pg_scrape_collector_success{collector="wal"} == 1`, and no `permission denied for function pg_ls_waldir` error appears in Alloy logs.
- WAL metrics confirmed present: `pg_wal_segments` and `pg_wal_size_bytes` (labels `instance="postgresql://infrapgsql:5432/postgres"`, `job="integrations/postgres"`).
- `pg_wal_lsn_diff` does **not** exist in this deployment. The Database dashboard WAL panel (refId C, `rate(pg_wal_lsn_diff[5m])`) is therefore incompatible with the deployed exporter. The panel was left unchanged pending an owner-approved, evidence-based replacement.
- `pg_stat_user_tables` and `pg_stat_progress_vacuum` return zero series while their collectors report success; this is expected while the monitored database has no qualifying activity.
- Database size is exposed as `pg_database_size_bytes`, not `pg_stat_database_size`.

### Phase 5 final acceptance evidence (2026-10-20)

WAL function privilege:

- No WAL function grant was required. The pre-existing function ACL already allowed
  `svc_metrics` to execute `pg_catalog.pg_ls_waldir()`.
- The pre-existing privilege was verified with
  `has_function_privilege('svc_metrics','pg_catalog.pg_ls_waldir()','EXECUTE')`.
- WAL function execution succeeded under `svc_metrics`: 3 WAL files, 50331648 aggregate
  bytes. No WAL filenames were recorded.
- No WAL privilege rollback is required, because no privilege change was made. The
  documented `REVOKE EXECUTE` is an intentional decommissioning action for a future
  collector disablement, not a Phase 5 rollback.

Database dashboard:

- The WAL panel query was corrected using runtime evidence, from
  `rate(pg_wal_lsn_diff[5m])` to `pg_wal_size_bytes`, with panel title
  `Current WAL Size` and unit `bytes`.
- Final status: all 12 Database dashboard query targets return data, with no query
  errors. Dashboard UID `servicehub-database` is unchanged.

Sensitive credential:

- The `svc_metrics` monitoring password was rotated after exposure in retained
  transcript output. No secret value is recorded in this repository.
- Rotation preserved LOGIN, NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOINHERIT,
  NOREPLICATION, NOBYPASSRLS, connection limit 5, `pg_monitor` membership, `CONNECT`,
  and the existing function ACL.
- After recreating only `obsvcealloy`: `pg_up == 1`, `pg_exporter_last_scrape_error == 0`,
  all 11 collectors report success, and no authentication, timeout, remote-write, or
  credential-leakage log entries were recorded.

Final runtime status:

- cAdvisor: `containerd_host` configured through the existing read-only mount;
  per-container series present with real container `name` labels.
- Alerts: `servicehub-postgresql-critical` Normal with `noDataState: Alerting` retained.
  `servicehub-fs-readonly` no longer fires because the intentional `/cdrom` mount is
  excluded.

Remaining deferred items:

- `servicehub-runner-warning` fires because `devopsrunner` is an in-scope service in
  `compose/devops.yml` with no deployed container. It is classified as an in-scope
  required service awaiting deployment, not an intentionally disabled optional runner.
- OCI APM, Confluence JMX, notification delivery pending an approved contact point,
  external whole-host watchdog, final retention tuning, and final threshold tuning
  remain deferred per ADR-010.

Discover additional PostgreSQL exporter metric names before assuming a family exists:

```bash
curl -fsS 'http://127.0.0.1:8428/api/v1/label/__name__/values' | jq -r '.data[]' | grep '^pg_' | sort
```

Record the configured PostgreSQL DSN behavior without printing credentials. The repository currently uses `sslmode=disable` for the internal-only Docker network. Record this as an accepted internal-network trust decision. If the owner requires TLS for database telemetry, correct the DSN, certificate trust, and PostgreSQL server settings before validation.

If the role, secret, or connectivity prerequisite is not ready, classify PostgreSQL as `Implemented in configuration; runtime prerequisite pending`. Core acceptance may then be conditional only if the owner explicitly accepts that PostgreSQL telemetry prerequisite remains open.

Controlled exporter-failure isolation test:

1. Record normal PostgreSQL metrics.
2. In an owner-approved maintenance window, back up the original runtime-only password outside Git, set an invalid `POSTGRES_EXPORTER_PASSWORD`, and recreate only Alloy.
3. Verify Alloy starts and remains healthy while recording the exporter error.
4. Restore the original runtime-only value and recreate only Alloy.
5. Verify PostgreSQL metrics recover.

**Expected/pass:** least-privilege role works, `pg_monitor` membership exists, metrics are present, Git has no credential value, DSN/SSL behavior is recorded, and exporter failure does not stop Alloy.

**Failure/stop:** excessive privileges, credential in Git, absent core metrics, unexpected network exposure, or Alloy startup failure.

**Evidence:** role checks, metric outputs, Git scan, DSN/SSL decision, isolation test, restoration confirmation without secret content.

**Recovery:** restore the original runtime environment, recreate only Alloy, and correct the role with owner approval.

---

## G18 — Confluence baseline validation and JMX deferral

**Purpose:** accept Confluence baseline telemetry while keeping JMX explicitly deferred.

**Prerequisites:** G12, G13, and G14 passed.

**Commands:**

```bash
query_vm 'container_cpu_usage_seconds_total{name="webappconf"}'
query_vm 'container_memory_working_set_bytes{name="webappconf"}'
query_vm 'probe_success{service="confluence"}'
query_vm 'sum(rate(traefik_service_requests_total{service=~".*confluence.*"}[5m]))'
query_vm 'sum(rate(traefik_service_requests_total{service=~".*confluence.*",code=~"5.."}[5m]))'
query_vm 'histogram_quantile(0.95, sum by (le) (rate(traefik_service_request_duration_seconds_bucket{service=~".*confluence.*"}[5m])))'
query_vl '{project="servicehub",container_name="webappconf"}'
```

Record actual Traefik service labels and correct queries/dashboards if they differ.

**Status:** Confluence JVM/application JMX telemetry is **Deferred pending approved JMX exporter dependency**. Do not download or install an arbitrary exporter. Do not let JMX block core acceptance.

**Expected/pass:** container metrics, logs, readiness, Traefik requests, 5xx, and latency are observable.

**Failure/stop:** baseline Confluence telemetry or readiness fails. Missing JMX is not a stop condition.

**Evidence:** metric outputs, log samples, probe result, label mapping, JMX deferral reason.

**Recovery:** correct baseline telemetry. No JMX action is required for core acceptance.

---

## G19 — Excluded-service verification

**Purpose:** prove excluded AI/mail services have no active observability or runtime presence.

**Prerequisites:** G12, G13, and G16 have run.

**Repository commands:**

```bash
rg -n -i 'litellm|aiserv|stalwart|bulwark|mailsv' \
  compose/obsvce.yml \
  compose/infra.yml \
  shared/grafana \
  shared/victoriametrics \
  shared/victorialogs || true
```

Only clearly historical/archive references are permitted. No active scrape, pipeline, probe, dashboard, alert, or runbook target may remain.

**Runtime commands:**

```bash
docker compose ps -a | grep -Ei 'litellm|aiserv|stalwart|bulwark|mailsv' && { echo 'FAIL: excluded service present'; exit 1; } || true
docker ps --format '{{.Names}}' | grep -Ei 'litellm|aiserv|stalwart|bulwark|mailsv' && { echo 'FAIL: excluded container present'; exit 1; } || true
for token in litellm aiserv stalwart bulwark mailsv; do
  curl -fsSG 'http://127.0.0.1:8428/api/v1/query' --data-urlencode "query={job=~\".*${token}.*\"}" | jq -e '.data.result | length == 0'
  curl -fsS 'http://127.0.0.1:9428/select/logsql/query' --data-urlencode "query={project=\"servicehub\",container_name!=\"servicehub-obsvcevlogs-1\"} | filter message:~\"(?i)${token}\"" --data-urlencode 'limit=1' | jq -e 'length == 0'
done
```

**Runtime correction recorded 2026-10-20.** The previous VictoriaLogs query
`{project="servicehub"} |~ "(?i)${token}"` is invalid LogsQL and returns HTTP 400
(`cannot parse 'filter' pipe: missing ':' in front of "~"`). It never executed.

The approved correction named `_msg` as the search field, but `_msg` does not exist
in runtime data: VictoriaLogs returns a synthetic `missing _msg field` placeholder, and
`filter _msg:~"authenticated"` matches 0 records. The field that actually carries log
text is `message` (`filter message:~"authenticated"` matches). The validated correction
therefore uses `message`:

```text
{project="servicehub",container_name!="servicehub-obsvcevlogs-1"} | filter message:~"(?i)${token}"
```

Runtime verification of that form:

- HTTP 200;
- excludes the VictoriaLogs container's own validation messages via `container_name`;
- still returns other ServiceHub containers (for example `servicehub-webappocis-1`);
- returns zero matches for excluded-service tokens;
- uses runtime field names (`container_name`, `message`).

Keep this query on one line in the committed file if command or URL encoding requires it.

In Grafana, verify no excluded service appears in active dashboards, variables, alerts, or notification text.

**Expected/pass:** no active excluded-service telemetry or running OCI services.

**Failure/stop:** active ADR-010-created reference or container. Do not delete unrelated mail work.

**Evidence:** scans, empty runtime results, Grafana search results, historical classification.

**Recovery:** remove only active ADR-010 references through a repository correction; preserve historical records.

---

## G20 — Persistence testing

**Purpose:** prove telemetry and configuration survive controlled recreation.

**Prerequisites:** G12–G18 passed; rollback evidence exists; owner approved recreation.

**Commands:**

```bash
for service in obsvcevm obsvcevlogs obsvcealloy obsvcegrafana; do
  before="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  docker compose up -d --no-deps --force-recreate "${service}"
  sleep 20
  docker compose ps "${service}"
  after="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "SERVICE=${service} BEFORE=${before} AFTER=${after}"
done
curl -fsS http://127.0.0.1:8428/health
curl -fsS http://127.0.0.1:9428/health
query_vm 'up{project="servicehub"}'
query_vl '{project="servicehub"}'
curl -fsS http://127.0.0.1:3000/api/health
```

Do not use `docker compose down`, `docker compose down -v`, or delete `${APPS_DATA}/obsvce`.

**Expected/pass:** services return and historical data/configuration remains queryable.

**Failure/stop:** data loss, provisioning loss, binding change, or crash loop.

**Evidence:** before/after timestamps, states, health outputs, continuity queries, Grafana inventory.

**Recovery:** stop only the failed service and restore its previous image/configuration from G02. Never delete persistent data.

---

## G21 — Evidence recording and acceptance decision

**Purpose:** convert gate results into durable repository evidence and an explicit decision.

**Prerequisites:** all gates executed and classified.

Update only:

- `docs/operations/MONITORING-ALERTING.md`
- `docs/operations/LOG-TROUBLESHOOTING.md`
- `docs/operations/runbooks/ADR-010-PHASE-5-OCI-VALIDATION.md`

Evidence record:

```text
Capability:
Status:
OCI host:
UTC evidence timestamp:
Commit/image/version:
Command or UI action:
Redacted result:
Query or dashboard UID:
Alert test result:
Correction:
Follow-up:
```

Do not change ADR-010 status; it remains Accepted. Phase 5 evidence is separate from ADR status.

Final Phase 5 report must include:

1. OCI checkout path, branch, and commit
2. Preservation evidence
3. Compose validation result
4. Alloy validation result
5. Host prerequisites and Docker/journald identity
6. Images and versions
7. Storage directory ownership and initial size
8. VictoriaMetrics health
9. VictoriaLogs health
10. Grafana initializer result
11. Alloy component and pipeline health
12. Grafana health and provisioning
13. Actual metrics and labels
14. Actual VictoriaLogs fields and queries
15. Probe results
16. Dashboard-by-dashboard status
17. Alert-by-alert classification
18. Notification status
19. PostgreSQL status
20. Confluence JMX status
21. Excluded-service verification
22. Persistence-test result
23. Storage baseline and growth
24. Repository corrections required
25. Runtime corrections applied
26. Remaining blockers
27. Documentation updates
28. Exact rollback procedure
29. Final acceptance recommendation
30. Docker logging decision status
31. Retention decision status
32. OCI Monitoring and manual-action status

Acceptance options:

| Decision | Requirements |
|---|---|
| Accepted: ADR-010 core runtime implementation verified | all core requirements passed; no material failures |
| Conditionally accepted: core runtime verified with documented deferred items | all core requirements passed; only owner-approved deferred items remain |
| Not accepted: material runtime failures remain | one or more core requirements failed or lacks evidence |

Record OCI Monitoring as either `Runtime verified`, `Deferred`, or `Blocked`. It is not part of Grafana self-monitoring because Grafana cannot reliably report its own total failure.

**Expected/pass:** all gate records, evidence, corrections, and follow-ups are committed.

**Failure/stop:** missing, failed, blocked, or unevidenced core gate.

**Evidence:** updated operational documents and commit ID.

**Recovery:** retain evidence even if the decision is not accepted.

---

## G22 — Rollback

**Purpose:** restore the pre-Phase 5 state without deleting telemetry or unrelated work.

**Prerequisites:** G02 backup path, prior commit, image IDs, and container state available.

**Sequence:**

1. Stop further changes.
2. Record current Compose, image, log, and Git state.
3. If repository state must change, use a deliberate revert commit or switch from the preserved prior clean checkout/clone. Never `git reset --hard` a dirty production checkout and never `git clean -fd`.
4. Restore only Phase 5-changed services using prior image IDs, one service at a time.
5. Re-run Compose resolution and health checks.
6. Verify unrelated `compose/mailsv.yml` state is unchanged.
7. Preserve new evidence before cleanup. Do not delete `${APPS_DATA}/obsvce`.
8. Remove only unapproved temporary rules or runtime values.

**Expected/pass:** prior services run from prior images/configuration; unrelated changes and persistent data remain intact.

**Failure/stop:** rollback would require persistent-data deletion, overwrite of unrelated work, or force-reset of a production checkout.

**Evidence:** rollback start/finish, restored image IDs, service states, Git state, health/data-integrity checks.

**Recovery:** retain failed-attempt and rollback evidence for the owner's acceptance review.
