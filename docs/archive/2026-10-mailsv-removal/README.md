# Archive: mailsv stack removal (2026-10)

The self-hosted email stack (Stalwart mail server + Bulwark webmail) was
disabled from the ServiceHub deployment in October 2026.

## Reason

Oracle Cloud Infrastructure blocks outbound port 25 (SMTP) by default, and
unblocking it requires a manual support request that is not guaranteed to be
approved. Self-hosted outbound email is therefore not viable on the OCI
deployment. An external email provider is used instead.

For notification email only, OCI Email Delivery can also be used directly on
its `587` SMTP submission endpoint; opening outbound port `25` is not required.

## What changed

- `docker-compose.yml`: the `compose/mailsv.yml` include was removed.
- `scripts/gen-admin-rules.py`: the `mailsvstalwart-*` Traefik routers are
  generated only when `ENABLE_MAILSV="true"` (default: `false`).
- `env.example`: `ENABLE_MAILSV="false"` added. Mail-only settings remain
  configured, and `setup.sh` generates their secrets, so the disabled stack is
  ready to enable later.

## Archived files

- `docs/operations/services/stalwart.md` — Stalwart setup and operations guide
- `docs/operations/services/bulwark.md` — Bulwark webmail setup guide
- `docs/lessons/LES-002-stalwart-allowlist-broke-bulwark-login.md` — incident
  lesson from the Stalwart/Bulwark allowlist issue

The compose file `compose/mailsv.yml` remains in the repository (excluded from
the root include) so the stack can be re-enabled on infrastructure that permits
outbound port 25 by setting `ENABLE_MAILSV="true"` and restoring the include.
