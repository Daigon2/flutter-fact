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
4. Domain must not import vendor SDKs: routing, storage, analytics, and
   equally the map, location and WebView packages. The script has enforced the
   wider reading since rules 19 to 21 were added; this line now says so. In a
   domain the rule 4 message is the correct one, and the home-directory rules
   19 to 21 stay silent there: they point at a directory a domain must never
   reference.
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
20. `maplibre_gl` may only be imported below `lib/map/`.
21. `geolocator` and its platform packages may only be imported below `lib/services/location/`.
22. `shared_preferences` and its platform packages may only be imported below `lib/services/preferences/`.

Rules 19 to 22 give a vendor SDK one home directory. They are not a ban, they
are an assignment: the map SDK belongs to the map host, the geolocation SDK
belongs to the location service, and the WebView belongs to the avatar. Rule 4
already keeps the map and geolocation SDKs out of every `domain` directory, but
only there, so before these rules a `presentation` or `app` file could reach the
vendor package directly. Measured on 2026-08-28 for `maplibre_gl` and on
2026-08-29 for `geolocator`, both with throwaway probes that passed the gate
with exit code 0.

Rule 21 follows `domain-map.md` §3, which lists the geolocation provider among
the supporting technical capabilities and not among the business domains, in the
same list as map rendering. The rule enforces that placement, it does not decide
it. Rule 20 was enforced in `tool/check_architecture.dart` from 2026-08-28 and
is written down here only now.

Rule 22 was added on 2026-08-31, together with the package itself.
`tool/check_architecture.dart` had until then carried `shared_preferences` as a
**deliberate** gap, with two stated conditions: the package was not in
`pubspec.yaml`, and no accepted decision named a home directory for it. Both
conditions fell away in the same change, so the rule enforces a placement
instead of making one. The device store is a supporting technical capability
like the geolocation provider, `lib/features/README.md` assigns vendor adapters
without a surface to `services/`, and the rest of the app sees the
`KeyValueStore` contract in `lib/core/preferences/` and never the package.
Like rules 19 to 21 it names the package family by prefix: the likeliest way
around the adapter is `shared_preferences_platform_interface`, because
`SharedPreferencesStorePlatform` lives there.

All three check the import, not the content. A service that hands the user's
position to somewhere it does not belong passes them, and where the position may
flow is a question for E-07 and stays a review matter.

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
anything outside lib/map -> maplibre_gl
anything outside lib/services/location -> geolocator (and geolocator_*)
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
- `features/facts/data/repositories/supabase_fact_repository.dart` declares a
  provider next to the implementation. It never broke a rule, but until
  2026-08-29 it was called `factRepositoryProvider` and its comment claimed that
  widgets and notifiers read "this provider", which they cannot. **Resolved in
  the step that connects `facts` to the map, as E-32 said it would be:** the
  provider is now called `supabaseFactRepositoryProvider`, only `lib/app/` reads
  it, and the contract-typed provider moved to `features/facts/application/`
  (next bullet). The same wrong sentence stood a second time next to
  `factRemoteDataSourceProvider` and was corrected there as well.
- `map/application/map_host_providers.dart` declares `mapHostProvider` on the
  `MapHost` contract and `mapHostRegistryProvider` on the implementation, both
  returning the same object. This is the **third** case in which neither
  placement from the sentence above works, and the reason is constructive
  rather than stylistic: the contract lives in `map/domain/`, where rule 2
  forbids Riverpod, and `map/presentation/` is unreachable for features under
  rule 18. `map/application/` is the only remaining place, which is why that
  folder exists at all.

  Note what carries the boundary here: the **type** of the provider, not its
  location. `MapHost` has no `attach`, so a feature holding `mapHostProvider`
  cannot register a host even if it tries. Whenever a provider must be readable
  by two layers with different rights, split it by type before splitting it by
  convention.

- `features/facts/application/fact_providers.dart` declares
  `factRepositoryProvider` on the `FactRepository` contract with an inert
  default; `app/bootstrap.dart` overrides it with the Supabase implementation.
  This is the **fourth** case, and it is the same constructive squeeze as the
  third: the contract lives in `features/facts/domain/`, where rule 2 forbids
  Riverpod, and `features/facts/presentation/` is unreachable for the consumer
  `features/discovery` under rule 8. `application/` is the only remaining place,
  and rule 10 names exactly that as a legal way across a feature boundary.

  Note the difference to the first bullet: `authRepositoryProvider` may sit in
  `identity/presentation/` because its only consumer is that same feature. As
  soon as a **second** feature consumes a contract, the provider has to move to
  `application/`. Placement follows the consumer, not taste.

## Exceptions

An exception requires:

- a written reason;
- a narrow API;
- an owner;
- a removal or review condition;
- an ADR if the exception changes a general rule.
