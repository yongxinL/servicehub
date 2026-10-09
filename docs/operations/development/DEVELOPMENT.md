---
project: ServiceHub
project_code: SVCHUB
document_type: DEV
document_id: DEVELOPMENT
title: ServiceHub Development Workflows
version: "1.0"
status: Active
lifecycle_stage: Development
owner: George Li
maintainer: George Li
created: 2026-10-09
updated: 2026-10-09
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

Development-side workflows for working with the ServiceHub repository: encrypted file management, the local development/administration flow, and documentation contribution.

## Managing Encrypted Files (git-crypt)

Self-signed certificates for staging are stored **encrypted** in `shared/traefik/advanced/selfsigncert/` using [git-crypt](https://github.com/AGWA/git-crypt). They appear as binary blobs to anyone without the key, making it safe to commit them. The deploy workflow decrypts them in the runner checkout before syncing the working tree to the remote server.

### One-time Setup (new repository)

```bash
# 1. Initialise git-crypt in the repo (only needed once)
git-crypt init

# 2. Export the symmetric key — back this up securely (password manager, etc.)
#    Losing this key means losing access to all encrypted files permanently.
git-crypt export-key ./servicehub.key

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
base64 -i servicehub.key | tr -d '\n'   # macOS / BSD
base64 -w0 servicehub.key               # Linux (GNU coreutils)
```

Copy the output into Forgejo → Repository → Settings → Actions → Secrets as **`GIT_CRYPT_KEY`**.

### Unlock on a New Machine

```bash
git-crypt unlock ./servicehub.key
```

## Local Development and Administration Flow

The repository documents a local Compose flow:

1. Install prerequisites listed in the [Installation guide](../INSTALLATION.md#prerequisites).
2. Run `bash scripts/setup.sh` to create or merge `.env`.
3. Review environment values without copying secret values into documentation.
4. Validate configuration with `docker compose config`.
5. Start selected services or the full stack using `docker compose up -d`.
6. Inspect health and logs before routing or deployment changes are considered valid.

This flow is Confirmed from repository commands; local execution results are `Not yet verified`.

## Contributing

1. Read the relevant index and template.
2. Use the next unused stable ID and current date.
3. Add or update the document in the same pull request as its implementation change.
4. Label claims as Confirmed, Inferred, Proposed, or TBD.
5. Link to relative repository paths and check every link.
6. Update `updated` and add the record to its index.
7. Never copy secrets, private keys, recovery material, production hostnames, or unverified results.
8. Request owner review for charter, requirements, ADR statuses, RFC decisions, phase completion, and releases.

## Related

- When the git-crypt key is needed during installation: [Installation](../INSTALLATION.md)
- How the deploy workflow uses the key: [Deployment (Forgejo Actions)](../DEPLOYMENT.md)
- Deployment scope and architecture model: [Deployment architecture](../architecture/DEPLOYMENT-ARCHITECTURE.md)
