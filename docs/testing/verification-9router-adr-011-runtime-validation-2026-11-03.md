# Verification Summary: ADR-011 9Router Runtime Validation (2026-11-03)

| Field | Value |
|---|---|
| Scope | ADR-011 9Router AI gateway — 27 Implementation Validation Gates (Stage 6) |
| Verified commit | `4d45965` (branch `feature/9router-ai-gateway`) |
| Environment | Local OrbStack Docker Compose project `servicehub` |
| Date | 2026-11-03 |
| Performed by | AI agent (Claude Code); agent results require owner review |
| Result | Passed with deviations — service stays experimental; operational acceptance not granted |

## 0. Scope statement: local versus OCI

| Environment | Status | Note |
|---|---|---|
| Local OrbStack (`servicehub` compose project) | PARTIAL | All runtime evidence below was collected here, read-only, with no container restart or recreation |
| OCI-hosted platform (ADR-011 deployment scope) | NOT RUN | Not reachable from the validation workstation; owner-side validation required |

**Local results do not prove OCI operational readiness.** ADR-011 places the
deployment scope on the OCI platform; every PASS in this report is evidence
about the local instance only.

## 0a. Evidence provenance

| Evidence | Source |
|---|---|
| Owner-provided (recorded, not agent-verified) | Hermes/Athena/Hyperion combos exist and work; OpenCode Free works; container was (re)started 2026-11-02T23:39Z by a non-agent action |
| Agent-executed | All probes, log sampling, DB reads, resource measurements in this report |
| Blocked by permission controls | NVIDIA rate ramp; full credential-pattern scan of live logs (structural sampling only); SQLite settings/key-value inspection |

No owner evidence below has been independently confirmed by the agent.

## 1. 27-gate results

Statuses: PASS / PARTIAL / FAIL / NOT RUN. Totals at the end must equal 27 rows.

| # | Gate (ADR-011) | Status | Evidence |
|---|---|---|---|
| 1 | Pinned release and image | PARTIAL | Image digest recorded: `sha256:fab111d99b23bde6c8944ca22982603ab0b09e917a0b1e4ce42a24b05753bec9` (`decolua/9router:latest`, 1.29 GB). Compose uses the mutable `latest` tag (owner-approved moving-tag policy); versioned-tag availability in the upstream registry not verified |
| 2 | Start without unnecessary privileges | PASS | `docker inspect`: `Privileged=false`, `CapAdd=null`, no docker.sock, single bind `…/route/niner:/app/data:rw`, `PortBindings={}`. RestartCount=0, OOMKilled=false. The observed start was a non-agent action |
| 3 | Persistence survives recreation | NOT RUN | Requires recreation — prohibited in this task. Circumstantial only: DB intact (integrity ok; combos=3, apiKeys=1, providerConnections=4, usageHistory=348) after the 2026-11-02T23:39Z start |
| 4 | HTTPS routing at `cerberus.<domain>` | PASS (local) | `curl --cacert <served-chain> https://cerberus.onelijia.local/v1/models` → HTTP 200, ~94 ms, full chain verification (leaf `*.oneLiJIA.com`, issuer OnelijiaCA). No TLS weakening flags used |
| 5 | No public native application port | PASS | `PortBindings={}`; native port 20128 not published; Traefik-only ingress |
| 6 | Dashboard protected by approved policy | PARTIAL | Unauthenticated `/dashboard/` → HTTP 401 from the whitelisted validation host (basicAuth + ipAllowList verified live). Rejection from an actual untrusted source was not tested (no non-whitelisted vantage available) |
| 7 | Unauthenticated and invalid API requests rejected | PASS | No key → 401; request with an invalid bearer token → 401 (live) |
| 8 | Claude Code compatibility | PARTIAL | Live gateway use by this validation session (Sonnet/Athena tier): `/v1/models` 200, chat completions 200, claude→claude format translation in logs. Only the Sonnet/Athena tier was exercised end-to-end; Haiku/Hermes and Opus/Hyperion, streaming and tool-call paths were not separately exercised |
| 9 | Codex CLI compatibility | NOT RUN | `codex` CLI not installed on the validation workstation |
| 10 | OpenCode compatibility | NOT RUN | `opencode` binary not present (checked PATH, `~/.opencode/bin`, `~/.local/bin`, npm globals, homebrew). Prior session's provider-registration issue therefore unresolved; exact blocker: client binary unavailable |
| 11 | OpenCode Free availability and routing | PARTIAL | Historical owner PASS: OpenCode Free works (owner evidence, not re-verified). Current agent evidence: `oc/*` models exposed via `/v1/models` and selected in rotation, but every observed `oc/*` attempt in the 48 h window hit `429 FreeUsageLimitError`; no agent-executed successful `oc/*` completion captured |
| 12 | NVIDIA API-key provider connectivity | PASS | Direct member `nvidia/z-ai/glm-5.3-flash`: 4/4 HTTP 200 valid completions (1.0–5.0 s); log line `[COMBO] Model nvidia/z-ai/glm-5.3-flash succeeded` |
| 13 | Measured NVIDIA behaviour near the planned limit | NOT RUN | Rate-ramp test denied by permission controls (load-testing a shared live service). No synthetic load sent |
| 14 | Verified proactive or compensating 40 RPM control | PARTIAL (open) | No proactive 36/39/40 RPM NVIDIA budget implemented (matches ADR-011 Gate 14 status: open). Live: `strategy: round-robin, sticky: 1` on all combos; no rate-limit settings present. Compensations observed: RTK token saver active, one-session-at-a-time team policy, reactive fallback — none verified as RPM-equivalent control |
| 15 | Bounded concurrency | PARTIAL | Bounded-retry mechanics observed in logs (30 s model lock on 502, per-account lock). No concurrency measurement executed |
| 16 | No immediate 429 retry storm | PASS | Natural 429s in 48 h logs show single-step `failed, trying next` member transitions; no same-member hammering pattern in sampled lines. Structural sampling only |
| 17 | Correct handling of Retry-After / reset information | PARTIAL | Fixed 30 s model lock observed on 502. Explicit `Retry-After` header handling not observed (upstream docs silent per ADR-011) |
| 18 | NVIDIA exhaustion returned as valid error, not 200-null | PARTIAL | Member failures propagate as typed error JSON and trigger fallback; no HTTP 200-with-null observed. Full all-members-exhausted end-to-end case neither observed nor manufactured |
| 19 | NVIDIA 400 errors remain actionable, not 429 fallback | PASS | Live probe (invalid `max_tokens`/`top_p`): HTTP 400 with `type: invalid_request_error`, `code: bad_request`, upstream message preserved — not masked as 429/fallback |
| 20 | Fallback selects only approved free routes | PARTIAL | Fallback stays within combo membership, but deployed membership includes two unapproved members (see §2); "only approved" cannot hold until the drift is corrected |
| 21 | Paid routes remain disabled | PARTIAL | Model list shows only `:free` OpenRouter entries and `oc/*` free models; no paid OpenRouter models exposed. Gemini and MiniMax account/plan status (free vs paid backend) not confirmed — owner configuration not verified |
| 22 | Fail-closed when free routes unavailable | NOT RUN | All-members-failed scenario neither observed nor manufactured (fault injection out of bounds) |
| 23 | No sensitive payload or credential logging | PARTIAL | Structural sampling shows model names, status codes, token counts only. Pattern scan of 48 h logs for `sk-…`, `Bearer …`, private-key blocks, `password=`, and auth-header mentions returned 0 matches. Full systematic scan denied by permission controls; `ENABLE_REQUEST_LOGS=false` set in compose (request-detail table empty in DB copy) |
| 24 | Usable health and operational visibility | PARTIAL | Protected dashboard; per-request logs (latency, tokens, combo/member); Traefik healthcheck healthy. Gap: `routeniner` has no container healthcheck (`Health=null`) |
| 25 | Backup and restore validation | PARTIAL | File-level drill executed live without stopping the service: SQLite online-backup copy, `pragma integrity_check` = ok, row counts verified, `jwt-secret`/`machine-id` present. Container-level restore (stop → replace → start → functional test) NOT RUN — prohibited. Runbook corrected this task (see §3) |
| 26 | Documented upgrade and rollback | PARTIAL | Runbook documents upgrade and rollback with digest recording; two inaccuracies corrected this task (§3). Execution NOT RUN (requires recreate) |
| 27 | No regression to existing ServiceHub services | PASS (local) | Traefik healthy, RestartCount=0; other containers unaffected; no new published ports; `docker compose config --quiet` passed. OCI-side regression not observable from the validation workstation |

### Totals (must equal 27)

| Status | Count | Gates |
|---|---|---|
| PASS | 7 | 2, 4, 5, 7, 12, 16, 19 |
| PASS (local scope only) | 1 | 27 |
| PARTIAL | 12 | 1, 6, 8, 11, 14, 15, 17, 18, 20, 21, 23, 24 |
| PARTIAL (backup scope) | 1 | 25 |
| PARTIAL (documented, not executed) | 1 | 26 |
| FAIL | 0 | — |
| NOT RUN | 5 | 3, 9, 10, 13, 22 |

Count check: 7 + 1 + 12 + 1 + 1 + 0 + 5 = 27.

Gate 14 is recorded **PARTIAL (open)** — matching the ADR-011 "Gate 14 status"
section — not FAIL: no proactive control exists and the ADR explicitly tracks
this gate as open pending runtime evidence or a future provider-aware control.

## 2. Combo membership drift (runtime drift, not accepted)

Approved definitions (`docs/operations/services/niner.md`) versus deployed state
read from the live service DB on 2026-11-03:

| Combo | Approved | Deployed | Difference |
|---|---|---|---|
| hermes | `oc/mimo-v2.6-flash-free`, `oc/glm-5.3-flash-free`, `openrouter/nvidia/nemotron-3.5-lightning:free`, `gemini/gemini-3.5-flash-lite` | 5 members incl. **`nvidia/meta/muse-glimmer-30b`** | Extra direct NVIDIA NIM member; contradicts the documented "no direct NVIDIA member" intent and adds Hermes traffic to the NVIDIA budget |
| athena | 4 approved members in documented order | Same 4 members, different order | Order only; not material under steady-state Round Robin |
| hyperion | 4 approved members | 5 members incl. **`gemini/gemini-3.6-flash`** | Extra member explicitly excluded in documentation (20 RPD exhaustion risk) |

Both extra members were observed being selected in live rotation. Per owner
review (2026-11-03): the approved definitions remain authoritative; ADR-011 is
not amended to accept the extras; removing them from the deployed dashboard
state requires separate owner authorisation. Until corrected, this drift stands
recorded and Gate 20 remains PARTIAL.

## 3. Runbook corrections applied (2026-11-03)

`docs/operations/runbooks/9ROUTER-BACKUP-RESTORE.md` (v1.0 → v1.1):

1. jwt-secret path corrected to the verified location: `/app/data/jwt-secret`
   (host `${APPS_DATA}/route/niner/jwt-secret`), plus `machine-id`. The previous
   `data-home/jwt-secret` claim was wrong — verified in the deployed container
   that `/app/data-home` is empty and no symlink target holds the secret.
2. Unsupported "container runs as node user, UID 1000" claim removed. Verified
   runtime: the service process runs as `root` (uid 0) and data files are owned
   `0:0` in-container / `501:20` on the macOS host.
3. Blind `chown -R 1000:1000` replaced with inspect-first instructions
   (`docker compose exec routeniner id`, `ls -ln`) and conditional ownership
   alignment.
4. Upgrade/rollback inspection commands aligned to compose service naming; a
   version note records that upgrade/rollback were reviewed but not executed.
5. Validation checklist corrected: no container healthcheck exists for
   `routeniner`; provider check no longer hardcodes "NVIDIA + OpenCode Free".
6. Scope and backup tier unchanged (Tier 2, `${APPS_DATA}/route/niner/`).

## 4. Client configuration validation

- Claude Code alias configuration validated live: `ANTHROPIC_BASE_URL` points at
  the gateway; the three `ANTHROPIC_DEFAULT_*_MODEL` aliases map
  Haiku→hermes, Sonnet→athena, Opus→hyperion; `model: sonnet` sets the default
  interactive tier. This is the intended configuration.
- `ANTHROPIC_MODEL=athena` found in the workstation's local client settings is
  **not** part of the intended configuration; the recommendation to set it is
  removed from `niner.md` (it pins every request to one combo and defeats alias
  selection).
- Codex CLI: NOT RUN — binary not installed.
- OpenCode: NOT RUN — binary not installed (`command not found`; absent from
  `~/.opencode/bin`, `~/.local/bin`, npm global list, homebrew).

## 5. Security and privacy findings

1. Client API key stored in plaintext in the workstation's `~/.claude/settings.json`
   and appeared in a prior session transcript. **Owner action (pending
   confirmation):** remove the key from local files and rotate it. Not confirmed
   as done; the agent performed no rotation and claims none.
2. Secret-bearing temporary files from the prior session
   (`/tmp/niner-restore-drill/` with `jwt-secret`, `machine-id`, `data.sqlite`;
   assorted evidence JSON files). **Owner action (pending confirmation):**
   delete them. The agent's cleanup attempt was denied; nothing was deleted.
3. `TRAEFIK_BAAUTH` hash present in the generated, untracked
   `shared/traefik/advanced/admin-routers.yml` — generation artefact, not
   committed; no action taken.
4. `ENABLE_REQUEST_LOGS=false` is set and the `requestDetails` table is empty in
   the DB copy — payload logging is off by configuration.

## 6. Owner actions pending confirmation

| Action | Status |
|---|---|
| Delete secret-bearing temp files (`/tmp/niner-restore-drill/` et al.) | Owner will do; NOT confirmed |
| Rotate the Claude Code client API key (transcript exposure) | Owner will do; NOT confirmed |
| Authorise and perform removal of `nvidia/meta/muse-glimmer-30b` (hermes) and `gemini/gemini-3.6-flash` (hyperion) from deployed dashboard state | Awaiting separate authorisation |

## 7. Commands run (Mandatory)

| Command | Outcome |
|---|---|
| `git diff --check` | Clean |
| `docker compose config --quiet` | Passed |
| `shellcheck scripts/*.sh` | NOT RUN — shellcheck not installed (exit 127) |
| `python3 ~/Documents/workspaces/nexora-audits/check-links.py` | NOT RUN — script path does not exist on this workstation |
| `git diff 257a48a..HEAD` secret-pattern scan (count-only) | 4 matches, all placeholder literals (`<CODEX_API_KEY>`, `<OPENCODE_API_KEY>`, `<YOUR_STRONG_NINER_INITIAL_PASSWORD>`, env passthrough) — no real secrets in branch diff |
| Runtime log credential-pattern scan (count-only) | 0 matches in 48 h window (structural sampling; full systematic scan denied by permission controls) |
| Markdown internal-link check over the 4 changed/added markdown files (ad-hoc, Python stdlib; relative links only) | 0 broken links |
| Full diff review | Performed by the agent across the branch diff (11 files) and this task's diff before committing |

## 8. Failures and deviations (Mandatory)

1. Gate 14: no proactive NVIDIA RPM control — open per ADR-011.
2. Gates 3, 13, 22: NOT RUN — require recreation/load/fault injection, prohibited.
3. Gates 9, 10: NOT RUN — Codex/OpenCode binaries absent from the workstation.
4. Combo membership drift (§2) — uncorrected pending owner authorisation.
5. OCI environment unvalidated (§0).
6. Validation tools unavailable: shellcheck, docs link checker.
7. This report is agent-produced evidence; it is not owner approval.

## 9. Not applicable items (Mandatory where any)

None — all 27 gates are applicable; none are marked N/A.

## 10. Owner review (Mandatory)

- Reviewed by: **pending — Project Owner**
- Approval mode: agent evidence only; operational acceptance requires ADR-011's
  27 gates to pass with owner review of all `NOT RUN`/`PARTIAL` items
- Date: 2026-11-03

## 11. Recommendation

Keep the 9Router service **experimental**. Operational acceptance is not
recommended until: combo drift is corrected and re-validated; gates 3, 9, 10,
13, 22 (and container-level 25/26 execution) are closed in an owner-supervised
maintenance window; Gate 14 receives an accepted control strategy; and the
pending owner actions in §6 are confirmed. Local PASS results do not transfer to
the OCI deployment scope.

## Related documents

- [ADR-011](../architecture/adr/ADR-011-adopt-9router-as-servicehub-ai-gateway.md)
- [niner.md](../operations/services/niner.md)
- [9Router Backup and Restore Runbook](../operations/runbooks/9ROUTER-BACKUP-RESTORE.md)
- [TEST-001 Platform Baseline Validation](TEST-001-platform-baseline-validation.md)
