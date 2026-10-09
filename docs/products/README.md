---
project: ServiceHub
project_code: SVCHUB
document_type: PRODUCT-INDEX
document_id: PRODUCT-INDEX
title: ServiceHub Product Guides Index
version: "1.1"
status: Active
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-09
updated: 2026-10-09
tags:
  - servicehub
  - products
  - index
related_documents:
  - HOME-001
  - OPS-INDEX
  - ARCHITECTURE
---

# ServiceHub Product Guides Index

Per-product build, configuration, and setup guides. Each guide covers the product's Compose service, environment variables, and product-specific operations. These guides were relocated from `shared/<product>/README.md` into the documentation set; the repository implementation remains the source of truth.

## Documents

- [Authentik](authentik.md) — IdP / SSO, LDAP directory, and OIDC provider.
- [Bulwark Webmail](bulwark.md) — JMAP webmail client for the email domain.
- [Confluence](confluence.md) — homepage / CMS (Data Center).
- [FastCRW](fastcrw.md) — optional web-search stack for Hermes Agent.
- [Forgejo](forgejo.md) — source control host and Actions runner.
- [Grafana](grafana.md) — dashboards for metrics and logs.
- [Hermes Agent](hermesagent.md) — single shared agent workspace and gateway.
- [LiteLLM Proxy](litellm.md) — unified LLM endpoint and complexity router.
- [llama.cpp Chat Inference](llamacpp.md) — local Gemma inference tier.
- [MariaDB](mariadb.md) — MySQL-compatible database.
- [oCIS](owncloud.md) — ownCloud Infinite Scale cloud drive.
- [Open WebUI](openwebui.md) — AI platform chat interface.
- [PostgreSQL](postgresql.md) — primary database.
- [Stalwart Mail Server](stalwart.md) — SMTP / IMAP / JMAP and web admin.
- [Traefik](traefik.md) — edge router and TLS termination.
- [VictoriaLogs](victorialogs.md) — log aggregation.
- [VictoriaMetrics](victoriametrics.md) — time-series metrics store.
- [WordPress](wordpress.md) — optional CMS alternative to Confluence.

## Safe Use

- Read the relevant product guide before changing configuration.
- Validate Compose configuration before starting or rebuilding.
- Back up data before upgrades or destructive maintenance.
- Do not paste secret values into commands, issues, test evidence, or documentation.
- Escalate to the project owner when recovery, security, or data-loss decisions are required.
