# Architecture Decision Records

## Purpose
Index of significant, durable technical decisions.

## Authority
This index is authoritative for ADR identity, allocation, location, status, supersession, and baseline. Each ADR is authoritative for its decision and rationale. Owning chapter: central manual 09.

## Artifact triggers
Technology or platform selection, data strategy, integration patterns, security architecture, deployment topology, cross-cutting conventions, or any decision costly to reverse.

## Naming and identifiers
`ADR-NNN-<kebab-title>.md`. Allocate the next number here when the ADR is created. Numbers are never reused.

## Status expectations
Proposed, Accepted, Rejected, Deprecated, Superseded. Accepted ADRs are immutable in meaning.

## Index

| ID | Title | Status | Updated | Baseline | Relations |
|---|---|---|---|---|---|
| [ADR-001](ADR-001-use-docker-compose.md) | Use Docker Compose as the Orchestration Substrate | Accepted | 2026-10-03 | 2026-10-03 | |
| [ADR-002](ADR-002-use-traefik-as-ingress.md) | Use Traefik as the Single HTTP Ingress | Accepted | 2026-10-03 | 2026-10-03 | |
| [ADR-003](ADR-003-use-postgresql-as-primary-database.md) | Use PostgreSQL as Primary Database | Accepted | 2026-10-03 | 2026-10-03 | |
| [ADR-004](ADR-004-use-authentik-for-central-identity.md) | Use Authentik for Central Identity | Accepted | 2026-10-03 | 2026-10-03 | |
| [ADR-005](ADR-005-use-litellm-for-ai-routing.md) | Use LiteLLM for AI Workload Routing | Accepted | 2026-10-03 | 2026-10-03 | |
| [ADR-006](ADR-006-adopt-ocis-with-local-filesystem-storage.md) | Adopt oCIS with Local Filesystem Storage | Accepted | 2026-10-04 | 2026-10-04 | |
| [ADR-007](ADR-007-adopt-dual-target-backup-and-recovery.md) | Adopt Dual-Target Backup and Disaster Recovery | Accepted | 2026-10-04 | 2026-10-04 | |
| [ADR-008](ADR-008-standardise-service-naming-storage-and-bind-mounts.md) | Standardise Service Naming, Storage Layout, Bind Mounts, and Environment Variables | Accepted | 2026-10-06 | 2026-10-04 | Partially superseded by ADR-009 (Open WebUI relocation) |
| [ADR-009](ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) | Rescope the OCI Deployment, Relocate AI Services to Local Infrastructure, and Harden Platform Boundaries | Accepted | 2026-10-17 | 2026-10-05 | Supersedes ADR-008 in part; partially superseded by ADR-010 for OCI observability scope |
| [ADR-010](ADR-010-establish-servicehub-observability-platform.md) | Establish the ServiceHub Observability Platform with Grafana, VictoriaMetrics, VictoriaLogs, Alloy, and Oracle APM | Accepted | 2026-10-17 | 2026-10-05 | Accepted; supersedes ADR-009's OCI-native-only observability decision in part and relevant ADR-008 collector mount restrictions |

Next available identifier: ADR-011.

## Relationship to other artifacts
RFC outcomes may produce ADRs; specifications and plans reference ADRs. Template: [../../templates/adr-template.md](../../templates/adr-template.md).

## Current scaffold state
ADR-001 through ADR-010 are recorded; next available identifier is ADR-011.
