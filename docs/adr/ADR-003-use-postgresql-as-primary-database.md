---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-003
title: Use PostgreSQL as the Primary Relational Platform
version: "1.1"
status: Accepted
decision_basis: Inferred from current implementation
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-08
tags:
  - servicehub
  - architecture
  - postgresql
  - database
related_documents:
  - ARCHITECTURE
  - BACKUP-RESTORE
  - ADR-001
---

# ADR-003: Use PostgreSQL as the Primary Relational Platform

## Context

The default platform requires relational storage for Authentik, Forgejo, LiteLLM, Confluence, and Stalwart. MariaDB also exists for an optional WordPress path.

## Decision

Use PostgreSQL 16 as the primary relational platform for default ServiceHub workloads. Retain MariaDB only for the optional WordPress alternative.

## Decision Drivers

- One database service supports most default applications.
- Explicit database list supports first-boot creation.
- Logical dump workflow already targets PostgreSQL.
- Compose dependency conditions can wait for PostgreSQL health.

## Options Considered

1. PostgreSQL for all default workloads.
2. MariaDB for all workloads.
3. Separate database engines per application.
4. Embedded databases only.

## Rationale

All default database consumers in `compose/*.yml` connect to `dbsvcpgsqldb`. `env.example` states that MariaDB is not used by the default stack. The backup workflow performs `pg_dump` and `pg_dumpall` against PostgreSQL.

## Positive Consequences

- Consolidated default database administration.
- Transaction-consistent logical backup path.
- One health and dependency target for default services.
- Shared database-name configuration.

## Negative Consequences

- PostgreSQL is a shared dependency and single point of failure on the host.
- A shared SQL user may broaden credential impact.
- MariaDB remains as a second database engine for optional use.
- Database upgrades and restore procedures still require validation.

## Risks

- No database replication or failover in the repository.
- Full filesystem backup of live database files is only crash-consistent.
- Database credentials are shared across several services.
- Restore procedure documentation exists, but no executed restore or database integrity evidence is recorded.

## Implementation Evidence

- [compose/dbsvc.yml](../../compose/dbsvc.yml)
- [PostgreSQL image](../../shared/postgresql/Dockerfile)
- [PostgreSQL README](../../shared/postgresql/README.md)
- [backup workflow](../../.forgejo/workflows/71-backup.yml)
- Database environment settings in `compose/authn.yml`, `compose/depot.yml`, `compose/aiagn.yml`, `compose/wbapp.yml`, and `compose/poste.yml`

## Related Documents

- [Component catalogue](../architecture/COMPONENT-CATALOGUE.md)
- [Backup and restore](../operations/BACKUP-RESTORE.md)
- [Baseline test plan](../testing/TEST-001-platform-baseline-validation.md)

## Follow-up Actions

- Validate all PostgreSQL consumers and health dependencies.
- Execute and validate the documented PostgreSQL restore procedure.
- Decide whether credential separation is required.
