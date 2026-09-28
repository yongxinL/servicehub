# Stalwart Mail Server — ServiceHub

> All-in-one mail & collaboration server: SMTP, JMAP, IMAP, CalDAV, CardDAV and WebDAV in a single binary. Backed by PostgreSQL, with accounts served from Authentik's LDAP directory.

## Overview

[Stalwart](https://github.com/stalwartlabs/stalwart) is the email server of the ServiceHub email domain (`poste`). It handles server-to-server and submission SMTP, IMAP and JMAP, and serves the web admin UI and API over HTTP. Bulwark webmail ([`../bulwark/README.md`](../bulwark/README.md)) talks to Stalwart via JMAP. The service is defined by `posteservice` in [`compose/poste.yml`](../../compose/poste.yml) and built from [`Dockerfile`](Dockerfile) (`FROM stalwartlabs/stalwart:${IMAGE_TAG}`).

## Service details

| Detail | Value |
|---|---|
| Service name | `posteservice` |
| Image tag | `v0.16` (build arg `IMAGE_TAG`) |
| Web admin / API / JMAP (HTTP) | 8080, routed by Traefik at `https://${EMAIL_HOST}` |
| SMTP server-to-server, STARTTLS | 25 (published to the host) |
| SMTP submission, implicit TLS | 465 (published to the host) |
| SMTP submission, STARTTLS | 587 (published to the host) |
| IMAP, implicit TLS | 993 (published to the host) |
| Optional listeners | 110, 143, 995, 4190 (commented out in the compose file) |
| Health check | `curl -fsS http://localhost:8080/healthz` every 30 s |
| Depends on | `routetraefik` (healthy) — Traefik must issue the public certificate first; `dbsvcpgsqldb` (healthy) — the PostgreSQL data store |
| Depended on by | `postewebmail` (healthy) |
| Data persistence | `${APPS_DATA}/platform/mailbox` (mounted at `/var/lib/stalwart`; TLS key material + runtime state — mail data itself lives in PostgreSQL) |
| Certificates | `${APPS_DATA}/certs` (mounted read-only at `/letsencrypt`) |

## Storage: PostgreSQL backend

Stalwart keeps its whole dataset (metadata, indexes, message blobs, FTS) in one **data store**, selected by a single `DataStore` object in `config.json`. This deployment uses the `PostgreSql` variant against the shared stack database:

| Setting | Value |
|---|---|
| Host / port | `${PGRSQL_HOST}:${PGRSQL_PORT}` (`dbsvcpgsqldb:5432`) |
| Database | `${POSTE_DBNAME}` (`svchubmboxdb`) — created by the PostgreSQL init script on first start |
| Credentials | `${SQLDB_USER}` / `${SQLDB_PASS}` (shared stack superuser) |

[`config.json`](config.json) is a template with `STALWART_PG_*` placeholders. [`entrypoint.sh`](entrypoint.sh) renders the real `/etc/stalwart/config.json` from it on **every start** (host, port, database, username, password and pool size), so credentials can rotate without a rebuild.

> The datastore location is the only setting Stalwart cannot change through its API (the API is served out of the datastore) — hence the template + render approach instead of runtime provisioning.

### Fallback administrator

The entrypoint exports `STALWART_RECOVERY_ADMIN=${STALWART_ADMIN_USER}:${STALWART_ADMIN_PASS}` (when `STALWART_ADMIN_PASS` is non-empty). Because a rendered `config.json` is always present, Stalwart never enters bootstrap mode and never prints a one-time temporary password — this pinned recovery account is the way in at `https://${EMAIL_HOST}/admin`, and it keeps working even if the LDAP directory (Authentik) is down. Leave `STALWART_ADMIN_PASS` empty to disable the fallback.

### Switching an existing installation from SQLite

PostgreSQL is the config for **new installs**. If `${APPS_DATA}/platform/mailbox` already holds a SQLite dataset, migrate instead of switching cold:

```bash
docker compose stop posteservice

# 1. Export the SQLite store (server stopped; uses a throwaway SQLite config
#    because the rendered config.json now points at PostgreSQL)
docker compose run --rm --entrypoint sh posteservice -c '
  printf "{\"@type\":\"Sqlite\",\"path\":\"/var/lib/stalwart/sqlite\",\"poolMaxConnections\":10}" > /tmp/sqlite.json
  /usr/local/bin/stalwart --config /tmp/sqlite.json --export /var/lib/stalwart/export'

# 2. Import into PostgreSQL (entrypoint renders the PostgreSQL config.json)
docker compose run --rm posteservice --import /var/lib/stalwart/export

docker compose start posteservice
```

The export directory lives on the `platform/mailbox` volume so both steps see it. See upstream [migration](https://stalw.art/docs/management/maintenance/migration) for details. Keep the SQLite file until you have verified the import.

## Directory: Authentik LDAP (SSO)

Mail accounts and credentials come from Authentik over LDAP, so users exist once in Authentik and log into the webmail (via OIDC) and IMAP/SMTP with the same identity. The Authentik side (see [`../authentik/README.md`](../authentik/README.md) for the full walkthrough):

1. An **application + LDAP provider** — keep the default Base DN `dc=ldap,dc=goauthentik,dc=io`; users live under `ou=users,<base DN>` and expose `cn` (username), `mail` and `memberOf`, with `objectClass` = `user` / `organizationalPerson` / `goauthentik.io/ldap/user`.
2. A **service account** user (e.g. `stalwart-ldap`) with the **Search full LDAP directory** permission (role assigned on the provider's *Permissions* tab).
3. A **managed LDAP outpost** — the embedded outpost only serves Proxy providers, so create one explicitly under **Applications → Outposts** (type *LDAP*), then edit its config and set **Docker network** to `servicehub_subnet` so the outpost container lands on the same network as `posteservice`. It listens internally on port `3389` (plain LDAP) and `6636` (LDAPS).

Then create the directory in Stalwart (admin UI → **Settings → Authentication → Directories → Create**, type *LDAP*) and fill in:

| Stalwart field | Value |
|---|---|
| `url` | `ldap://ak-outpost-<outpost name>:3389` — the managed LDAP outpost container on the `subnet` network |
| `bindDn` | `cn=stalwart-ldap,ou=users,dc=ldap,dc=goauthentik,dc=io` — the Authentik service account DN (default Base DN) |
| `bindSecret` | The service account's Authentik password (inline value, or an env var reference) |
| `filterLogin` | `(&(objectClass=user)(mail=?))` — **must be overridden**: Stalwart's default filter matches `objectClass=inetOrgPerson`, which Authentik does not expose |
| `filterMailbox` | `(&(objectClass=user)(\|(mail=?)(mailAlias=?)))` — same override; `mailAlias` only matches when the custom attribute is set |
| `bindAuthentication` | `true` (default) — Stalwart searches for the user DN with the service account, then binds **as the user** with the supplied password; no hash comparison, so nothing to sync |
| `attrSecretChanged` | `pwdChangeTime` (default) — invalidates cached OAuth tokens after LDAP password changes |

> User bind authentication (`bindAuthentication: true`) means Stalwart never reads password hashes: login validates by binding to Authentik's outpost as the user. The service-account bind is still required for non-authentication lookups (address/domain validation, account metadata).

Finally, **bind the mail domain to the directory** (Stalwart admin → **Settings → Domains** → the domain served at `${EMAIL_HOST}`, set its directory to the LDAP directory). Domains carry a `directoryId`; an unset (`null`) value means the internal directory, so accounts on unbound domains keep using local passwords — without this step the LDAP directory is created but never consulted.

Verify from the host (the outpost maps host ports `389`/`636` by default unless *Map ports* was unticked):

```bash
ldapsearch -H ldap://localhost:389 \
  -D "cn=stalwart-ldap,ou=users,dc=ldap,dc=goauthentik,dc=io" -W \
  -b "dc=ldap,dc=goauthentik,dc=io" "(objectClass=user)"
```

### Passwords & clients

- With LDAP user-bind authentication, local password changes from the webmail are **not possible** (Stalwart doesn't own the hash) — users change their password in Authentik. Per-device **app passwords** are supported on the Authentik side (enable *User database + app passwords* on the LDAP provider's Bind Flow password stage) and bind with the same DN.
- Because the mail domain is bound to the LDAP directory, **all accounts on it authenticate through Authentik** — including technical accounts like the stack sender `servicehub@${EMAIL_HOST}` (create it as an Authentik service account with its email set, see the walkthrough). Accounts on domains *not* bound to the directory keep using Stalwart's internal directory with local passwords.

## Traefik routing

Incoming HTTPS requests for `${EMAIL_HOST}` are routed to the internal HTTP port 8080 by Traefik, which terminates TLS. The router has an IP allow-list middleware (`posteservice-whitelist`) built from `${TRUSTED_IP}`, so the web admin UI is only reachable from trusted networks.

## TLS certificates

Certificates come from the shared Traefik ACME store — Stalwart does not run its own ACME client:

1. On first boot, before any public certificate exists, [`entrypoint.sh`](entrypoint.sh) generates a 2-day bootstrap self-signed certificate for `${MAIL_DOMAIN}` so the server can start.
2. [`acme-export.sh`](acme-export.sh) runs as a background watcher: every `${CERT_CHECK_INTERVAL}` seconds (and on `acme.json` changes via `inotifywait`) it:
    - extracts the fullchain and key for `${MAIL_DOMAIN}` from `/letsencrypt/acme.json` under the `${CERTRESOLVER}` resolver,
    - validates them with `openssl` and checks cert/key match,
    - on change, installs them into `/var/lib/stalwart/tls/` and restarts the server.

This mirrors how the deploy workflow restores `acme.json` from the `*_B64ENC_ACME` Forgejo Actions secret.

## Configuration (env)

| Variable | Purpose |
|---|---|
| `TIME_ZONE` | Container timezone |
| `EMAIL_HOST` | Mail server hostname; container `hostname`, Stalwart `MAIL_DOMAIN` and public URL |
| `CERTRESOLVER` | Which key of `acme.json` to read (`letsencrypt` or empty for self-signed staging) |
| `CERT_CHECK_INTERVAL` | Certificate re-check interval (default `86400`) |
| `POSTE_DBNAME` | PostgreSQL database name (must be in `PGRSQL_DBLIST`, created on first PostgreSQL start) |
| `PGRSQL_HOST` / `PGRSQL_PORT` | PostgreSQL connection target (`dbsvcpgsqldb:5432`) |
| `SQLDB_USER` / `SQLDB_PASS` | PostgreSQL credentials |
| `STALWART_ADMIN_USER` / `STALWART_ADMIN_PASS` | Fallback administrator, mapped to `STALWART_RECOVERY_ADMIN` (pass generated by `setup.sh`; empty disables) |

Directory settings (LDAP URL, bind DN/secret, filters) are applied once through the admin UI and stored in the PostgreSQL data store — they survive restarts and are backed up with the database.

## Data & persistence

| Container path | Host path | Purpose |
|---|---|---|
| `/var/lib/stalwart` | `${APPS_DATA}/platform/mailbox` | TLS key material (`tls/`) and runtime state (mail data lives in PostgreSQL) |
| PostgreSQL database | `${APPS_DATA}/databases/pgsqldb` (via `dbsvcpgsqldb`) | All mail data: accounts metadata, messages, indexes, FTS |
| `/letsencrypt` | `${APPS_DATA}/certs` | Traefik's shared `acme.json` (read-only `acme-export.sh`) |

## First boot

1. Add `${POSTE_DBNAME}` to `PGRSQL_DBLIST` if not already present, then bring up the database and the server:

    ```bash
    docker compose up -d posteservice
    ```

2. Open `https://${EMAIL_HOST}/admin` (from a trusted IP) and sign in with `${STALWART_ADMIN_USER}` / `${STALWART_ADMIN_PASS}` — the recovery admin.

3. Configure the Authentik LDAP directory (next section); the stack's own sender account `${EMAIL_USER}` is created as an Authentik service account.

For external clients to reach ports 25/465/587/993, DNS `MX`/`A` records for `${EMAIL_HOST}` must point at the host. Other stack components send mail using `${EMAIL_USER}` / `${EMAIL_PASS}` over port `${EMAIL_PORT}` (see [Root README — Email](../../README.md#configuration)).

## Initial provisioning walkthrough

PostgreSQL holds everything, so the fastest path is: first `docker compose up -d posteservice` boots straight into the admin UI with the recovery admin, provision the directory + accounts, then flip Bulwark's OIDC vars and deploy. Complete steps, in order:

1. **Database** — `${POSTE_DBNAME}` in `PGRSQL_DBLIST`; `docker compose up -d dbsvcpgsqldb` creates it on first start.
2. **Stalwart** — `docker compose up -d posteservice`; sign in at `https://${EMAIL_HOST}/admin` with `${STALWART_ADMIN_USER}` / `${STALWART_ADMIN_PASS}` (recovery admin).
3. **LDAP provider in Authentik** — Application `stalwart-mail` with provider type **LDAP Provider** (Base DN default `dc=ldap,dc=goauthentik,dc=io`).
4. **LDAP service account in Authentik** — Directory → Users → New User `stalwart-ldap`; set a password under Recovery. Create a role `LDAP search` with the **Search full LDAP directory** permission, add the service account to it, and assign the role to the provider under its **Permissions** tab.
5. **LDAP outpost in Authentik** — **Applications → Outposts → Create Outpost**, type **LDAP**, integration **Docker**, applications: `stalwart-mail`; edit the outpost config and set **Docker network** to `servicehub_subnet`. The outpost container is named after the outpost (`ak-outpost-<name>`) and listens on `3389`/`6636` — note it also maps host ports `389`/`636` unless you untick *Map ports*. Verify with the `ldapsearch` command in the [directory section](#directory-authentik-ldap-sso).
6. **Point Stalwart at the outpost** — Stalwart admin → **Settings → Authentication → Directories → Create** (LDAP), using the values from the [directory table](#directory-authentik-ldap-sso) above. Then **Settings → Domains** → bind the mail domain to the new directory (`directoryId`).
7. **Technical sender account in Authentik** — since the mail domain is bound to LDAP, create `servicehub@${EMAIL_HOST}` as an Authentik service account with that address as its **email**; `${EMAIL_PASS}` is the account's password. Stack components send with `${EMAIL_USER}` / `${EMAIL_PASS}` on port `${EMAIL_PORT}` (see [Root README — Email](../../README.md#configuration)).
8. **Mailboxes for users** — for LDAP-backed users authentication needs no extra setup; create the mailbox in Stalwart (matching the user's `mail` attribute) to assign quota and groups. Verify a login with the user's **email + Authentik password** from an IMAP/JMAP client or Bulwark's password form.
9. **OIDC for Bulwark** — create an OAuth2/OIDC provider application in Authentik for `${WEBMAIL_DOMAIN}` with redirect URI `https://${WEBMAIL_DOMAIN}/auth/callback`, copy client id/secret into `.env` (`WEBMAIL_OIDC_*`), then `docker compose up -d postewebmail`. See [Bulwark — SSO setup](../bulwark/README.md#sso-setup-authentik-oidc).

## Operations

```bash
# Start / restart
docker compose up -d posteservice

# Follow logs
docker compose logs -f posteservice

# Inspect the exported certificate state
ls -l ${APPS_DATA}/platform/mailbox/tls/

# Inspect Stalwart's PostgreSQL footprint
docker compose exec dbsvcpgsqldb psql -U "${SQLDB_USER}" -d "${POSTE_DBNAME}" -c "\dt"
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build — upstream image + curl/jq/inotify-tools for the cert watch tooling |
| [`config.json`](config.json) | **Template** rendered by the entrypoint into `/etc/stalwart/config.json` (PostgreSQL `DataStore`) |
| [`entrypoint.sh`](entrypoint.sh) | Renders the DB config, pins the recovery admin, bootstraps certs, drops privileges, starts the export watcher |
| [`acme-export.sh`](acme-export.sh) | Extracts and installs the public certificate from Traefik's `acme.json` |

## See also

- [Bulwark Webmail](../bulwark/README.md) — JMAP webmail client for this server (Authentik OIDC SSO)
- [Authentik](../authentik/README.md) — IdP; LDAP outpost + OIDC provider live here
- [PostgreSQL](../postgresql/README.md) — the shared database host (`dbsvcpgsqldb`)
- [Traefik](../traefik/README.md) — edge routing and TLS termination
- [Root README — Email stack](../../README.md#email-stack-poste)
