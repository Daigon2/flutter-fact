---
id: ARCH-STRUCTURE
status: accepted
owner: architecture
scope:
  - flutter
load_when:
  - new_feature
  - file_placement
  - refactoring
---

# Target Folder Structure

```text
lib/
├── main.dart
├── app/
│   ├── bootstrap/
│   │   ├── bootstrap.dart
│   │   ├── app_environment.dart
│   │   └── provider_observers.dart
│   ├── routing/
│   │   ├── app_router.dart
│   │   ├── route_guards.dart
│   │   ├── route_refresh.dart
│   │   └── routes/
│   ├── shell/
│   ├── theme/
│   ├── localization/
│   └── fact_app.dart
│
├── core/
│   ├── error/
│   ├── result/
│   ├── logging/
│   ├── time/
│   ├── identifiers/
│   ├── geo/
│   └── widgets/
│
├── services/
│   ├── analytics/
│   ├── crash_reporting/
│   ├── feature_flags/
│   ├── notifications/
│   ├── permissions/
│   ├── location/
│   ├── deep_links/
│   └── background_tasks/
│
└── features/
    ├── identity/
    ├── city/
    ├── facts/
    ├── discovery/
    ├── collection/
    ├── progression/
    ├── challenges/
    ├── tours/
    ├── profile/
    └── settings/
```

## Large feature template

```text
features/facts/
├── presentation/
│   ├── pages/
│   ├── widgets/
│   ├── notifiers/
│   ├── state/
│   ├── routes/
│   └── formatting/
├── application/
│   ├── use_cases/
│   └── services/
├── domain/
│   ├── entities/
│   ├── value_objects/
│   ├── repositories/
│   ├── failures/
│   └── policies/
└── data/
    ├── repositories/
    ├── datasources/
    │   ├── remote/
    │   └── local/
    ├── dto/
    ├── mappers/
    └── sync/
```

## Small feature template

```text
features/settings/
├── presentation/
│   ├── pages/
│   ├── widgets/
│   └── notifiers/
└── data/
    └── settings_store.dart
```

## Placement rules

- `app/shell/` holds the app-wide chrome: the bottom navigation shell, the tab
  bar and the slot reserved for the mini player. It is app-wide composition in
  the sense of `architecture-overview.md` §5, not routing infrastructure, so it
  does not belong under `app/routing/`. It contains no business rules and no
  feature imports; feature pages are supplied through the router.

- Riverpod providers that construct data/application dependencies live near the implementation they expose.
- Feature UI providers live in `presentation`.
- Repository interfaces live in `domain/repositories`.
- Repository implementations live in `data/repositories`.
- DTOs never leave the data layer.
- Cross-feature reusable UI enters `core/widgets` only after proven reuse and if it contains no business semantics.
- App-wide vendor adapters live under `services`.
- Feature-specific analytics event definitions live with the feature; the analytics transport lives under `services/analytics`.
- Generated files remain adjacent to their source files and are committed only if the project policy requires it.
