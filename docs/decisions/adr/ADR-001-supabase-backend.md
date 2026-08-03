---
id: ADR-001
status: accepted
owner: architecture
scope:
  - decision
load_when:
  - relevant_decision
---

# ADR-001: Supabase as Backend

Status: **Accepted**  
Date: 2026-07-19

## Context

FACT requires authentication, relational data, storage and server-side authorization while being developed by a small team. An existing Supabase backend and content pipeline already exist.

## Decision

Use Supabase as the production backend for v1 and the foreseeable product phase. Flutter accesses Supabase only through data-layer adapters and repository implementations.

## Alternatives considered

- Custom backend from the start
- Firebase
- Backend-agnostic abstraction over every Supabase capability

## Consequences

- Lower operational burden and faster delivery.
- Supabase-specific code is accepted in the data layer.
- Row Level Security and server validation are mandatory.
- Repositories protect higher layers from transport/schema coupling.

## Rules

- No direct Supabase use in widgets, notifiers or domain code.
- Schema changes are versioned migrations.
- Client checks are never authorization.
- Complex trusted reward/security logic runs server-side.

## Review triggers

- Supabase blocks required functionality.
- Cost, performance, compliance or availability becomes unacceptable.
- Team scale justifies a dedicated backend.
- Domain workflows cannot be safely expressed with current backend capabilities.
