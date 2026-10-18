---
project: ServiceHub
project_code: SVCHUB
document_type: RUNBOOK
document_id: RUNBOOK-ADR-010-PHASE-5
title: ADR-010 Phase 5 OCI Validation
version: "1.0"
status: Planned
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-18
updated: 2026-10-18
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

> **Status:** Planned. This runbook has not been executed and must be performed on the OCI host by the owner. Record timestamps, commands, redacted outputs, and evidence for every item.

## 1. Preserve current OCI state

1. Confirm the OCI target and SSH identity.
2. Run `git status --short`, `git branch --show-current`, `git rev-parse HEAD`, and `git remote -v`.
3. Preserve any dirty checkout as a patch outside the deployment path; never discard a `compose/mailsv.yml` modification or unrelated change.
4. Record `docker compose ps`, container IDs, image IDs, and current observability container logs without stopping or recreating anything.
5. Define rollback commit and image tags before changing state.

## 2. Synchronize and validate

6. Fetch the approved `adr-010` branch without force-pull, rebase, reset, clean, or stashing user changes.
7. Verify the checked-out commit matches the approved Forgejo revision.
8. Run `docker compose config --quiet`.
9. Build `obsvcevm`, `obsvcevlogs`, `obsvcealloy`, and `obsvcegrafana`.
10. Capture image digests and product versions.

## 3. Storage and ownership

11. Confirm `${APPS_DATA}/obsvce/victoriametrics`, `${APPS_DATA}/obsvce/victorialogs`, and `${APPS_DATA}/obsvce/grafana` exist with expected ownership and permissions.
12. Record free space, inode capacity, and read-only state.
13. Add the Alloy container runtime identity to `systemd-journal` using the host's actual GID. Do not reuse a value guessed in Git.
14. Confirm journal files and `/etc/machine-id` are readable by Alloy.

## 4. Start services in dependency order

15. Start VictoriaMetrics and record `/health`, build/version, and startup logs.
16. Start VictoriaLogs and record `/health`, build/version, and startup logs. Use host-side checks or Alloy; do not add a shell or curl to the image.
17. Start Alloy and record `/health`, configuration load, scrape status, remote-write status, and errors.
18. Start Grafana and record `/api/health`, datasource status, plugin version, provisioning logs, dashboard inventory, and alert inventory.

## 5. Validate telemetry

19. Query host CPU, memory, load, PSI, disk, network, and uptime metrics.
20. Query filesystem capacity, available/free bytes, inode capacity/utilization, and read-only state.
21. Query cAdvisor CPU, throttling, memory/working set/limits, network, filesystem I/O, process state, start time, last-seen, and OOM indicators.
22. Confirm selective journald ingestion for SSH, sudo, logind, kernel/OOM, Docker, systemd, storage, network, reboot/shutdown, and enabled firewall events.
23. Confirm Docker stdout/stderr ingestion and local Docker log rotation policy.
24. Query Traefik metrics, access logs, status codes, latency, and structured fields.
25. Verify GeoIP country, client IP structured metadata, city, and cardinality controls; confirm client IP is absent as a metric label.
26. Verify internal readiness probes and public HTTPS/TLS probes, including DNS, handshake, certificate validity, expiry, and duration.
27. Scrape Authentik server, worker, and applicable outpost metrics on port 9300; classify authentication, provider, OIDC, worker, outpost, and database errors.
28. Scrape oCIS proxy metrics on port 9205; verify requests, failures, duration, health, and build/version fields.
29. Configure the least-privilege PostgreSQL monitoring role outside Git, supply credentials through the approved mechanism, and verify availability, connections, transactions, locks, deadlocks, long transactions, size, cache, temporary data, and WAL indicators.
30. Provide the approved Confluence JMX exporter decision and version, deploy it only after owner approval, keep its endpoint internal, and verify JVM, GC, thread, request, database-pool, and latency metrics.

## 6. Validate interfaces

31. Load all eight ServiceHub dashboards and each Reference dashboard; record UIDs, panels, datasource resolution, and representative values.
32. Evaluate each provisioned alert, including firing, recovery, no-data, execution-error, group labels, and annotations.
33. Test notification delivery only after the owner selects and configures a contact point.
34. Execute VictoriaLogs troubleshooting queries from `docs/operations/LOG-TROUBLESHOOTING.md` and correct field assumptions with evidence.
35. Verify LiteLLM, `aiserv`, Stalwart, Bulwark, and `mailsv` are absent from metrics, logs, probes, dashboards, alerts, and troubleshooting examples.
36. Record VictoriaMetrics and VictoriaLogs ingestion rates, storage growth, and observed retention.
37. Test rollback using the pre-change commit/image evidence without deleting telemetry data.

## 7. Evidence requirements

For each item, record the command or UI action, UTC timestamp, commit/image/version, redacted output, screenshot or query result, pass/fail, and follow-up. Store implementation evidence in `docs/operations/MONITORING-ALERTING.md`; do not claim runtime verification until the output exists.
