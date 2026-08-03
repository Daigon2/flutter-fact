---
id: ARCH-DEPS
status: accepted
owner: architecture
scope:
  - flutter
  - backend
load_when:
  - implementation
  - review
  - refactoring
---

# Dependency Rules

## Allowed layer dependencies

| Source | May depend on |
|---|---|
| Presentation | Application, Domain, narrowly scoped Core |
| Application | Domain, narrowly scoped Core |
| Domain | Dart SDK and approved pure-Dart primitives only |
| Data | Domain, Core technical primitives, vendor SDKs |
| App composition | All public feature entry points and services |
| Services | Vendor SDKs, Core contracts; domain only through explicit adapters |
| Core | No feature domain |

## Hard rules

1. Domain must not import Flutter.
2. Domain must not import Riverpod.
3. Domain must not import Supabase.
4. Domain must not import routing, storage or analytics SDKs.
5. Presentation must not call Supabase directly.
6. Presentation must not call local database APIs directly.
7. Widgets must not instantiate repositories or vendor clients.
8. A feature must not import another feature's `presentation` directory.
9. A feature must not import another feature's `data` directory.
10. Cross-feature access must use a public domain/application contract or an app-level composition adapter.
11. Core must not contain Fact, Tour, Challenge, Collection, Profile or Progression concepts.
12. Notifiers must not navigate directly.
13. Repository interfaces must not return DTOs, JSON maps or `AsyncValue`.
14. Data sources must not return presentation models.
15. Business rules must not depend on localization strings.
16. Backend security must not rely solely on client checks.

## Import policy

Preferred:

```text
presentation -> application -> domain
data -----------------------> domain
app -> feature public entry points
```

Forbidden:

```text
domain -> data
domain -> presentation
data -> presentation
feature A presentation -> feature B presentation
core -> any feature
```

## Exceptions

An exception requires:

- a written reason;
- a narrow API;
- an owner;
- a removal or review condition;
- an ADR if the exception changes a general rule.
