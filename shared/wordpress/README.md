# WordPress — ServiceHub

> Optional WordPress homepage / CMS (PHP-FPM + Nginx). Not enabled by default.

## Overview

[WordPress](https://wordpress.org/) runs on a custom `wordpress:fpm-alpine` image with Nginx and PHP-FPM managed by supervisord. It can replace Confluence as the homepage, serving `WBHOME_DOMAIN` plus the apex `${DOMAIN_NAME}`.

The service is kept ready to run in [`compose.yml`](compose.yml) but is **not** included by the root `docker-compose.yml`. It is backed by [MariaDB](../mariadb/README.md). Only one homepage can run at a time — Confluence and WordPress both claim `WBHOME_DOMAIN` and the apex domain.

## Service details

| Detail | Value |
|---|---|
| Service name | `wbappcmswppv` |
| Compose file | `shared/wordpress/compose.yml` (not included by default) |
| URL | `https://${WBHOME_DOMAIN}` and `https://${DOMAIN_NAME}` (apex) |
| Internal port | 80 (Nginx; TLS terminated by Traefik) |
| Database | MariaDB (`${WBHOME_DBNAME}`) |
| Data persistence | `${APPS_DATA}/webapps/wordpress` (mounted at `/var/www/html`) |
| Process manager | supervisord (PHP-FPM + Nginx) |
| PHP extensions | intl, zip, gd, opcache, imagick, exif, fileinfo |

## Switching from Confluence

1. Stop the running Confluence homepage:

    ```bash
    docker compose stop wbappcmsconf
    ```

2. In [`docker-compose.yml`](../../docker-compose.yml), replace `- compose/wbapp.yml` with `- shared/wordpress/compose.yml`.
3. In `.env`, ensure `MARIADB_DB_LIST` contains `${WBHOME_DBNAME}` (the default) and set `WBHOME_DOMAIN` / `WBHOME_DBNAME` as desired.
4. Start it:

    ```bash
    docker compose up -d --build
    ```

Reverse the change to go back to Confluence; the two must never run together.

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Description |
|---|---|
| `WBHOME_DOMAIN` | Homepage hostname (default `www.${DOMAIN_NAME}`) |
| `WBHOME_DBNAME` | MariaDB database name (must be in `MARIADB_DB_LIST`) |
| `SQLDB_USER` / `SQLDB_PASS` | Shared MariaDB credentials |
| `MySQL_HOST` / `MySQL_PORT` | MariaDB connection target (`dbsvcmariadb:3306`) |
| `APPS_DATA` | Host path for the data bind mount |
| `TIME_ZONE` | Container timezone |

Container settings applied by the compose file:

| Setting | Value | Purpose |
|---|---|---|
| `WORDPRESS_DB_HOST` | `${MySQL_HOST}` | Database host (`dbsvcmariadb`) |
| `WORDPRESS_DB_NAME` | `${WBHOME_DBNAME}` | Database name |
| `WORDPRESS_DB_USER` / `WORDPRESS_DB_PASSWORD` | `${SQLDB_USER}` / `${SQLDB_PASS}` | Database credentials |

## Data & persistence

| Container path | Host path | Purpose |
|---|---|---|
| `/var/www/html` | `${APPS_DATA}/webapps/wordpress` | WordPress core, plugins, themes, uploads and `wp-config.php` |

The image aligns `www-data` with UID/GID `1000` (`WWW_DATA_UID` / `WWW_DATA_GID`) so the bind mount is writable by the host user.

## Setup (first boot)

1. Start WordPress (after switching the include, with Traefik and MariaDB healthy):

    ```bash
    docker compose up -d wbappcmswppv
    ```

2. Open `https://${WBHOME_DOMAIN}/wp-admin/install.php` and complete the WordPress installer.

## Operations

```bash
# Start / restart
docker compose up -d wbappcmswppv

# Rebuild after a Dockerfile or config change
docker compose up -d --build wbappcmswppv

# Follow logs
docker compose logs -f wbappcmswppv
```

## Files

| Path | Purpose |
|---|---|
| [`compose.yml`](compose.yml) | Service definition (swap this in for `compose/wbapp.yml` to enable) |
| [`Dockerfile`](Dockerfile) | Image build (`FROM wordpress:fpm-alpine`) + Nginx/supervisord/PHP setup |
| [`etc/nginx/nginx.conf`](etc/nginx/nginx.conf) | Nginx base configuration |
| [`etc/nginx/http.d/00-common.inc`](etc/nginx/http.d/00-common.inc) | Shared locations (caching, hidden-file denial) |
| [`etc/nginx/http.d/10-wordpress.inc`](etc/nginx/http.d/10-wordpress.inc) | WordPress rewrite and PHP-FPM proxying |
| [`etc/supervisord.conf`](etc/supervisord.conf) | Runs PHP-FPM and Nginx in one container |

## See also

- [Confluence](../confluence/README.md) — the default homepage (never run both)
- [MariaDB](../mariadb/README.md) — database backend
- [Traefik](../traefik/README.md) — edge routing and TLS
- [Root README — Homepage](../../README.md#homepage)
