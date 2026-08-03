---
id: ENG-DOCS
status: accepted
owner: engineering
scope:
  - documentation
load_when:
  - documentation_change
  - architecture_change
---

# Documentation Standard

## Source of truth

Repository documentation is authoritative. Chat history is not.

## Required documentation updates

Update documentation when changing:

- architecture;
- domain ownership;
- public contracts;
- persistence/schema;
- setup;
- release process;
- security/privacy behavior;
- agent workflow;
- non-obvious operational procedure.

## ADRs

Use an ADR when a decision is costly to reverse, affects multiple features, introduces a framework or changes a security/persistence/public-contract boundary.

## Code comments

Document local why. Do not duplicate architecture documents inside code.

## Diagrams

Mermaid source is preferred for version-controlled diagrams. A diagram must match current code or be marked target/future.

## Staleness

Every major document has:

- status;
- owner or owning area;
- version/date where useful;
- links to superseding documents.

## AI-generated documentation

AI output must be checked against code and accepted decisions. Plausible but unverified documentation is a defect.
