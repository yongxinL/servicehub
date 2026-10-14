---
project: ServiceHub
project_code: SVCHUB
document_type: DEV
document_id: DEVELOPMENT
title: ServiceHub Development Workflows
version: "1.2"
status: Active
lifecycle_stage: Development
owner: project-owner
maintainer: project-owner
created: 2026-10-09
updated: 2026-10-14
tags:
  - servicehub
  - development
  - git-crypt
related_documents:
  - INSTALLATION
  - DEPLOYMENT
  - DEPLOYMENT-ARCHITECTURE
---

# ServiceHub Development Workflows

Development workflows for the ServiceHub repository: managing encrypted files, the local development flow, the change workflow for new features and fixes, and contributing documentation.

## Managing Encrypted Files (git-crypt)

Self-signed certificates for staging are stored **encrypted** in `shared/traefik/advanced/selfsigncert/` using [git-crypt](https://github.com/AGWA/git-crypt). They appear as binary blobs to anyone without the key, making it safe to commit them. The deploy workflow decrypts them in the runner checkout before syncing the working tree to the remote server.

### One-time Setup (new repository)

```bash
# 1. Initialise git-crypt in the repo (only needed once)
git-crypt init

# 2. Export the symmetric key — back this up securely (password manager, etc.)
#    Losing this key means losing access to all encrypted files permanently.
#    Never place the key file inside the repository working tree.
git-crypt export-key ~/secure/servicehub.key

# 3. Verify .gitattributes is present (already included in this repo)
cat .gitattributes
```

`.gitattributes` encrypts every certificate file under the self-signed cert directory:

```
shared/traefik/advanced/selfsigncert/*.pem filter=git-crypt diff=git-crypt
shared/traefik/advanced/selfsigncert/*.key filter=git-crypt diff=git-crypt
shared/traefik/advanced/selfsigncert/*.crt filter=git-crypt diff=git-crypt
shared/traefik/advanced/selfsigncert/*.pfx filter=git-crypt diff=git-crypt
```

### Add Your Staging Certificates

Place your self-signed files in `shared/traefik/advanced/selfsigncert/` matching the names in `shared/traefik/advanced/certificates.yml`, then commit normally:

```bash
cp /path/to/selfcert.pem    shared/traefik/advanced/selfsigncert/
cp /path/to/selfcert.key    shared/traefik/advanced/selfsigncert/
cp /path/to/selfcertCA.crt  shared/traefik/advanced/selfsigncert/
git add shared/traefik/advanced/selfsigncert/
git commit -m "add staging self-signed certificates (encrypted)"
```

git-crypt encrypts the files transparently on commit. Verify with:

```bash
# Should print non-text (encrypted) output — not your cert content
git show HEAD:shared/traefik/advanced/selfsigncert/selfcert.pem | file -
```

### Encode the Key for Forgejo Actions

The deploy workflow needs the key as a Forgejo Actions secret:

```bash
# Encode the binary key as base64 (single line, no trailing newline)
base64 -i ~/secure/servicehub.key | tr -d '\n'   # macOS / BSD
base64 -w0 ~/secure/servicehub.key               # Linux (GNU coreutils)
```

Copy the output into Forgejo → Repository → Settings → Actions → Secrets as **`GIT_CRYPT_KEY`**.

### Unlock on a New Machine

```bash
git-crypt unlock ~/secure/servicehub.key
```

Never place the key file inside the repository working tree.

## Local Development and Administration Flow

The repository documents a local Compose flow:

1. Install prerequisites listed in the [Installation guide](INSTALLATION.md#prerequisites).
2. Run `bash scripts/setup.sh` to create or merge `.env`.
3. Review environment values without copying secret values into documentation.
4. Validate configuration with `docker compose config`.
5. Start selected services or the full stack using `docker compose up -d`.
6. Inspect health and logs before routing or deployment changes are considered valid.

This flow is Confirmed from repository commands; local execution results are `Not yet verified`.

## Change Workflow

### 1. Decide the path

| If the change... | Then |
|---|---|
| Adds or changes behaviour that users or operators can observe (new feature, new service, new integration, changed routing, authentication, backup or data handling) | Follow the full Spec Kit workflow (section 2). |
| Also needs a lasting technical choice (for example a new database, ingress or identity provider) | Write an ADR first, then follow the full Spec Kit workflow. |
| Is a large, costly or hard-to-reverse proposal with several options | Write an RFC first, then ADRs and specifications. |
| Fixes a simple bug with one cause, restoring behaviour that already worked | Use the Spec Kit `bug` extension if it is installed; otherwise use a `fix/` branch with a reviewed commit. |
| Is a typo, formatting, a refactoring with no behaviour change, or a routine dependency or configuration update | Make an ordinary commit on a `docs/` or `chore/` branch. |

If you are unsure, the Project Owner decides and records the reason in the commit message.

### 2. Full Spec Kit workflow

Run the `$speckit-...` commands in Codex from the repository root. Run all git commands yourself. Review the result of each step before starting the next one.

#### Step 1: Create a branch

```bash
git switch main && git pull
git switch -c feat/<short-name>
```

#### Step 2: Specify (what and why, not how)

- Run `$speckit-specify` followed by a description of the feature and the product requirement (`PR-NNN`) it serves.
- Ask the agent to use the next free `SPEC-NNN`, number requirements as `SPEC-NNN-FR-001`, `SPEC-NNN-NFR-001` and `SPEC-NNN-AC-001`, and cite the ADRs that constrain the feature.
- Check that the specification describes behaviour only, contains no design, and that every acceptance criterion can be tested.
- Set the status to **Draft** and add the specification to the specification index (`specs/README.md`; create it with the first specification).
- Commit: `docs(spec): draft SPEC-NNN <title>`

#### Step 3: Clarify

- Run `$speckit-clarify` and answer its questions yourself.
- Check that no ambiguity remains and that failure and security behaviour are stated.
- Set the status to **Approved** and record the approval: `project-owner / owner-self-approval / <date>`.
- Commit: `docs(spec): approve SPEC-NNN`

#### Step 4: Plan (how)

- Run `$speckit-plan`.
- Check that the plan lists the Accepted ADRs it relies on (constitution principle XVI) and adds no new requirements. If the plan needs a new lasting decision, stop and write an ADR first.
- Commit: `docs(spec): approve SPEC-NNN plan`

#### Step 5: Tasks and analysis

- Run `$speckit-tasks`, then `$speckit-analyze`. For high-risk work, also run `$speckit-checklist`.
- Check that every requirement and acceptance criterion maps to a task and that documentation tasks are included.
- Commit: `docs(spec): add SPEC-NNN tasks`

#### Step 6: Go or no-go (your decision; no command)

- Confirm that the specification and plan are approved, no questions are open, risky changes have a rollback route, and every tool the work needs is in the tooling adoption register.
- Set the status to **In Implementation**.
- Commit: `docs(spec): authorize SPEC-NNN implementation`

#### Step 7: Implement

- Run `$speckit-implement`. The agent works task by task and does not commit or deploy.
- After each task, run the validation commands (section 3) and update the documentation listed in section 4.
- Check that each change maps to a task and that the approved specification was not changed.
- Commit in small pieces: `feat(<area>): <change> (SPEC-NNN-FR-00N)`

#### Step 8: Verify (your evidence; no command)

- For each `SPEC-NNN-AC-NNN`, record the evidence (an automated check, a manual result, or "not applicable" with a reason) in a verification summary in the feature's `specs/` folder. Use `docs/templates/verification-summary-template.md`.
- Set the status to **Implemented**.
- Commit: `docs(spec): add SPEC-NNN verification summary`

#### Step 9: Converge and accept

- Run `$speckit-converge` and resolve every difference it reports.
- Accept the work and set the status to **Verified**.

```bash
git add -A
git commit -m "docs(spec): SPEC-NNN verified"
git switch main
git merge --no-ff feat/<short-name>
```

#### Step 10: Release (when you ship)

- Create `docs/releases/<version>.md` from `docs/templates/release-template.md`. List the included `SPEC-NNN` with baseline commits, the verification evidence, the deployment runbook, the rollback route and known issues.
- Approve the release record, then tag the release:

```bash
git tag -a v<version> -m "ServiceHub <version>"
```

### 3. Validation commands

Run these before every commit that changes configuration or documentation:

```bash
docker compose config --quiet
shellcheck scripts/*.sh
python3 ~/Documents/workspaces/nexora-audits/check-links.py
```

The link checker path is local to the Project Owner's machine.

### 4. Documentation to update with a change

| If you change... | Update |
|---|---|
| A service's behaviour or configuration | `docs/operations/services/<service>.md` |
| A deployment, backup, restore or recovery procedure | `docs/operations/runbooks/` |
| Services, ports, hosts or owners | `docs/operations/SERVICE-INVENTORY.md` |
| Environment variables | `env.example` (names and placeholders only, never values) |
| A lasting technical decision | A new ADR in `docs/architecture/adr/` and its index |

### 5. Branch names

| Prefix | Use |
|---|---|
| `feat/<name>` | New feature or service |
| `fix/<name>` | Bug fix |
| `docs/<name>` | Documentation only |
| `chore/<name>` | Maintenance, tooling or governance |

### 6. Full rules

- [Project constitution](../../.specify/memory/constitution.md)
- [Agent instructions](../../AGENTS.md)
- Central Nexora Governance manual, chapters 06 (Specification-Driven Development), 07 (Spec Kit standard) and 26 (validation and quality gates)

## Contributing

1. Read the relevant area index and template.
2. Use the next unused stable ID allocated in the index; use ISO dates (YYYY-MM-DD).
3. Add or update the document in the same commit as its implementation change.
4. Link to relative repository paths; verify every link with the link checker.
5. Update `updated` metadata and add the record to its area index.
6. Never copy secrets, private keys, recovery material, production hostnames, or unverified results.
7. Owner approval required for specifications, ADR status transitions, RFC outcomes, product documents (vision/requirements), and releases.

## Related

- When the git-crypt key is needed during installation: [Installation](INSTALLATION.md)
- How the deploy workflow uses the key: [Deployment (Forgejo Actions)](runbooks/DEPLOYMENT.md)
- Deployment scope and architecture model: [Deployment architecture](../architecture/DEPLOYMENT-ARCHITECTURE.md)
