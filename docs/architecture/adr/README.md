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
| ADR-001 | Use Docker Compose as the Orchestration Substrate | Accepted | 2026-10-03 | 2026-10-03 | |
| ADR-002 | Use Traefik as the Single HTTP Ingress | Accepted | 2026-10-03 | 2026-10-03 | |
| ADR-003 | Use PostgreSQL as Primary Database | Accepted | 2026-10-03 | 2026-10-03 | |
| ADR-004 | Use Authentik for Central Identity | Accepted | 2026-10-03 | 2026-10-03 | |
| ADR-005 | Use LiteLLM for AI Workload Routing | Accepted | 2026-10-03 | 2026-10-03 | |
| ADR-006 | Adopt oCIS with Local Filesystem Storage | Accepted | 2026-10-04 | 2026-10-04 | |
| ADR-007 | Adopt Dual-Target Backup and Disaster Recovery | Accepted | 2026-10-04 | 2026-10-04 | |
| ADR-008 | Standardise Service Naming, Storage Layout, Bind Mounts, and Environment Variables | Accepted | 2026-10-06 | 2026-10-04 | Partially superseded by ADR-009 (Open WebUI relocation) |
| ADR-009 | Rescope the OCI Deployment, Relocate AI Services to Local Infrastructure, and Harden Platform Boundaries | Accepted | 2026-10-08 | 2026-10-05 | Supersedes ADR-008 in part; defers observability to ADR-010 |
| ADR-010 | Collect OCI Logs and Integrate Service Telemetry with Oracle APM | Proposed | 2026-10-05 | 2026-10-05 | Split from ADR-009; pending owner decision |

Next available identifier: ADR-011.

## Relationship to other artifacts
RFC outcomes may produce ADRs; specifications and plans reference ADRs. Template: [../../templates/adr-template.md](../../templates/adr-template.md).

## Current scaffold state
ADR-001 through ADR-010 are recorded; next available identifier is ADR-011.
