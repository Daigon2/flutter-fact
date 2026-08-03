---
id: ARCH-QUALITY
status: accepted
owner: architecture
scope:
  - system
load_when:
  - architecture_review
  - tradeoff
---

# Quality Attributes

## Priorities

### 1. Maintainability

A developer or agent must locate feature behavior quickly and understand its dependencies without tracing global mutable state.

### 2. Correctness

Collection, progression, challenges and rewards must remain consistent under retries, offline use and duplicated requests.

### 3. Testability

Domain and use-case behavior must run without Flutter bindings, network or Supabase.

### 4. Product iteration speed

The architecture must support fast experiments without forcing every small feature into four layers.

### 5. Multi-city scalability

Adding a city should be primarily data/configuration work, not a fork of feature logic.

### 6. Privacy and security

Location, account and behavioral data require minimization, backend authorization and safe telemetry.

### 7. Reliability

Critical user actions must expose pending/failure states and recover safely.

### 8. Performance

Map interaction, content loading and image rendering must remain smooth on representative mid-range devices.

### 9. Accessibility and localization

Tourists and locals require robust language, text scaling and accessible navigation.

### 10. AI change safety

Rules, ownership and contracts must make automated changes bounded and reviewable.

## Accepted trade-offs

- More explicit mapping code in exchange for clean boundaries.
- Some local duplication in exchange for reduced premature coupling.
- Selective rather than universal offline support.
- Supabase coupling inside the data layer in exchange for delivery speed.
- Code generation where it removes errors, despite build-step overhead.
- A modular monolith rather than packages/micro-frontends until team scale demands otherwise.
