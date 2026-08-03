---
id: DEC-OPEN
status: accepted
owner: architecture
scope:
  - decisions
load_when:
  - planning
  - architecture_review
---

# Open Architecture Decisions

| ID | Decision | Impact | Decide no later than | Dependencies |
|---|---|---|---|---|
| OD-001 | Guest mode and guest-to-account migration | Product, identity, sync | Before auth implementation | Product |
| OD-002 | Local database technology | Offline, migrations, performance | Before offline collection implementation | Query spike |
| OD-003 | Detailed sync protocol and outbox schema | Correctness | Before offline writes | OD-002 |
| OD-004 | Result/failure implementation | All layers | Before first production feature | Small code spike |
| OD-005 | `freezed` usage boundary | Models/build tooling | Before model standardization | Build workflow |
| OD-006 | Analytics vendor and taxonomy | Privacy/product metrics | Before beta | Consent design |
| OD-007 | Crash-reporting vendor | Operations/privacy | Before beta | Environment setup |
| OD-008 | Push provider and campaign tooling | Engagement | Before push feature | Product roadmap |
| OD-009 | Map tile and media caching | Offline/storage cost | Before downloadable tours | Map provider terms |
| OD-010 | Background sync strategy | Offline reliability | Before background sync | iOS/Android constraints |
| OD-011 | Progression economy and reward ledger | Domain correctness | Before gamification implementation | Product |
| OD-012 | Account deletion/export workflow | Compliance | Before public launch | Backend schema |
| OD-013 | Content language fallback | UX/data model | Before second language/city | Content pipeline |
| OD-014 | Universal link/app link domains | Routing/release | Before external sharing | Domain ownership |

## Decision policy

An open decision becomes an ADR when it:

- adds or replaces a framework;
- changes persistence or synchronization semantics;
- affects multiple features;
- changes security/privacy behavior;
- changes a public route or backend contract;
- creates a long-lived constraint.
