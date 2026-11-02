# 9Router Backup and Restore Runbook

**Service:** `routeniner` (Compose: `compose/route.yml`)  
**ADR-011 experimental** — Tier 2 backup scope  
**Version:** 1.0  
**Status:** Draft (runtime validation pending)

---

## Persistent State Inventory

| Host Path | Container Path | Description |
|-----------|----------------|-------------|
| `${APPS_DATA}/route/niner/db/data.sqlite` | `/app/data/db/data.sqlite` | Primary SQLite database (providers, API keys, combos, usage, quota) |
| `${APPS_DATA}/route/niner/db/backups/` | `/app/data/db/backups/` | Automatic SQLite backups (internal rotation) |
| `${APPS_DATA}/route/niner/data-home/jwt-secret` | `/app/data-home/jwt-secret` (symlinked from `/root/.9router/jwt-secret`) | JWT signing secret (auto-generated if `JWT_SECRET` unset) |

**Total backup scope:** `${APPS_DATA}/route/niner/`

---

## Backup Classification (ADR-007)

| Tier | Cadence | Scope | Method |
|------|---------|-------|--------|
| **Tier 2** | Weekly (default Sunday 02:30) | `${APPS_DATA}/route/niner/` | Full archive via backup workflow (`forgejo/71-backup.yml`) |

**Consistency:** Crash-consistent file copy. SQLite is in WAL mode; backup may contain incomplete transactions. Post-restore functional test required.

---

## Backup Procedure (Automated)

The existing backup workflow handles `route/niner` as part of the full `APPS_DATA` archive.

### Trigger
- Scheduled: Weekly via Forgejo Actions (see `forgejo/71-backup.yml`)
- Manual: `workflow_dispatch` with `full` input

### What Runs
1. Archive `${APPS_DATA}/route/niner/` (alongside other route/domain dirs)
2. Verify SHA-256 of archive
3. Copy to Home Server and/or Google Drive (Crypt remote)
4. Record artifact metadata in workflow summary

### Exclusions
None — entire `${APPS_DATA}/route/niner/` included.

---

## Restore Procedure

### Prerequisites
- Access to backup target (Home Server or Google Drive)
- ServiceHub host with `docker compose` available
- Tier 2 archive for desired date

### Steps

1. **Stop the service**
   ```bash
   docker compose stop routeniner
   ```

2. **Extract archive to staging**
   ```bash
   mkdir -p /tmp/niner-restore
   tar -xzf <archive.tar.gz> -C /tmp/niner-restore
   ```

3. **Verify extracted content**
   ```bash
   ls -la /tmp/niner-restore/route/niner/
   # Should show: db/, data-home/
   ```

4. **Replace persistent directory**
   ```bash
   # Backup current state (safety)
   mv ${APPS_DATA}/route/niner ${APPS_DATA}/route/niner.pre-restore.$(date +%s)
   # Restore
   mv /tmp/niner-restore/route/niner ${APPS_DATA}/route/niner
   ```

5. **Fix ownership (container runs as node user, UID 1000)**
   ```bash
   chown -R 1000:1000 ${APPS_DATA}/route/niner
   chmod -R 750 ${APPS_DATA}/route/niner
   ```

6. **Start the service**
   ```bash
   docker compose up -d routeniner
   ```

7. **Post-restore functional test**
   - Wait for container healthy: `docker compose ps routeniner`
   - Access dashboard from `TRUSTED_IP`: `https://cerberus.${DOMAIN_NAME}/dashboard`
   - Verify API keys still work:
     ```bash
     curl -H "Authorization: Bearer <EXISTING_API_KEY>" \
          https://cerberus.${DOMAIN_NAME}/v1/models
     ```
   - Verify providers connected in dashboard UI

8. **Clean up staging**
   ```bash
   rm -rf /tmp/niner-restore
   ```

---

## Credential Rotation After Restore

If the backup is suspected compromised:

1. **Regenerate JWT secret** (auto-generated at restart if missing, or set `JWT_SECRET` in `.env`)
2. **Regenerate client API keys** via 9Router dashboard → Settings → API Keys
3. **Update all clients** (Claude Code, Codex CLI, OpenCode) with new keys
4. **Re-enter NVIDIA API key** via dashboard (not in backup scope if rotated)

---

## Upgrade Procedure

The deployment follows the owner-approved moving `latest` tag policy (ADR-011 Stage 4). `compose/route.yml` is not edited on upgrade; the resolved image identity is recorded instead.

### Pre-Upgrade
1. Review upstream release notes for breaking changes
2. Record the currently deployed image ID and repository digest:
   ```bash
   docker inspect routeniner --format '{{.Image}}'
   docker images --digests decolua/9router
   ```
3. Create Tier 2 backup (on-demand): `workflow_dispatch` with `full` — or stop the service and archive `${APPS_DATA}/route/niner/` directly for a consistency-safe SQLite copy

### Upgrade
1. `docker compose pull routeniner`
2. `docker compose up -d routeniner` (recreates only `routeniner`)
3. Run the validation checklist above

### Rollback
1. Re-tag the previously recorded image identity as `decolua/9router:latest` (or run the container from the recorded digest)
2. `docker compose up -d routeniner`
3. Run the validation checklist above

> **Risk:** `latest` is mutable. A later pull can deploy different software without changing `compose/route.yml`. Every upgrade must record the resolved image identity and include post-upgrade validation.

---

## Validation Checklist

| Check | Method | Expected |
|-------|--------|----------|
| Container starts | `docker compose ps` | `Up`, healthy |
| Dashboard accessible | Browser from `TRUSTED_IP` | Login page → dashboard |
| API key valid | `curl /v1/models` with Bearer | JSON model list |
| Providers connected | Dashboard UI → Providers | NVIDIA + OpenCode Free |
| SQLite intact | Dashboard → Usage/Stats | Historical data present |

---

## Emergency Contacts

- **Owner:** Project Owner (per `docs/governance/governance-adoption.md`)
- **Escalation:** Stop and report if restore fails or data corruption detected

---

## Related Documents

- [niner.md](../services/niner.md)
- [BACKUP-RESTORE.md](BACKUP-RESTORE.md)
- [ADR-007: Dual-Target Backup and Recovery](../../architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md)
- [ADR-011: 9Router AI Gateway](../../architecture/adr/ADR-011-adopt-9router-as-servicehub-ai-gateway.md)