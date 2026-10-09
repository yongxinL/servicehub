# oCIS — ServiceHub Cloud Drive

> ownCloud Infinite Scale file synchronisation and sharing, authenticated by Authentik OIDC.

## Overview

[ownCloud Infinite Scale (oCIS)](https://doc.owncloud.com/ocis/8.2/) runs as the `webappocis` service in [`compose/webapp.yml`](../../compose/webapp.yml) and is built from [`shared/owncloud/Dockerfile`](../../shared/owncloud/Dockerfile) (`FROM owncloud/ocis:${IMAGE_TAG}`). It is routed through Traefik at `https://${CLOUD_DOMAIN}`, stores configuration and file data under `${APPS_DATA}/webapp/ocis`, and delegates sign-in to Authentik.

The build passes `CLOUD_TAG` to the Dockerfile as `IMAGE_TAG` and tags the result `webappocis:latest`. Its entrypoint initialises `${APPS_DATA}/webapp/ocis/config/ocis.yaml` only when it does not exist, then starts the supported single-container service set and persists configuration separately from file data.

oCIS does not use a ServiceHub PostgreSQL database in this implementation. Authentik stores identity and application state in PostgreSQL; oCIS stores its core state in its local configuration and data directories. See [ADR-006](../../docs/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md) for the persistence decision and implementation note.

## Service Details

| Detail | Value |
|---|---|
| Service name | `webappocis` |
| Initialiser | `webappocisinit` |
| Compose file | `compose/webapp.yml` |
| Image | `webappocis:latest` |
| Entrypoint | `/usr/local/bin/ocis-entrypoint` |
| Build context | `shared/owncloud/` |
| Base image | `owncloud/ocis:${CLOUD_TAG}` |
| Internal port | 9200 |
| Public route | `https://${CLOUD_DOMAIN}` |
| Authentication | Authentik OAuth 2.0 / OIDC |
| Configuration | `${APPS_DATA}/webapp/ocis/config` → `/etc/ocis` |
| File data | `${APPS_DATA}/webapp/ocis/data` → `/var/lib/ocis` |
| Health check | `curl -fsS http://localhost:9200/status.php` |
| Database | None for oCIS; Authentik uses ServiceHub PostgreSQL |

The oCIS image runs as UID/GID `1000:1000`. `webappocisinit` creates and corrects ownership on both bind-mounted directories before the main service starts.

## Configuration in `.env`

Set these values in `.env`; [`env.example`](../../env.example) contains the defaults and placeholders.

| Variable | Description |
|---|---|
| `CLOUD_DOMAIN` | Public oCIS hostname, default `drive.${DOMAIN_NAME}` |
| `CLOUD_TAG` | Pinned oCIS image tag, default `8.2.0` |
| `CLOUD_OIDC_ISSUER` | Authentik issuer for the oCIS application |
| `CLOUD_OIDC_CLIENT_ID` | Public client ID displayed by the Authentik provider |
| `CLOUD_INSECURE` | Set `true` only when Authentik uses a self-signed certificate |

Do not record the Authentik provider client secret in documentation. The browser client is configured as a public OIDC client and does not require a client secret.

## Authentik OIDC Setup

Perform this one-time setup before starting `webappocis`:

1. Open the Authentik administration interface at `https://${IDENTITY_DOMAIN}`.
2. Create an **OAuth2 / OpenID Provider** with these settings:
   - **Client type:** Public.
   - **Redirect URIs:**
     - `https://${CLOUD_DOMAIN}/oidc-callback.html`
     - `https://${CLOUD_DOMAIN}/oidc-silent-redirect.html`
     - `https://${CLOUD_DOMAIN}/`
   - **Scopes:** `openid`, `profile`, and `email`.
   - **Signing key:** an approved Authentik signing key.
3. Create an **Application** linked to that provider:
   - **Slug:** `ocis`.
   - **Launch URL:** `https://${CLOUD_DOMAIN}`.
4. Copy the provider client ID into `CLOUD_OIDC_CLIENT_ID`.
5. Confirm that `CLOUD_OIDC_ISSUER` matches the provider issuer. With slug `ocis`, the expected form is:

   ```text
   https://${IDENTITY_DOMAIN}/application/o/ocis/
   ```

6. Apply the `.env` changes and restart oCIS.

The oCIS router deliberately does **not** use Traefik forward auth. oCIS performs the OIDC authorization-code flow itself and provisions an oCIS account after the first successful Authentik sign-in.

## Start and Validate

Validate the Compose model first:

```bash
docker compose --env-file env.example config --quiet
```

Start the service:

```bash
docker compose up -d --build webappocis
```

For a first deployment where the bind-mount directories do not yet exist, the deployment workflow starts `webappocisinit` before `webappocis`. From a local shell, the explicit sequence is:

```bash
docker compose up -d webappocisinit
docker compose up -d --build webappocis
```

Check status:

```bash
docker compose ps webappocis
docker compose logs -f webappocis
curl -fsS "https://${CLOUD_DOMAIN}/status.php"
```

Open `https://${CLOUD_DOMAIN}` and verify:

- The login button redirects to Authentik.
- A test user can complete OIDC sign-in.
- The user is auto-provisioned in oCIS on first login.
- Sign-out returns to the expected oCIS or Authentik page.
- A file can be uploaded, downloaded, and synchronised.
- `/admin` or equivalent administrative access follows the approved role model.

These checks are required before the deployment is described as tested.

## Backup and Recovery

Both oCIS paths are beneath `APPS_DATA`, so the current weekly full archive includes them unless they are explicitly excluded. Preserve both directories together:

- `${APPS_DATA}/webapp/ocis/config`
- `${APPS_DATA}/webapp/ocis/data`

oCIS does not add a PostgreSQL dump. Its configuration and file paths are covered by the full-archive and configured dual-target transfer scope in [ADR-007](../../docs/adr/ADR-007-adopt-dual-target-backup-and-recovery.md). Repository configuration does not prove successful transfer or restore capability.

## Operations

```bash
# Restart oCIS
docker compose restart webappocis

# Follow logs
docker compose logs -f webappocis

# Validate Compose after changes
docker compose config --quiet
```

Upgrades must pin a tested `CLOUD_TAG`, back up both oCIS directories, and record compatibility and rollback evidence. Do not remove `${APPS_DATA}/webapp/ocis` during a routine restart.

## Security Notes

- Keep `CLOUD_INSECURE=false` when Authentik has a trusted certificate.
- Use a public OIDC client with PKCE; do not place a client secret in `.env`.
- Keep the oCIS route behind `secure-chain`; authentication belongs to oCIS and Authentik rather than Traefik forward auth.
- Disable public registration in Authentik and assign file-sharing permissions through the approved identity and group model.
- Validate external sharing, link passwords, retention, and administrative access before enabling them for sensitive records.

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](../../shared/owncloud/Dockerfile) | Image build (`FROM owncloud/ocis:${IMAGE_TAG}`) |
| [`entrypoint.sh`](../../shared/owncloud/entrypoint.sh) | Initialises a missing configuration file and starts `ocis server` |

## Related Documentation

- [ADR-006 Adopt oCIS with Local Filesystem Storage](../../docs/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md)
- [ADR-007 Adopt Dual-Target Backup and Disaster Recovery](../../docs/adr/ADR-007-adopt-dual-target-backup-and-recovery.md)
- [Authentik](authentik.md)
- [Traefik](traefik.md)
- [PostgreSQL](postgresql.md)
- [Backup and restore](../../docs/operations/BACKUP-RESTORE.md)
