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
│   ├── bootstrap.dart
│   ├── app.dart
│   ├── onboarding/
│   ├── routing/
│   │   ├── app_router.dart
│   │   ├── route_guards.dart
│   │   ├── route_refresh.dart
│   │   └── routes/
│   ├── shell/
│   ├── theme/
│   └── localization/
│
├── core/
│   ├── anchors/
│   ├── async/
│   ├── diagnostics/
│   ├── error/
│   ├── result/
│   ├── logging/
│   ├── time/
│   ├── identifiers/
│   ├── geo/
│   └── widgets/
│
├── services/
│   ├── supabase/
│   ├── analytics/
│   ├── crash_reporting/
│   ├── feature_flags/
│   ├── notifications/
│   ├── permissions/
│   ├── location/
│   ├── preferences/
│   ├── deep_links/
│   └── background_tasks/
│
├── map/
│   ├── domain/
│   ├── application/
│   └── presentation/
│       └── avatar/
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
    ├── puzzles/
    ├── profile/
    └── settings/
```

This tree is the target, not an inventory. Most entries do not exist yet. Four
entries were corrected on 2026-08-28 because the document named something the
code names differently, which is worse than a gap: `app/bootstrap.dart` is a
file and not a folder, the root widget lives in `app/app.dart` and not in
`app/fact_app.dart`, and `core/async/`, `core/diagnostics/` and
`services/supabase/` are built and were missing here. `app/onboarding/` and
`core/anchors/` come from E-26 and E-27 in `REBUILD_STATUS.md`. `map/` was added
on 2026-08-28 with the map host decision; `map/application/` followed on
2026-08-29 with step 12 and is the first `application/` folder in the
repository. It carries composition, not use cases, see
`architecture-overview.md` §7.

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

- `core/anchors/` owns the anchor mechanism only. Anchor identifiers belong to
  the surface that draws the widget, never to `core`: tab anchors live in
  `app/shell/`, map anchors in `features/discovery/presentation/`. This is E-27
  in `REBUILD_STATUS.md`. The check script cannot enforce it: `_checkCoreConcepts`
  in `tool/check_architecture.dart` splits the path and never reads the file, so
  a `lib/core/anchors/anchor_ids.dart` full of domain identifiers would pass the
  gate. Review enforces this rule, not the machine.

- `map/` is the map host: app and UI infrastructure that belongs to no business
  domain. It owns the map surface and the camera. Features hand it intentions
  through `map/domain` and never import `map/presentation` or `map/data`
  (rule 18 in `dependency-rules.md`). The 3D avatar stays behind
  `map/presentation/avatar/`, and `webview_flutter` may appear nowhere else
  (rule 19). Unlike `core/anchors/` above, both rules are machine-enforced.

- `services/location/` is the location provider, the second home directory of
  this kind. `domain-map.md` §3 lists the geolocation provider among the
  capabilities that are not business domains, so it belongs here and not in a
  feature. The whole `geolocator` package family may appear nowhere else
  (rule 21): `Position` and `LocationAccuracy` live in
  `geolocator_platform_interface`, so a ban on the main name alone would leave
  the most obvious detour open. As with `map/`, the rule checks the import and
  never the content. A service that hands the user's whereabouts somewhere it
  does not belong passes it; that is E-07 and stays a review concern.

- `services/preferences/` is the device key-value store, the third home
  directory of this kind, added on 2026-08-31 with `shared_preferences` itself.
  The whole package family may appear nowhere else (rule 22), by prefix and for
  the same reason as rule 21: `SharedPreferencesStorePlatform` lives in
  `shared_preferences_platform_interface`, which is the obvious detour. The
  contract the rest of the app sees is `KeyValueStore` in `core/preferences/`,
  the same split as `core/diagnostics` and `services/diagnostics`. Five stores
  ride on it: first launch, tour, audio mode, language and the running hunt.

- `map/application/map_host_providers.dart` holds the two providers that give
  access to the map host, and the boundary between them is drawn by **type**,
  not by convention:

  | Provider | Type | Who reads it |
  |---|---|---|
  | `mapHostProvider` | `Provider<MapHost>` | any feature |
  | `mapHostRegistryProvider` | `Provider<MapHostRegistry>` | only `map/presentation/` |

  Both return the same object. There are two because `MapHost` has no `attach`:
  a feature that only sees `mapHostProvider` cannot register itself as the host,
  and that is enforced by the compiler rather than by a comment or a new check
  in `tool/check_architecture.dart`.

  The registry is a plain mutable object and deliberately not a `Notifier`.
  Attaching happens in `initState` and detaching in `dispose` of the map
  widget, and Riverpod forbids provider mutation in both
  (`flutter_riverpod-3.4.2/lib/src/core/provider_scope.dart:381-385`). Routing
  it through `addPostFrameCallback` would open a window in which the map is
  already on screen while every intent still falls into the void. This is the
  same decision, for the same reason, as `core/anchors/anchor_registry.dart`,
  and it is not the manual singleton registry ADR-005 rejects: the provider
  creates and owns the object, and it dies with the scope.

- Riverpod providers that construct a `data` or `application` implementation
  live next to that implementation, and **only app composition reads them**.
  They are not an access path for higher layers and cannot become one:
  `presentation` must not import `data` (rule 17), so a provider declared in
  `data` is unreachable from the UI by construction. Higher layers read a
  provider typed on the **domain contract**, placed with the contract or in
  `presentation`, with a safe default and an override from `app/bootstrap.dart`.
  The sentence used to read "live near the implementation they expose", which
  both readings satisfied, and both are in the code. Resolved on 2026-08-28 as
  E-32; the worked example and the two code sites are in `dependency-rules.md`,
  section "Providers that construct dependencies".

- Feature UI providers live in `presentation`.
- Repository interfaces live in `domain/repositories`.
- Repository implementations live in `data/repositories`.
- DTOs never leave the data layer.
- Cross-feature reusable UI enters `core/widgets` only after proven reuse and if it contains no business semantics.
- App-wide vendor adapters live under `services`.
- Feature-specific analytics event definitions live with the feature; the analytics transport lives under `services/analytics`.
- Generated files remain adjacent to their source files and are committed only if the project policy requires it.
