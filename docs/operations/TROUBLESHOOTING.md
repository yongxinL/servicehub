---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: TROUBLESHOOTING
title: ServiceHub Troubleshooting
version: "1.0.1"
status: Draft
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-06
tags:
  - servicehub
  - operations
  - troubleshooting
related_documents:
  - RUNBOOK
  - SERVICE-INVENTORY
  - MONITORING-ALERTING
---

# ServiceHub Troubleshooting

Start with read-only diagnostics. Do not paste resolved Compose output, environment values, tokens, keys, or private log content into issues or documentation. Escalation contacts are `TBD`.

## Traefik Route Unavailable

**Symptoms:** The configured hostname returns a Traefik error, connection failure, or reaches the wrong service.

**Likely causes:** Traefik unhealthy, Docker provider cannot inspect labels, service unhealthy, hostname mismatch, disabled route label, or service not on `subnet`.

**Evidence to collect:** `docker compose ps`, Traefik logs, relevant Compose label, DNS resolution, container network membership, and target port.

**Diagnostic steps:** Validate configuration, confirm `routetraefik` health, confirm the target service is running, inspect its Traefik labels, and test the internal port from the Docker network.

**Resolution:** Correct configuration through a reviewed change, rebuild or restart the affected service, then retest DNS, route, and health. Do not expose an ad-hoc host port as a workaround without security review.

**Escalation:** Escalate if Traefik itself is unhealthy or multiple routes fail.

**Related documents:** [Deployment architecture](../architecture/DEPLOYMENT-ARCHITECTURE.md), [component catalogue](../architecture/COMPONENT-CATALOGUE.md).

## TLS Failure

**Symptoms:** Certificate warning, handshake failure, expired certificate, or HTTP redirect succeeds but HTTPS fails.

**Likely causes:** DNS mismatch, ACME challenge failure, missing or unreadable `acme.json`, wrong `CERTRESOLVER`, self-signed trust, or clock problem.

**Evidence to collect:** `CERTRESOLVER` name only, DNS result, certificate chain returned for `<hostname>`, Traefik logs, certificate file mode, and current time.

**Diagnostic steps:** Validate configuration, confirm Traefik health, inspect certificate output with `openssl s_client -connect <hostname>:443 -servername <hostname>`, and compare SANs with the requested hostname.

**Resolution:** Correct DNS or resolver configuration, restore valid protected certificate material, or approve renewed issuance. Never publish certificate private-key content.

**Escalation:** Escalate repeated CA failures, unexpected certificate replacement, or suspected private-key exposure.

**Related documents:** [Runbook](RUNBOOK.md), [backup and restore](BACKUP-RESTORE.md).

## Authentik Unavailable

**Symptoms:** Login page fails, protected routes cannot authenticate, worker errors, or outposts do not respond.

**Likely causes:** Authentik service unhealthy, worker not started, PostgreSQL unavailable, initialiser failure, memory pressure, or certificate/configuration error.

**Evidence to collect:** `docker compose ps infraauth infraauthwrk infraauthinit infrapgsql`, recent server and worker logs, PostgreSQL health, and disk or memory signals.

**Diagnostic steps:** Confirm PostgreSQL health, complete initialiser status, inspect Authentik logs for database or secret errors, and test the Authentik route separately from downstream applications.

**Resolution:** Restore the failing dependency, correct reviewed configuration, and restart the worker and server in dependency order. Preserve the break-glass path; its procedure is `TBD`.

**Escalation:** Escalate if login recovery or administrator access may be lost.

**Related documents:** [ADR-004](../adr/ADR-004-use-authentik-for-central-identity.md), [Authentik README](../../shared/authentik/README.md).

## Forward-Auth Redirect Loop

**Symptoms:** Browser repeatedly redirects between an application and Authentik or never reaches the application.

**Likely causes:** Wrong issuer or root URL, proxy header mismatch, trusted proxy CIDR mismatch, stale session, cookie domain issue, or conflicting IP allowlist and forward-auth middleware.

**Evidence to collect:** Redirect chain, response headers with cookies redacted, Traefik middleware chain, `TRUSTED_IP`, Authentik application URLs, and timestamps.

**Diagnostic steps:** Test the application route in a private browser session, confirm the middleware order, verify Authentik's externally reachable URL, and compare forwarded-header trust with the actual ingress path.

**Resolution:** Correct reviewed URL, proxy, cookie, or middleware configuration; clear only test sessions; restart affected routing components if required.

**Escalation:** Escalate if administrator login is unavailable or the loop affects multiple protected services.

**Related documents:** [Forward-auth middleware](../../shared/traefik/advanced/middlewares-authentik.yml), [troubleshooting test plan](../testing/TEST-001-platform-baseline-validation.md).

## Identity Console Rate-Limited (429)

**Symptoms:** The Authentik admin console (`admin/#/...`) never finishes loading; the browser console shows `429` responses for `/static/...` chunks and `Failed to fetch dynamically imported module`.

**Likely causes:** The `rate-limit` middleware in `secure-chain` (20 req/s average, burst 50, per client IP) is exhausted by the admin SPA's parallel chunk and API requests on a cold cache, several open tabs, or multiple clients sharing one public address.

**Evidence to collect:** Browser developer-tools network log (status 429 and request paths), Traefik access logs (`docker logs routetraefik | grep ' 429 '`), the `infraauth` router labels, and [`shared/traefik/advanced/middlewares-security.yml`](../../shared/traefik/advanced/middlewares-security.yml).

**Diagnostic steps:** Confirm the 429 responses target the identity hostname, confirm the router uses `secure-chain@file`, and check whether the address is shared by several clients.

**Resolution:** The `/static/` exemption ships as router `infraauth-static` ([`compose/infra.yml`](../../compose/infra.yml), priority 200, `secure-headers` only); redeploy the identity service so Traefik picks up the labels, then reload the console. If non-static requests still trip the limit for a legitimately shared address, raise `burst` in `middlewares-security.yml` through a reviewed change. The bucket refills 20 requests per second, so a quiet reload also clears it.

**Escalation:** Escalate if 429s continue on a quiet, single-client load after the exemption is deployed.

**Related documents:** [Traefik security middlewares](../../shared/traefik/README.md#security-middlewares), [ADR-002](../adr/ADR-002-use-traefik-as-ingress.md).

## Database Connection Failure

**Symptoms:** Applications report connection refused, authentication failure, missing database, or `pg_isready` fails.

**Likely causes:** PostgreSQL unhealthy, wrong service name or port, missing database in `POSTGRES_DATABASES`, credential mismatch, disk full, permissions, or resource exhaustion.

**Evidence to collect:** PostgreSQL health, Compose environment variable names only, dependent-service logs, disk space, database directory ownership, and connection errors with credentials redacted.

**Diagnostic steps:** Confirm `infrapgsql` health and logs, confirm the dependent service is on `subnet`, verify database name configuration, then test connectivity from the dependent container.

**Resolution:** Restore the database service or disk capacity, correct reviewed configuration, and create missing databases or grants using an approved procedure. Do not reset persistent data as a first action.

**Escalation:** Escalate suspected corruption, unexplained restarts, or data loss.

**Related documents:** [PostgreSQL README](../../shared/postgresql/README.md), [backup and restore](BACKUP-RESTORE.md).

## Forgejo Unavailable

**Symptoms:** Repository URL fails, health endpoint errors, clone fails, or Actions do not appear.

**Likely causes:** Forgejo unhealthy, PostgreSQL or Authentik dependency failure, disk full, repository data permission problem, route failure, or disabled Actions unit.

**Evidence to collect:** `docker compose ps devopsforgejo`, Forgejo logs, PostgreSQL health, route result, repository path free space, and runner status.

**Diagnostic steps:** Check dependencies and health first, then test the internal port, route, and registration settings. Keep repository data untouched.

**Resolution:** Restore dependencies or disk capacity, correct reviewed configuration, and rebuild only `devopsforgejo` if its image changed.

**Escalation:** Escalate repository corruption, access-control failure, or inability to recover repositories.

**Related documents:** [Forgejo README](../../shared/forgejo/README.md), [service inventory](SERVICE-INVENTORY.md).

## Runner Deployment Failure

**Symptoms:** Workflow remains queued, runner is offline, checkout fails, SSH fails, or remote Compose command fails.

**Likely causes:** Runner unhealthy or unregistered, label mismatch, missing repository or target secrets, unknown-host mismatch, network access failure, insufficient remote permissions, or Compose error.

**Evidence to collect:** Runner health and logs, Forgejo runner registration state, workflow log stage, secret names that are missing with values omitted, remote prerequisite test result, and Compose validation output.

**Diagnostic steps:** Confirm `devopsrunner` health and `.runner`, confirm `ssh-deploy` label, run the repository remote-access workflow, then isolate checkout, SSH, environment restore, and Compose stages.

**Resolution:** Correct the failing configuration or secret, re-register the runner only under the documented procedure, and rerun a low-impact staging deployment.

**Escalation:** Escalate repeated SSH host-key mismatch, credential exposure, or remote filesystem damage.

**Related documents:** [Deployment architecture](../architecture/DEPLOYMENT-ARCHITECTURE.md), [Forgejo README](../../shared/forgejo/README.md).

## WordPress Failure

**Symptoms:** The optional WordPress route fails, shows database errors, or the service is missing.

**Likely causes:** WordPress Compose file not included, `inframariadb` unhealthy, database not in `MARIADB_DATABASES`, route conflict with Confluence, or bind-mount ownership problem.

**Evidence to collect:** Root include list, optional Compose definition, MariaDB health and logs, route rule, WordPress logs, and persistent directory state.

**Diagnostic steps:** Confirm whether WordPress is intentionally enabled, validate its Compose file, check MariaDB health and database-name configuration, then test the route.

**Resolution:** Follow the [WordPress README](../../shared/wordpress/README.md) for an approved enablement or repair. Do not swap the default homepage during an incident without a change record.

**Escalation:** Escalate if enabling or disabling WordPress threatens Confluence data or routing.

**Related documents:** [WordPress README](../../shared/wordpress/README.md), [roadmap](../requirements/ROADMAP.md).

## LiteLLM Unavailable

**Symptoms:** Hermes or Open WebUI cannot obtain completions, the LiteLLM health endpoint fails, or its UI/API port is unreachable.

**Likely causes:** Service unhealthy, PostgreSQL unavailable, invalid master key, provider configuration error, container restart, or host-port conflict.

**Evidence to collect:** `docker compose ps aiservlitellm infrapgsql`, LiteLLM logs, health status, provider error class with keys redacted, and route or port reachability.

**Diagnostic steps:** Confirm PostgreSQL health, inspect LiteLLM startup and configuration-overwrite logs, test declared health, then isolate provider failures from proxy failure.

**Resolution:** Restore the dependency or correct reviewed configuration, restart `aiservlitellm`, and retest local and cloud routes separately.

**Escalation:** Escalate suspected key exposure or persistent provider outage.

**Related documents:** [LiteLLM README](../../shared/litellm/README.md), [ADR-005](../adr/ADR-005-use-litellm-for-ai-routing.md).

## Local Model Unavailable

**Symptoms:** `hephaestus` health fails, model download stalls, llama.cpp restarts, or local inference times out.

**Likely causes:** Model missing or incomplete, insufficient memory, long startup, Hugging Face access issue, invalid model name, container health start period, or host resource pressure.

**Evidence to collect:** `aiservllamacpp` health and logs, local port health, model cache path and free space without listing sensitive files, host memory pressure, and configured model name.

**Diagnostic steps:** Confirm container health after the configured start period, review download or load errors, verify cache integrity and disk space, and test local inference directly before LiteLLM.

**Resolution:** Restore model cache from an approved source, correct model configuration, or resolve host capacity. Avoid deleting the model cache without a recovery source.

**Escalation:** Escalate persistent memory pressure or repeated crashes affecting the host.

**Related documents:** [llama.cpp README](../../shared/llamacpp/README.md), [AI phase](../phases/PHASE-003-ai-platform.md).

## Wrong AI Routing Destination

**Symptoms:** A local request reaches the cloud target, a cloud-tagged request stays local, or fallback occurs unexpectedly.

**Likely causes:** User tags, keyword classification, approximate token threshold, local health failure, context-window fallback, provider failure fallback, or runtime config override.

**Evidence to collect:** Smart-router logs, model before and after routing, reason field, input size class without recording private content, local health, fallback flags, and active configuration file location.

**Diagnostic steps:** Reproduce with approved non-sensitive test messages for each rule, compare runtime config with `config.default.yaml`, and check whether explicit tags disabled fallback.

**Resolution:** Correct the routing configuration or user instruction through a reviewed change and rerun privacy, local, cloud, unhealthy-local, and context tests.

**Escalation:** Escalate immediately if privacy-sensitive content reaches a cloud provider contrary to policy.

**Related documents:** [Smart router](../../shared/litellm/smartrouter.py), [AI test cases](../testing/TEST-001-platform-baseline-validation.md).

## Grafana Data Missing

**Symptoms:** Dashboards show no data, datasource errors, or missing logs.

**Likely causes:** VictoriaMetrics or VictoriaLogs unavailable, Grafana datasource URL wrong, Alloy stopped, time range mismatch, label mismatch, or provisioning failure.

**Evidence to collect:** Grafana health, datasource test output, store health, Alloy health and logs, query time range, and provisioned datasource configuration.

**Diagnostic steps:** Test each datasource independently, confirm store health, query a known metric or recent log, then confirm Alloy delivery.

**Resolution:** Restore the failing store or collector, correct reviewed provisioning, and wait for data arrival before judging a query.

**Escalation:** Escalate if historical data may have been lost or overwritten.

**Related documents:** [Grafana README](../../shared/grafana/README.md), [monitoring](MONITORING-ALERTING.md).

## VictoriaMetrics or VictoriaLogs Unavailable

**Symptoms:** Store health fails, Grafana datasource errors, Alloy remote write or log push fails, or host port is unreachable.

**Likely causes:** Container unhealthy, disk full, corrupt or permission-denied storage, resource exhaustion, network failure, or configuration error.

**Evidence to collect:** Store health and logs, `APPS_DATA` free space and permissions, Alloy delivery logs, container restart count, and port reachability.

**Diagnostic steps:** Check disk first, then store health and logs, then Alloy destination health, and finally query directly on the internal service address.

**Resolution:** Restore disk capacity or permissions, correct reviewed configuration, and restart the affected store before restarting Alloy. Preserve storage for diagnosis.

**Escalation:** Escalate suspected telemetry-store corruption or data loss.

**Related documents:** [VictoriaMetrics README](../../shared/victoriametrics/README.md), [VictoriaLogs README](../../shared/victorialogs/README.md).

## Disk Capacity Problems

**Symptoms:** Containers fail writes, databases become unhealthy, archives fail, images cannot build, or logs stop.

**Likely causes:** Large model or telemetry growth, backup accumulation, container images, logs, database growth, or unexpected file generation.

**Evidence to collect:** Host filesystem usage, `APPS_DATA` usage, backup-root usage, Docker disk usage, container restart errors, and growth trend without exposing file contents.

**Diagnostic steps:** Identify the mounted filesystem first, compare repository data, Docker data, backups, logs, databases, and model cache, then correlate with recent changes.

**Resolution:** Expand storage or apply an owner-approved retention and cleanup procedure. Do not run destructive pruning or delete database/model/backup data during diagnosis.

**Escalation:** Escalate when free-space thresholds threaten data integrity or backups.

**Related documents:** [Backup and restore](BACKUP-RESTORE.md), [monitoring](MONITORING-ALERTING.md).

## Failed Container Health Check

**Symptoms:** A service reports `unhealthy`, dependencies do not start, or traffic reaches a failing backend.

**Likely causes:** Slow startup, missing dependency, wrong internal port, command unavailable, credential/configuration error, resource exhaustion, or genuine application failure.

**Evidence to collect:** `docker compose ps`, health status history, recent logs, declared healthcheck command, startup duration, dependency status, and resource pressure.

**Diagnostic steps:** Compare health start period with observed startup, confirm the health command works in the container, then inspect application logs and dependencies.

**Resolution:** Correct a verified configuration or dependency issue, or adjust the health probe only through a reviewed implementation change. Restart after preserving diagnostics.

**Escalation:** Escalate repeated restart loops, host resource risk, or multiple failed services.

**Related documents:** [Runbook](RUNBOOK.md), [service inventory](SERVICE-INVENTORY.md), [test plan](../testing/TEST-001-platform-baseline-validation.md).
