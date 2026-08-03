---
id: ARCH-INDEX
status: accepted
owner: architecture
scope:
  - architecture
load_when:
  - architecture_context
---

# Architecture Documentation

Canonical system structure and boundaries.

Start with `architecture-overview.md`. Load narrower documents only when the task touches them:

- domain ownership → `domain-map.md`
- file placement → `project-structure.md`
- imports and layers → `dependency-rules.md`
- models/repositories → `data-flow.md`
- location, analytics, permissions, localization → `cross-cutting-concerns.md`
- caching and synchronization → `offline-and-sync.md`
- trade-offs → `quality-attributes.md`
- accepted choices → `../decisions/adr/`
