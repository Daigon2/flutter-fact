# Start Here

FACT is a gamified city-discovery Flutter application for iOS and Android. Tourists are the marketing focus, while the product serves tourists and locals. The first city is expected to be Munich, and the system must support rapid multi-city expansion.

## For a new contributor

1. Read `docs/product/product-overview.md`.
2. Read `docs/architecture/architecture-overview.md`.
3. Read `docs/engineering/engineering-principles.md`.
4. For a concrete task, follow `docs/ai/context-routing.md` rather than loading every document.

## Repository knowledge map

- `docs/product/` — user value, scope and journeys.
- `docs/architecture/` — boundaries, domains and data flow.
- `docs/decisions/` — accepted ADRs and unresolved choices.
- `docs/engineering/` — implementation and quality rules.
- `docs/operations/` — runtime and release procedures.
- `docs/ai/` — Claude context, delegation and escalation.
- `.claude/` — executable agents, skills, rules and hooks.

## Current foundational decisions

- Supabase backend.
- Pragmatic feature-first Clean Architecture.
- Riverpod 3 for state and DI.
- Typed `go_router` navigation.
- Selective offline capability by feature.

## Legacy code

Proof-of-concept web or Flutter code is a behavioral reference only. New production code follows the accepted architecture and standards.
