# ServiceHub Agent Guidance

- `docs/` is the authoritative documentation system; repository implementation remains the source of truth for behaviour.
- Update relevant documentation in the same change as the implementation.
- Record architecture decisions as ADRs and significant cross-cutting proposals as RFCs.
- Require test evidence and release notes before describing work as tested, released, or completed.
- Never invent completed work, approvals, runtime results, recovery objectives, ownership, hostnames, or secret values.
- Preserve stable document IDs, use controlled metadata, and update `updated` dates.
- Add each new record to its appropriate index and maintain relative links.
- Use Australian English where natural and standard Markdown with one H1 per document.
- Validate metadata, unique IDs, index coverage, internal links, heading hierarchy, and secrets before review.
- Do not use the Forgejo Wiki as the source of truth; external portals link to this repository.
