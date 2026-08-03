---
id: ADR-002
status: accepted
owner: architecture
scope:
  - decision
load_when:
  - relevant_decision
---

# ADR-002: Pragmatic Feature-First Clean Architecture

Status: **Accepted**  
Date: 2026-07-19

## Context

FACT needs clear feature ownership and testable business logic without forcing small screens into excessive layers.

## Decision

Organize by feature first. Inside a feature, add presentation, application, domain and data layers only as complexity requires.

## Alternatives considered

- Technical layer-first architecture
- Strict four-layer architecture for every feature
- Unstructured screen/service folders

## Consequences

- Changes are easier to localize.
- Small features remain lightweight.
- Larger features gain explicit boundaries.
- Teams must consciously promote features as complexity grows.

## Rules

- Architecture grows with complexity.
- Business concepts never move into core for convenience.
- Domain remains technology-independent.
- Cross-feature communication uses contracts, IDs, events or projections.

## Review triggers

- Feature boundaries repeatedly cause duplication or cycles.
- Team size or package ownership requires physical package separation.
- Build times or repository scale require modular packages.
