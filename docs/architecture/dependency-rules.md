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
| Map host (`lib/map/`) | Its own layers under the rules above; only `map/domain` is public |

A feature's `presentation` and `data` directories are private to that feature.
Only app composition under `lib/app/` may read them, which is the row above.
This holds for every caller, not only for another feature: `lib/services/` and
`lib/map/` are bound by it as well.

The map host under `lib/map/` is app and UI infrastructure, not a business
domain. It owns the map surface and the camera; features hand it intentions
instead of steering it, and they see only `map/domain`. Decided on 2026-08-28,
enforced as rule 18. `domain-map.md` §7 stands unchanged: `map` is not an
independent business domain.

## Hard rules

1. Domain must not import Flutter.
2. Domain must not import Riverpod.
3. Domain must not import Supabase.
4. Domain must not import routing, storage or analytics SDKs.
5. Presentation must not call Supabase directly.
6. Presentation must not call local database APIs directly.
7. Widgets must not instantiate repositories or vendor clients.
8. Nobody outside a feature may import that feature's `presentation` directory. App composition under `lib/app/` is the only exception.
9. Nobody outside a feature may import that feature's `data` directory. App composition under `lib/app/` is the only exception.
10. Cross-feature access must use a public domain/application contract or an app-level composition adapter.
11. Core must not contain Fact, Tour, Challenge, Collection, Profile or Progression concepts.
12. Notifiers must not navigate directly.
13. Repository interfaces must not return DTOs, JSON maps or `AsyncValue`.
14. Data sources must not return presentation models.
15. Business rules must not depend on localization strings.
16. Backend security must not rely solely on client checks.
17. Presentation must not import a `data` directory, not even its own feature's. Access runs through application or a domain contract.
18. A feature must not import `map/presentation` or `map/data`. The map host exposes only `map/domain`.
19. `webview_flutter` may only be imported below `lib/map/presentation/avatar/`.

Rule 17 was written down on 2026-08-28 (E-31). It is not new: it has shaped
every feature with a repository since step 9, and `tool/check_architecture.dart`
has enforced it all along. Until then it could only be derived from the allow
list in the table above, where `Data` does not appear in the Presentation row.
The strictest rule of the project existed in a script and in no document, which
is the wrong way round.

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
presentation -> data, including its own feature's data
feature A -> feature B presentation
feature A -> feature B data
anything outside lib/app -> a feature's presentation or data
core -> any feature
feature -> map/presentation
feature -> map/data
anything outside lib/map/presentation/avatar -> webview_flutter
```

`tool/check_architecture.dart` enforces all of these. The layer of a file is
recognized by a path segment named exactly `domain`, `application`,
`presentation` or `data`, anywhere below `lib/`, not only below `lib/features/`.
`lib/map/domain/` therefore carries the same import ban as
`lib/features/tours/domain/`.

## Providers that construct dependencies

A Riverpod provider that constructs a `data` or `application` implementation
lives next to that implementation, and **only app composition reads it**. It is
not an access path for higher layers, and it cannot become one: rule 17 keeps
`presentation` out of `data`, so such a provider is unreachable from the UI by
construction.

Higher layers read a provider that is typed on the **domain contract**. It is
placed with the contract or in `presentation`, carries a safe default, and the
implementation arrives as an override from `app/bootstrap.dart`.

Both readings of this sentence exist in the code, which is why it is spelled out
here (E-32):

- `features/identity/presentation/notifiers/auth_providers.dart` declares
  `authRepositoryProvider` on `AuthRepository` with an inert default;
  `app/bootstrap.dart` overrides it with the Supabase implementation. This is
  the pattern to copy.
- `core/diagnostics/diagnostics_providers.dart` sits next to its contract in
  `core` and is read from `presentation` and from `data`. Also correct: the
  provider is typed on the contract, not on an implementation.
- `features/facts/data/repositories/supabase_fact_repository.dart` declares
  `factRepositoryProvider` next to the implementation. It breaks no rule,
  because nothing in `presentation` reads it and today only tests do. Its own
  comment nevertheless claims that widgets and notifiers read "this provider",
  and they cannot. Tracked in `REBUILD_STATUS.md`; the fix belongs to the step
  that connects `facts` to the map.

## Exceptions

An exception requires:

- a written reason;
- a narrow API;
- an owner;
- a removal or review condition;
- an ADR if the exception changes a general rule.
