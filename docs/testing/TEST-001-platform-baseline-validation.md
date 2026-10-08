---
project: ServiceHub
project_code: SVCHUB
document_type: TEST
document_id: TEST-001
title: Platform Baseline Validation
version: "1.1"
status: Not Executed
lifecycle_stage: Testing
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-08
tags:
  - servicehub
  - testing
  - validation
related_documents:
  - ARCHITECTURE
  - DEPLOYMENT-ARCHITECTURE
  - BACKUP-RESTORE
  - ADR-006
  - ADR-007
  - RELEASE-INDEX
---

# TEST-001: Platform Baseline Validation

## Execution Status

**Not Executed.** The repository contains workflow definitions and service health checks but no reliable report showing that this baseline was executed successfully.

This document is a test plan, not a test result.

## Test Context

- Environment: `TBD` — use staging unless the owner approves another target.
- Commit or tag: `TBD` at execution.
- Tester: `TBD`.
- Start and finish time: `TBD`.
- Data used: synthetic or approved test data only.
- Secret handling: never include secret values in results.

## Test Cases

| ID | Area | Procedure and expected result | Evidence required |
|---|---|---|---|
| TC-001 | Compose configuration | Run `docker compose config` from the repository root. Expect successful interpolation and no missing required input. | Command result with secret values redacted |
| TC-002 | Custom image builds | Build default services with `docker compose build`. Expect every build to complete or record an approved exception. | Build log and image list |
| TC-003 | Environment validation | Confirm required variable names are present and no placeholder required for the target remains. Do not record values. | Redacted checklist |
| TC-004 | Container health | Inspect `docker compose ps`. Expect declared health checks to reach healthy within configured start periods. | Status output and timestamps |
| TC-005 | Dependency ordering | Start in dependency order from a controlled state. Expect initialisers to complete and dependent services to wait for stated conditions. | Start logs |
| TC-006 | Network isolation | Confirm databases and unrouted services are not reachable through Traefik or unintended host ports. | Port and route evidence |
| TC-007 | HTTP redirect | Request port 80 for a routed hostname. Expect redirect to HTTPS. | HTTP response headers |
| TC-008 | TLS | Request each intended HTTPS route. Expect a trusted certificate in production mode or the approved self-signed result in staging. | Certificate chain and browser or CLI result |
| TC-009 | Authentik authentication | Complete login through Authentik using an approved test account. Expect successful authentication without exposing credentials. | Redacted result |
| TC-010 | Traefik forward authentication | Access Grafana unauthenticated and authenticated. Expect redirect to Authentik and authorised access after login. | Redirect and access evidence |
| TC-011 | Forgejo and runner | Verify Forgejo health, registration controls, `depotrunner` health, the `ssh-deploy` label, backup-tool availability, and minimal deployment and backup workflows. The repository uses Forgejo Actions, not a `.gitea` workflow directory. | Service and workflow logs |
| TC-012 | Deployment | Dispatch a controlled staging deployment for one low-impact application service. Expect checkout, environment merge, build, and `--no-deps` deployment to complete. | Workflow log |
| TC-013 | Rollback | Restore the previous approved version using a documented method. Expect services and data to remain valid. | Rollback record; procedure currently TBD |
| TC-014 | PostgreSQL | Confirm all default PostgreSQL consumers connect, health is healthy, and data persists across a controlled restart. | Query and restart evidence |
| TC-015 | MariaDB | Confirm MariaDB health and, if optional WordPress is enabled, its database connectivity. Do not imply WordPress is default. | Health and optional service evidence |
| TC-016 | Local AI inference | Call the configured local endpoint through LiteLLM. Expect a valid response and local health before and after. | Redacted request class and response status |
| TC-017 | Cloud AI routing | Send an approved non-sensitive cloud-tagged request. Expect the configured cloud route to respond without recording credentials. | Routing log and status |
| TC-018 | Privacy-sensitive routing | Send an approved privacy-tagged test request. Expect local routing and no fallback to cloud. | Smart-router log |
| TC-019 | Context-window fallback | Send a controlled input that exceeds the configured local context path. Expect escalation according to LiteLLM configuration. | Routing and response evidence |
| TC-020 | Metrics | Confirm host, container, Traefik, and LiteLLM metrics appear in VictoriaMetrics. | Query results |
| TC-021 | Logs | Generate controlled logs and confirm they appear in VictoriaLogs with expected labels. | Query results |
| TC-022 | Dashboards | Open provisioned Grafana dashboards and confirm data sources return data. | Dashboard evidence |
| TC-023 | Backup database | Dispatch a database backup in staging. Expect per-database dumps, globals dump, archive creation, permissions, and retention input validation. | Backup manifest and workflow log |
| TC-024 | Backup full archive | Dispatch a full backup when approved. Expect an `APPS_DATA` archive and recorded exclusions. | Archive manifest and workflow log |
| TC-025 | Restore | Restore database dumps and filesystem data from each accepted target into isolated environments, then validate services. | Restore steps, duration, integrity checks, and service results |
| TC-026 | oCIS cloud drive | Confirm both oCIS paths persist across a controlled restart; complete Authentik OIDC sign-in and sign-out; verify account provisioning, upload, download, encoded WebDAV paths, and sharing controls. | Redacted OIDC result, service logs, file checks, and persistence evidence |
| TC-027 | Dual-target backup | Dispatch a controlled backup and expect an Rclone destination comparison for each enabled target and all configured retention operations to succeed without exposing target locations or retention values. | Redacted workflow log, artifact manifest, and integrity results |

## Pass Criteria

- All applicable cases pass or have an explicitly approved deviation.
- No secret, private key, recovery material, production hostname, or personal data appears in evidence.
- Backup restore is tested, not inferred from backup creation.
- Rollback evidence exists before a release claims rollback capability.
- Findings are linked to incidents, ADRs, RFCs, or phase follow-up.

## Execution Record

| Field | Value |
|---|---|
| Environment | TBD |
| Commit | TBD |
| Executed by | TBD |
| Executed at | TBD |
| Overall result | Not Executed |
| Evidence location | TBD |
| Deviations | TBD |

## Related Documents

- [Architecture](../architecture/ARCHITECTURE.md)
- [Runbook](../operations/RUNBOOK.md)
- [Backup and restore](../operations/BACKUP-RESTORE.md)
- [Release governance](../releases/README.md)
