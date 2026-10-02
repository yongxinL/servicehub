---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: RUNBOOK
title: ServiceHub Runbook
version: "1.0"
status: Draft
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-01
tags:
  - servicehub
  - operations
  - runbook
related_documents:
  - SERVICE-INVENTORY
  - TROUBLESHOOTING
  - BACKUP-RESTORE
---

# ServiceHub Runbook

## Prerequisites

- Docker 24+ and Compose 2.20+.
- Repository checkout with valid `.env`.
- `python3` and `openssl` for `scripts/setup.sh`.
- `git-crypt` when encrypted certificate material must be unlocked.
- Docker group access for the administrator.
- Read access to logs and `APPS_DATA`.
- Backup and escalation details before maintenance: `TBD`.

Confirm the working directory contains the root `docker-compose.yml` before running commands.

## Configuration Validation

```bash
docker compose config
```

Review interpolation errors and warnings. The output may resolve sensitive environment values, so do not paste it into issues or documentation.

For a compact service-name check used by the repository workflows:

```bash
docker compose config --services
```

## Start

Start the full default stack:

```bash
docker compose up -d
```

Start one service and its dependencies:

```bash
docker compose up -d depotservice
```

Rebuild one service after a configuration or image change:

```bash
docker compose up -d --build depotservice
```

## Stop

Stop containers without removing them:

```bash
docker compose stop
```

Remove containers while retaining bind-mounted data:

```bash
docker compose down
```

`docker compose down` does not delete the bind mounts under `APPS_DATA`, but confirm the target and backup before using any destructive maintenance command.

## Restart

Restart one service:

```bash
docker compose restart depotservice
```

Restart the identity server and worker:

```bash
docker compose restart authnservice authnworkers
```

Use the [service inventory](SERVICE-INVENTORY.md) to identify dependencies before restarting.

## Health Checks

```bash
docker compose ps
```

Check a specific service's declared health through Compose status:

```bash
docker compose ps depotservice
```

For routed services, combine container health with a redacted HTTPS request to the configured hostname. Health definitions are recorded in the [component catalogue](../architecture/COMPONENT-CATALOGUE.md).

## Log Access

Follow one service:

```bash
docker compose logs -f depotservice
```

Read recent logs:

```bash
docker compose logs --tail 200 depotservice
```

Container logs are also collected by Grafana Alloy into VictoriaLogs when the observability stack is healthy. Do not record credentials or private request data from logs.

## Service Dependency Awareness

- Start or verify `routetraefik` before Authentik, Forgejo, Confluence, Open WebUI, Grafana, and Stalwart as declared in Compose.
- Verify `dbsvcpgsqldb` before Authentik, Forgejo, LiteLLM, Confluence, and Stalwart.
- Complete one-shot initialisers before their dependent services.
- Keep `depotrunner` with `depotservice`; remote workflows depend on both.
- Traefik discovers new labelled containers automatically, but middleware and certificate files are read from repository configuration.

Compose conditions enforce some ordering, but full health and route validation remains required.

## Routine Maintenance

1. Record the current commit and service state.
2. Review pending changes and documentation impact.
3. Confirm backup availability when data or configuration changes.
4. Run `bash scripts/setup.sh` to merge newly added environment variables.
5. Validate `docker compose config`.
6. Rebuild only affected services.
7. Check health, logs, routes, and telemetry.
8. Update documentation and relevant indexes.

To update images explicitly, the root README documents:

```bash
docker compose pull && docker compose up -d
```

Treat this as a controlled maintenance action because mutable `latest` images may change.

## Upgrade Process

1. Confirm target, commit, change scope, and rollback limitation.
2. Take and verify a backup.
3. Review Compose, Dockerfile, environment, schema, and migration changes.
4. Merge or encode environment changes without exposing values.
5. Validate configuration.
6. Build and deploy affected services.
7. Check health, authentication, routes, data, metrics, and logs.
8. Record evidence and update documentation.

The Forgejo deployment workflow handles application services with `--no-deps`; foundational services are updated manually. See [deployment architecture](../architecture/DEPLOYMENT-ARCHITECTURE.md).

## Rollback

No rollback procedure is implemented or validated in the repository. Do not claim rollback capability.

**Proposed rollback sequence:**

1. Stop accepting the change where possible.
2. Restore or retain pre-change data according to the migration type.
3. Deploy the previous approved commit or image set using a reviewed procedure.
4. Restore configuration compatibility.
5. Validate health, data, routes, authentication, and telemetry.
6. Record outcome and residual risk.

The exact command sequence is `TBD` until tested.

## Escalation

Named escalation contacts and response targets are `TBD`.

Escalate immediately when:

- Data loss, corruption, or unauthorised access is suspected.
- A backup or restore may be incomplete.
- Production-wide outage or certificate failure occurs.
- Secrets or private keys may have been exposed.
- A proposed workaround could delete or overwrite persistent data.

Preserve logs and timestamps, avoid reproducing secrets, and link the relevant [troubleshooting](TROUBLESHOOTING.md) workflow.

## Emergency Considerations

- Treat local `.env`, git-crypt keys, ACME data, SSH keys, and repository secrets as sensitive.
- Prefer read-only diagnostics before restart or rebuild.
- Use break-glass accounts only through an approved procedure; the procedure is `TBD`.
- If Traefik is unavailable, do not publish additional application ports without security review.
- If recovery objectives are unknown, record them as `TBD` rather than guessing.

## Related Documents

- [Service inventory](SERVICE-INVENTORY.md)
- [Backup and restore](BACKUP-RESTORE.md)
- [Monitoring and alerting](MONITORING-ALERTING.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Test register](../testing/README.md)

