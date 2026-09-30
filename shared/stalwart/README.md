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
| Health check | `curl -fsS -H "X-Forwarded-For: 127.0.0.1" http://localhost:8080/healthz/live` every 30 s |
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

[`entrypoint.sh`](entrypoint.sh) writes `/etc/stalwart/config.json` with `jq` on **every start** from the `STALWART_DB_*` environment variables (host, port, database, username and pool size; the password is referenced as a `STALWART_DB_PASSWORD` environment-variable secret, so it never lands on disk), so credentials can rotate without a rebuild.

> The datastore location is the only setting Stalwart cannot change through its API (the API is served out of the datastore) — hence the render approach instead of runtime provisioning.

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

### Database management (create / delete / backup / restore)

All mail data (accounts, messages, indexes, blobs) lives in `${POSTE_DBNAME}` (`svchubmboxdb`); the `${APPS_DATA}/platform/mailbox` volume holds only TLS material and runtime state. Run these from the deploy directory on the host.

**Create** — keep `${POSTE_DBNAME}` in `PGRSQL_DBLIST` for new installs ([first boot](#first-boot)). The init script only runs on an empty data directory, so on an existing cluster create the database manually; Stalwart creates its schema in the empty database on the next start:

```bash
docker compose exec dbsvcpgsqldb psql -U "${SQLDB_USER}" -d postgres \
  -c "CREATE DATABASE \"${POSTE_DBNAME}\";"
docker compose up -d posteservice
```

**Delete** — stop the mail service first, then drop the database; this destroys the whole dataset and is irreversible:

```bash
docker compose stop posteservice
docker compose exec dbsvcpgsqldb psql -U "${SQLDB_USER}" -d postgres \
  -c "DROP DATABASE IF EXISTS \"${POSTE_DBNAME}\";"
```

To start over, create the database again and `docker compose start posteservice`, then re-run the [initial provisioning walkthrough](#initial-provisioning-walkthrough). Delete `${APPS_DATA}/platform/mailbox` too if the TLS material and runtime state should go as well.

**Backup** — `pg_dump` takes a transaction-consistent snapshot and is safe while Stalwart is serving mail (unlike copying the PostgreSQL data directory):

```bash
docker compose exec -T dbsvcpgsqldb pg_dump -U "${SQLDB_USER}" -Fc "${POSTE_DBNAME}" \
  > "poste-$(date +%F).dump"
```

`-Fc` is the compressed custom format used by `pg_restore` (selective/parallel restore); for a plain-SQL dump use `-Fp | gzip > poste-$(date +%F).sql.gz` instead. Copy the dump off the server — the scheduled [Forgejo backup workflow](../../README.md#data-backups-forgejo-actions) also dumps every database daily (kept 6 months) and archives `APPS_DATA` weekly, so this section is the manual path.

**Restore** — stop Stalwart (no writers), recreate the database, import the dump and start again:

```bash
docker compose stop posteservice
docker compose exec -T dbsvcpgsqldb psql -U "${SQLDB_USER}" -d postgres \
  -c "DROP DATABASE IF EXISTS \"${POSTE_DBNAME}\";" \
  -c "CREATE DATABASE \"${POSTE_DBNAME}\";"
docker compose exec -T dbsvcpgsqldb pg_restore -U "${SQLDB_USER}" -d "${POSTE_DBNAME}" --no-owner \
  < poste-YYYY-MM-DD.dump
docker compose start posteservice
```

For a `.sql.gz` dump, pipe it into `psql` instead: `gunzip -c poste-YYYY-MM-DD.sql.gz | docker compose exec -T dbsvcpgsqldb psql -U "${SQLDB_USER}" -d "${POSTE_DBNAME}"`. Verify with `docker compose exec dbsvcpgsqldb psql -U "${SQLDB_USER}" -d "${POSTE_DBNAME}" -c '\dt'` and a test login; the fallback admin at `https://${EMAIL_HOST}/admin` works even if the LDAP directory is down.

> `-T` disables TTY allocation so the binary dump streams cleanly through the redirect; the `< dump` and `gunzip -c` pipes run in the host shell, not the container.

## Directory: Authentik LDAP (SSO)

Mail accounts and credentials come from Authentik over LDAP, so users exist once in Authentik and log into the webmail (password form — see [Bulwark — SSO/OIDC](../bulwark/README.md#sso--oidc-not-used) for why OIDC SSO is not used with an LDAP directory) and IMAP/SMTP with the same identity. The integration spans both sides: an Authentik **application + LDAP provider**, a **service account** used for lookups, and a **managed LDAP outpost** — then the Stalwart **LDAP directory** that binds against the outpost, and the **domain binding** that activates it. All of it lives in this section.

Field names below are for Authentik `2026.8` (`AUTHN_TAG`); older versions label **Bind Flow** as *Authentication flow*.

### Authentik: application and LDAP provider

**Applications → Applications → New Application** — set a name/slug (e.g. `stalwart-mail`), **Next**, provider type **LDAP Provider**, **Next**, then fill in the provider form:

| UI field (2026.8) | Property | Value for this stack |
|---|---|---|
| Provider Name | `name` | `stalwart-mail` |
| Bind Mode | `bindMode` | *Cached binding* (form default) or *Direct binding* — see the mode note below |
| Search Mode | `searchMode` | *Cached querying* (form default; the outpost holds users/groups in memory and refreshes every 5 min) or *Direct querying* (always fresh, slower) |
| Code-based MFA Support | `mfaSupport` | on (default) — clients may append `;TOTP` to the password (`password;123456`) for Duo/TOTP/static authenticators; WebAuthn and SMS are unsupported by LDAP. Leave it on only if every LDAP-bind user has a supported authenticator, otherwise a password containing `;` can be rejected. |
| Bind Flow | `authorizationFlow` | `default-authentication-flow` (brand default), required — the Authentication-designation flow evaluated for bind requests (in *Cached binding* mode, once per session). Despite the label, the LDAP form stores it in the provider's `authorization_flow` field (the form's own comment: "we're using the authorization field to store the authentication information"). It must be a flow that can authenticate directory binds — a Source flow like `default-source-authentication` fails with `Flow does not apply to current user`. |
| Unbind Flow | `invalidationFlow` | `default-invalidation-flow` (brand default), required — the Invalidation-designation flow executed on unbind/logout. |
| Base DN | `baseDn` | `dc=ldap,dc=goauthentik,dc=io` (Authentik's default) or a custom DN — users are served under `ou=users,<base DN>`, groups under `ou=groups,<base DN>`. Must be unique per LDAP provider; Stalwart's `baseDn`/`bindDn` and the `ldapsearch` commands must use the same value. |
| Certificate / TLS Server Name | `certificate` / `tlsServerName` | leave empty — these enable LDAPS/StartTLS; Stalwart talks plain LDAP to the outpost over the shared Docker network. |
| UID Start Number / GID Start Number | `uidStartNumber` / `gidStartNumber` | defaults `2000` / `4000` — POSIX numbering for `uidNumber`/`gidNumber`, irrelevant to mail clients. |

Click **Submit**: the application and provider are created together.

> **Bind/Search mode:** the 2026.8 form preselects **Cached binding** and **Cached querying**. Cached binding executes the bind flow once and keeps the result (success **and** failure) in outpost memory for the session duration — password changes and session revocation do not invalidate the entry; only session expiry or `docker restart ak-outpost-<outpost name>` does. Use **Direct binding** if every bind should re-check the current credentials. Cached querying is fine here — directory data is at most 5 minutes stale.

### Authentik: service account, role and permissions

1. **Service account user** — Directory → Users → **New User** (e.g. `stalwart-ldap`); open the user → **Recovery** → **Set password**. The bind DN is `cn=<username>,ou=users,<base DN>` (e.g. `cn=stalwart-ldap,ou=users,dc=ldap,dc=goauthentik,dc=io`).
2. **Role** — Directory → Roles → **New Role** (e.g. `LDAP search`). Authentik ships no ready-made role for this, and the provider's *Permissions* tab only lists roles that already exist — it neither creates nor owns a role. Create a dedicated one: reusing an existing role grants the provider's search permission to every member of that role. Then open the role → **Users** tab → **Add Existing User** → select the service account → **Assign**. (If you already have a role holding the permission, e.g. for another LDAP provider, you can reuse it instead of creating a new one.)
3. **Search full LDAP directory** — two paths with a different scope; the first is recommended:
    - **Object permission (provider-scoped)** — Applications → Providers → open the LDAP provider → **Permissions** tab → **Assign Role Object Permission** → select `LDAP search` → enable **Search full LDAP directory** → **Assign Role Object Permission**. Affects only this provider.
    - **Global permission (role-scoped)** — Directory → Roles → `LDAP search` → **Permissions** tab → **Assigned global permissions** → add **Search full LDAP directory**. Affects every LDAP provider; the user still needs access to each provider's application.

    Without it a bound user can only see their own entry and the groups they belong to. The service account needs full search so Stalwart can resolve accounts (address/domain validation, metadata); ordinary mail users need nothing beyond application access.
4. **Application access** — everyone who binds must be allowed on the LDAP application: the service account *and* every mail user, since mail logins bind as the user. With no bindings the application is open to all users (`core_default_app_access` allows by default), so this only matters once you add bindings — then they must pass for both, or the outpost logs `50 insufficientAccessRights / Access denied for user`.

### Authentik: outpost

Applications → Outposts → **New Outpost**: type **LDAP**, integration **Docker** (the local Docker-socket integration is used by `authnworkers`), applications: the LDAP application above. Then edit the outpost and set **Docker network** to `servicehub_subnet` — without it the outpost container lands on the default bridge and Stalwart cannot reach it. The container is named after the outpost (`ak-outpost-<name>`) and listens on `3389` (LDAP) / `6636` (LDAPS); with *Map ports* on (default) it also binds host ports `389`/`636`.

### Stalwart: LDAP directory

Create the directory in Stalwart. In the v0.16 admin UI the path is **Settings → Authentication → Directories → Create directory** (the form's `Directory type` selector is the `@type` discriminator); pick *LDAP* and fill in:

| UI label (v0.16) | Property | Value |
|---|---|---|
| Description | `description` | Short name, e.g. `Authentik LDAP` |
| Server URL | `url` | `ldap://ak-outpost-<outpost name>:3389` — the managed LDAP outpost container on the `subnet` network |
| Base DN | `baseDn` | `dc=ldap,dc=goauthentik,dc=io` — Authentik's default Base DN, must match the provider (a custom DN works too — see the note below) |
| Bind DN | `bindDn` | `cn=stalwart-ldap,ou=users,dc=ldap,dc=goauthentik,dc=io` — the Authentik service account DN (`cn=<username>,ou=users,<base DN>`) |
| Bind Secret | `bindSecret` | The service account's Authentik password (choose *Value*, or an *Environment variable* / *File* reference) |
| Use Bind Authentication | `bindAuthentication` | on (default) — Stalwart searches for the user DN with the service account, then binds **as the user** with the supplied password; no hash comparison, so nothing to sync |
| Login Filter | `filterLogin` | `(&(objectClass=user)(mail=?))` — **must be overridden**: Stalwart's default filter matches `objectClass=inetOrgPerson`, which Authentik does not expose |
| Mailbox Filter | `filterMailbox` | `(&(objectClass=user)(\|(mail=?)(mailAlias=?)))` — same override; `mailAlias` only matches when the custom attribute is set |
| Member Of Filter | `filterMemberOf` | `(&(objectClass=groupOfNames)(member=?))` (default) |
| Password Changed Attribute | `attrSecretChanged` | `pwdChangeTime` (default) — invalidates cached OAuth tokens after LDAP password changes |

> **Custom Base DN:** the default `dc=ldap,dc=goauthentik,dc=io` is not required — any valid DN works (e.g. `dc=example,dc=com`). Set it on the Authentik LDAP provider, then mirror it here: `baseDn` = that DN, and `bindDn` = `cn=<service account username>,ou=users,<that DN>` — users always live under `ou=users,<base DN>`, so only the suffix changes. The `filter*` values are attribute-based and need no change. Update the `ldapsearch` example below to match, and after changing the DN on an existing provider run `docker restart ak-outpost-<outpost name>` to drop the outpost's cached bind results.

The other form sections keep their defaults for this setup: *Connection* (`Connection Timeout` 30 s, `Enable TLS` off — the outpost speaks plain LDAP on the shared network, `Allow Invalid Certificates` off), *Attributes* (`groupClass` `groupOfNames`, the `attr*` mappings listed above) and *Pool* (`Max Connections` 10).

> User bind authentication (`bindAuthentication: true`) means Stalwart never reads password hashes: login validates by binding to Authentik's outpost as the user. The service-account bind is still required for non-authentication lookups (address/domain validation, account metadata).

### Stalwart: bind the mail domain

Finally, **bind the mail domain to the directory**. v0.16 moved the domain list out of *Settings* into the **Management** layout — the older `Settings → Domains` path no longer exists:

- **Per domain** (what this stack uses): **Management → Domains → Domains** → open `${EMAIL_HOST}` → **Domain** section → **Directory** (`Domain.directoryId`). This selects the account source for that domain.
- **Global default**: **Settings → Authentication → General** → **Directory** section → **Authentication Directory** (`Authentication.directoryId`) — used for any domain that does not set its own.

Account lookups resolve the directory in this order: `Domain.directoryId` → `Authentication.directoryId` → Stalwart's internal directory. With a single mail domain either level works; leaving both unset keeps accounts on local passwords and the LDAP directory would never be consulted.

### Verify

Check that the outpost serves the directory from the host (it maps host ports `389`/`636` by default unless *Map ports* was unticked):

```bash
# replace dc=ldap,dc=goauthentik,dc=io with your Base DN if you changed it
ldapsearch -H ldap://localhost:389 \
  -D "cn=stalwart-ldap,ou=users,dc=ldap,dc=goauthentik,dc=io" -W \
  -b "dc=ldap,dc=goauthentik,dc=io" "(objectClass=user)"
```

(Filter on `objectClass=user` — Authentik does not expose `inetOrgPerson`/`posixAccount`, so Stalwart's stock LDAP filters must be overridden; see [Stalwart: LDAP directory](#stalwart-ldap-directory).) Users authenticate by binding as themselves with their Authentik password, so mail-client logins stay in sync with SSO.

### Troubleshooting binds

Check the outpost log first — it names the reason:

```bash
docker logs ak-outpost-<outpost name> 2>&1 | grep -iE "bind|error|flow"
```

| Outpost log / symptom | Cause & fix |
|---|---|
| `"Flow does not apply to current user"`, Stalwart logs LDAP `resultCode 49` | The LDAP provider's **Bind Flow** is not meant for binds — it must be an Authentication-designation flow (e.g. `default-authentication-flow`); a Source flow such as `default-source-authentication` cannot authenticate a directory bind. |
| No `"failed to execute flow"` error, retries log `"authenticated from session"`, yet Stalwart still gets `resultCode 49` | The provider's **Bind Flow** is unset, or — with *Cached binding* — an earlier failed bind is still cached: the outpost's cached binder stores the failed result code per (DN, password) and replays it. Set the flow, then clear the cache with `docker restart ak-outpost-<outpost name>` (only a restart resets it). *Direct binding* has no such cache. |
| Bind succeeds but searches return nothing | By default a bound user only sees their own entry and groups. The service account needs **Search full LDAP directory** — grant it a role as a provider object permission (or a global permission), see [Service account, role and permissions](#authentik-service-account-role-and-permissions). |
| Bind returns `50 insufficientAccessRights`, log says `Access denied for user` | The LDAP application's access bindings exclude the binding user/service account — grant access on the application. |
| Bind returns `50 insufficientAccessRights` but the outpost log shows **no bind entry for the attempt at all** | The bind never targets a provider. Two shapes: `bindDN:""` means the DN never reached the outpost (broken multi-line command — a flattened `\ -D` turns the backslash into a bogus filter argument and drops the DN; run the command on one line); `bindDN:"<base DN>"` means Stalwart's directory **Bind DN** field contains the bare base DN (e.g. `dc=lifamy,dc=com`) instead of the service account DN (`cn=<user>,ou=users,<base DN>`) — fix the field, restart `posteservice` to drop pooled LDAP connections. The outpost replies `50` for "no provider found" binds, which Stalwart surfaces as "Temporary server failure" on the login page. |
| Stalwart logs `auth.failed ... details = "Auth bind lookup filter yielded no results"` | The lookup filter (e.g. `(&(objectClass=user)(mail=<address>))`) matched no entry: the user's **Email** field in Authentik is empty/different from the login name, or the service account's search can't see the user (missing **Search full LDAP directory**, or an outpost container still caching the pre-permission state — `docker restart ak-outpost-<outpost name>`). `ldapsearch` as the service account with the same filter shows exactly what Stalwart sees. |
| `resultCode 49 invalidCredentials` with the flow set correctly | The stored **Bind Secret** does not match the service account password — reset it in Authentik (*Users → the service account → Set password*) and update Stalwart's directory. |
| Binds or searches fail after changing the Base DN | Stalwart's directory still uses the old `baseDn`/`bindDn` — update both to the new DN, then `docker restart ak-outpost-<outpost name>` to clear the outpost's cached bind results. |

### Passwords & clients

- With LDAP user-bind authentication, local password changes from the webmail are **not possible** (Stalwart doesn't own the hash) — users change their password in Authentik.
- **App passwords** — per-device credentials that bind with the same DN, supported on the Authentik side: enable *User database + app passwords* on the LDAP provider's Bind Flow password stage — open **Flows and Stages → Flows → `default-authentication-flow`** and edit the password stage it references (if the identification stage has a **Password stage** set, edit that one) → **Backends**.
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

The exported files only take effect once a **Certificate object** references them (v0.16 stores certificates in PostgreSQL under **Settings → TLS → Certificates**; empty by default, so nothing is served until this is done once):

1. **Settings → TLS → Certificates → Create certificate** — set `certificate` to type **File** `/var/lib/stalwart/tls/fullchain.pem` and `privateKey` to type **File** `/var/lib/stalwart/tls/privkey.pem`. Stalwart parses the SANs, issuer and validity automatically (server-set fields on the object).
2. **Settings → Authentication → General** (SystemSettings) → **Default Certificate** (`defaultCertificateId`) → select that certificate — what clients without SNI get.
3. Listener TLS settings don't need changes; certificates are selected by SNI against the object's SAN list.

Renewals need no further action: `acme-export.sh` replaces the files and restarts the container, and Stalwart re-reads them at boot.

Verify what the listeners actually serve:

```bash
docker compose exec posteservice \
  openssl s_client -connect localhost:993 -servername ${EMAIL_HOST} </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

- `issuer=...Let's Encrypt...` — the exported certificate is in use.
- `issuer` and `subject` are both `${EMAIL_HOST}` (self-signed within the container bootstrap) — still the bootstrap certificate; the Certificate object is missing or wrong. Run `docker compose restart posteservice` after fixing it.

## Logs & troubleshooting

Stalwart logs through *Tracers* (**Settings → Telemetry → Tracers**). v0.16 has **no console tracer by default**: when no tracer exists, Stalwart creates a **Log (file)** tracer that writes `/var/log/stalwart/stalwart.log.<YYYY-MM-DD>` (daily rotation) at level *Info*. The entrypoint creates and chowns that directory so it works out of the box:

```bash
docker compose exec posteservice ls -l /var/log/stalwart/
docker compose exec posteservice tail -f "/var/log/stalwart/stalwart.log.$(date +%F)"
```

> If the file is missing, the tracer was never able to open it (Stalwart does not create log directories, and the `stalwart` user cannot write into a root-owned one). Fix the directory ownership or point the tracer at `/var/lib/stalwart/logs` (also created by the entrypoint), then `docker compose restart posteservice`.

`docker compose logs -f posteservice` shows only bootstrap output (e.g. the certificate retry notice) — tracer events do not go to stdout unless a **Stdout** tracer is configured (next section).

### Logging to the Docker console

To capture tracer events with `docker compose logs` — for example to keep all stack output in one place — add a **Stdout** tracer instead of (or alongside) the file tracer:

1. **Settings → Telemetry → Tracers → Create tracer** → type **Stdout**; set **Level** (default *Info*, same as the file tracer) and save.
2. Optionally open the *Log* tracer and turn **Enable** off (or delete it) so events are not written to disk as well.
3. Reproduce and follow the output:

    ```bash
    docker compose logs -f posteservice
    ```

Notes:

- The default file tracer is only created while **no** tracer exists, so it does not come back once you add your own tracer.
- Only **one console tracer** is allowed; a second *Stdout* tracer is skipped with an `Only one console tracer is allowed` config error.
- *Buffered* (default on) batches writes and *ANSI* (default off) keeps colour codes out of `docker logs` — the defaults are the right choice for console output.

To debug authentication (e.g. LDAP binds):

1. **Settings → Telemetry → Tracers** → open the *Log* (or *Stdout*) tracer → set **Logging level** to *Debug* (or *Trace*), save, and restart `posteservice`.
2. Reproduce the failure and read the file or `docker compose logs` as above; bind errors show the LDAP result code (e.g. `49 invalidCredentials`).
3. **Settings → Telemetry → Event Levels** overrides levels per `Event Id` when the global level is too noisy.

The file tracer's path is on the container filesystem, so those logs are lost when the container is recreated. To persist them, edit the tracer's **Path** to `/var/lib/stalwart/logs` (host `${APPS_DATA}/platform/mailbox/logs`); console output instead lives in Docker's logging driver (`docker compose logs`, no rotation unless configured on the daemon).

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

PostgreSQL holds everything, so the fastest path is: first `docker compose up -d posteservice` boots straight into the admin UI with the recovery admin, provision the directory + accounts, then deploy Bulwark. Complete steps, in order:

1. **Database** — `${POSTE_DBNAME}` in `PGRSQL_DBLIST`; `docker compose up -d dbsvcpgsqldb` creates it on first start.
2. **Stalwart** — `docker compose up -d posteservice`; sign in at `https://${EMAIL_HOST}/admin` with `${STALWART_ADMIN_USER}` / `${STALWART_ADMIN_PASS}` (recovery admin).
3. **LDAP provider in Authentik** — Application `stalwart-mail` with provider type **LDAP Provider** (Base DN: default `dc=ldap,dc=goauthentik,dc=io` or your own — see the [directory section](#directory-authentik-ldap-sso); full field-by-field provider settings — Bind/Unbind Flow, bind/search modes — in [Authentik: application and LDAP provider](#authentik-application-and-ldap-provider)).
4. **LDAP service account in Authentik** — Directory → Users → New User `stalwart-ldap`; set a password under Recovery. Create a role `LDAP search` with the **Search full LDAP directory** permission, add the service account to it, and assign the role to the provider under its **Permissions** tab (object vs global permission, and application access: [Authentik: service account, role and permissions](#authentik-service-account-role-and-permissions)).
5. **LDAP outpost in Authentik** — **Applications → Outposts → Create Outpost**, type **LDAP**, integration **Docker**, applications: `stalwart-mail`; edit the outpost config and set **Docker network** to `servicehub_subnet`. The outpost container is named after the outpost (`ak-outpost-<name>`) and listens on `3389`/`6636` — note it also maps host ports `389`/`636` unless you untick *Map ports*. Verify with the `ldapsearch` command in the [directory section](#directory-authentik-ldap-sso).
6. **Point Stalwart at the outpost** — Stalwart admin → **Settings → Authentication → Directories → Create directory** (type LDAP), using the values from the [directory table](#directory-authentik-ldap-sso) above. Then bind the mail domain: **Management → Domains → Domains** → `${EMAIL_HOST}` → **Domain** section → **Directory** (or, for all domains at once, **Settings → Authentication → General** → **Authentication Directory**).
7. **Technical sender account in Authentik** — since the mail domain is bound to LDAP, create `servicehub@${EMAIL_HOST}` as an Authentik service account with that address as its **email**; `${EMAIL_PASS}` is the account's password. Stack components send with `${EMAIL_USER}` / `${EMAIL_PASS}` on port `${EMAIL_PORT}` (see [Root README — Email](../../README.md#configuration)).
8. **Mailboxes for users** — for LDAP-backed users authentication needs no extra setup; create the mailbox in Stalwart (matching the user's `mail` attribute) to assign quota and groups. Verify a login with the user's **email + Authentik password** from an IMAP/JMAP client or Bulwark's password form.
9. **Bulwark webmail** — `docker compose up -d postesvcinit postewebmail`; users sign in at `https://${WEBMAIL_DOMAIN}` with their **email + Authentik password** (the password form validates through Stalwart's LDAP directory). Before first login, enable **Permissive CORS policy** (**Settings → Network → HTTP → Security**, `usePermissiveCors`) and confirm the [Certificate object](#tls-certificates) is in place — both are login prerequisites documented in [Bulwark — Login prerequisites](../bulwark/README.md#login-prerequisites-stalwart-side). OIDC SSO is not used in this stack (requires an OIDC-backed Stalwart directory — see [Bulwark — SSO/OIDC](../bulwark/README.md#sso--oidc-not-used)).

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
| [`Dockerfile`](Dockerfile) | Image build — upstream image + curl/jq/inotify-tools for the cert watch tooling; `ldap-utils` for LDAP connectivity/debugging against the Authentik outpost (`docker compose exec posteservice ldapsearch ...`) |
| [`entrypoint.sh`](entrypoint.sh) | Generates the PostgreSQL `DataStore` config with `jq`, pins the recovery admin, bootstraps certs, drops privileges, starts the export watcher |
| [`acme-export.sh`](acme-export.sh) | Extracts and installs the public certificate from Traefik's `acme.json` |

## See also

- [Bulwark Webmail](../bulwark/README.md) — JMAP webmail client for this server (password form via the LDAP directory; OIDC SSO not used)
- [Authentik](../authentik/README.md) — IdP; the LDAP directory walkthrough is above
- [PostgreSQL](../postgresql/README.md) — the shared database host (`dbsvcpgsqldb`)
- [Traefik](../traefik/README.md) — edge routing and TLS termination
- [Root README — Email stack](../../README.md#email-stack-poste)
