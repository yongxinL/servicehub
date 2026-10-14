# Governance

## Purpose
Project-level governance records: which Nexora release is adopted, where truth lives, approved exceptions, and which tools are permitted and enabled.

## Authority
These records are authoritative for project governance configuration. They do not restate the central manual; they reference it at the adopted tag.

## Contents

| Record | Authoritative for |
|---|---|
| [governance-adoption.md](governance-adoption.md) | Adopted release, owner, mode, agent, adoption state |
| [source-of-truth-register.md](source-of-truth-register.md) | Information category to location mapping |
| [documentation-exceptions.md](documentation-exceptions.md) | Temporary and standing exceptions |
| [approved-tooling.md](approved-tooling.md) | Tools permitted in this project |
| [tooling-adoption-register.md](tooling-adoption-register.md) | Tools actually configured or enabled |

## Artifact triggers
Updated at adoption, at governance upgrades, on exceptions, on tool adoption or removal, and on ownership or agent changes.

## Naming and identifiers
Fixed filenames; no identifiers. Exceptions use local `EXC-NNN` labels within the exceptions record.

## Status expectations
`governance-adoption.md` carries the adoption state (Not Adopted, Adoption in Progress, Adopted with Exceptions, Adopted, Retired).

## Index-entry requirements
This index lists the five records above; no other files belong here.

## Relationship to other artifacts
Referenced by `AGENTS.md`, `CENTRAL-GOVERNANCE-REFERENCE.md`, and every area index.

## Current scaffold state
The five records are present as customizable scaffolds until adoption customization is complete.
