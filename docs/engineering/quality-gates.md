---
id: ENG-GATES
status: accepted
owner: engineering
scope:
  - ci
  - quality
load_when:
  - task_completion
  - ci_change
  - architecture_enforcement
---

# Quality Gates and Architecture Enforcement

## Static analysis

Required baseline:

- Dart analyzer with strict language options;
- Flutter lint baseline;
- no ignored analyzer warnings without reason.

### Accepted deviation: no Riverpod lint

`riverpod_lint` via `custom_lint` was part of this baseline. It is currently not
installable, so the requirement is suspended rather than met. Verified in an
isolated copy of the project with four resolution attempts on Dart 3.12.1 and
Flutter 3.44.1:

```text
riverpod_lint 3.1.8          requires analyzer ^13.0.0
flutter_test (from the SDK)  pins test_api 0.7.11 and matcher 0.12.19 and thereby
                             forces test into a range with analyzer >=8.0.0 <13.0.0
supabase_flutter             blocks the escape via older test versions
                             (supabase 2.16.1 -> realtime_client 2.13.0 ->
                             web_socket_channel ^3.0.3)
riverpod_lint >=3.1.4-dev.1  requires analyzer_plugin ^0.14.0
custom_lint >=0.7.4          requires analyzer_plugin ^0.13.0  (conflict)
```

The conflict sits between the pinned Flutter SDK, `supabase_flutter` and the
lint packages. No change to FACT code resolves it. Two details, because they
have been stated wrongly before: `riverpod_annotation` is not part of this
project and is not involved, and `custom_lint` on its own does resolve. Without
a plugin it checks nothing, which is why it is not in the pipeline either.

Partial replacement: `tool/check_architecture.dart` runs the boundary checks
below and additionally rules 7, 12 and 13 from
`../architecture/dependency-rules.md`, which `riverpod_lint` would have caught
in part. It is not a substitute for the Riverpod-specific rules. Currently
unenforced by any tool, and therefore review-only:

- `notifier_extends`;
- `avoid_public_notifier_states`;
- `provider_dependencies`;
- `scoped_providers_should_specify_dependencies`;
- `unsupported_provider_value`.

Resumption condition: the requirement returns to the baseline as soon as
`custom_lint` and `riverpod_lint` can both be added to `dev_dependencies` and
`flutter pub get` resolves them against the unchanged `pubspec.yaml`, without a
`dependency_overrides` entry. That needs two things at once: the `flutter_test`
version shipped with the pinned Flutter SDK must permit a `test` version whose
`analyzer` constraint covers the `analyzer` major `riverpod_lint` requires, and
`custom_lint` and `riverpod_lint` must agree on one `analyzer_plugin` major.
Re-check after every Flutter SDK upgrade and after every major upgrade of
`supabase_flutter`. When it resolves, add the packages, put the baseline entry
back and delete this section.

## Custom boundary checks

A repository script, kept simple and deterministic, fails CI for:

1. `supabase_flutter` imports below any `presentation/`.
2. Flutter imports below any `domain/`.
3. Riverpod imports below any `domain/`.
4. Imports of a feature's `/presentation/` from outside that feature.
5. Imports of a feature's `/data/` from outside that feature.
6. Feature-domain imports from `core`.
7. direct `GetIt` or `injectable` dependencies.
8. raw `context.go('/...')` patterns outside routing infrastructure.
9. production `print()` calls.
10. `presentation` importing a `data` directory, including its own feature's.
11. a feature importing `map/presentation` or `map/data`.
12. `webview_flutter` outside `lib/map/presentation/avatar/`.
13. `maplibre_gl` outside `lib/map/`, `geolocator` outside
    `lib/services/location/`, `shared_preferences` outside
    `lib/services/preferences/`.
14. Anything in the shared kernel `lib/kernel/` that is not `dart:`, the kernel
    itself or a vetted pure-Dart package.

Checks 1 to 3 read "below `features/**/...`" until 2026-08-28. They now apply to
every `presentation`, `domain`, `application` and `data` segment below `lib/`.
The old wording was not a shortening: three of the four layer patterns literally
required `lib/features/`, and a file `lib/map/domain/x.dart` importing Flutter,
Riverpod and Supabase passed the gate, measured on throwaway files. The same
asymmetry hit checks 4 and 5, which were skipped entirely for files outside
`lib/features/`.

Check 4 and 5 exempt `lib/app/`, because the dependency table gives app
composition "All public feature entry points and services". They also exempt
`lib/core/`, where the wider ban in rule 11 already reports the same import with
a more precise message.

Check 12 has no trigger today: `webview_flutter` is not a dependency of this
project and needs a separate approval (E-10). The rule exists ahead of the
package on purpose, because "encapsulate behind a clear interface" without an
enforced line is an intention, not a boundary.

**Check 6 gained an exception on 2026-08-31, and check 14 is its counterweight.**
A feature domain may now import `package:fact_app/kernel/`, the shared kernel
(ADR-008, rule 23). That is the only loosening: one additional permitted import
path, granted because the strictness had been paid for three times and the third
case, an enumeration with meaning, could have diverged without a failing test.

Check 14 is why the loosening is not a hole. It is an **allow-list** and not a
ban list, for the same reason check 6 is: a vendor package nobody anticipated has
to be rejected rather than slip through. Everything in the kernel is visible to
every domain, so a foreign import there would be the most expensive one in the
tree. Both directions are enforced, and the four admission rules for what may
live in the kernel are in ADR-008, not here.

`tool/check_architecture.dart` implements these checks. Its own black-box suite
is `test/tool/check_architecture_test.dart`: every check has a probe that must
be reported and, where a too-wide implementation would report correct code, a
counter-probe that must stay silent. A later custom lint package is justified
only if scripts become too weak.

## CI gates

Every pull request:

```text
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/check_architecture.dart
```

Critical backend migrations additionally run Supabase policy/function tests.

### Drift checks for generated files

Three tools verify that checked-in generated files still match their source.
All three must exit 0 before a change is merged:

```text
dart run tool/generate_i18n.dart --check
dart run tool/bake_map_style.dart --check
dart run tool/generate_curated_data.dart --check
```

They are **not** part of the CI gate list above, and that is a limitation, not
an oversight: `generate_i18n` and `generate_curated_data` read the PWA in the
read-only repository, which CI has no access to. Both exit 2 with instructions
when the source is unreachable. `flutter test` runs without it, because the
generated files are versioned. Until CI has the source, these three run
locally, and a hand-edited generated file would pass CI.

Two gates are absent from the CI list on purpose and must not be reported as
running:

- Riverpod lint, see "Accepted deviation: no Riverpod lint" above;
- a single generated-code consistency check. There is no
  `tool/check_generated_code.dart`; the three tools above cover that ground
  file by file instead.

## Pull request architecture section

Each PR should state:

- owning feature;
- affected layers;
- new dependency or none;
- persistence/schema changes;
- offline implications;
- analytics/privacy implications;
- ADR impact;
- tests added.

## Review triggers

An architecture review is mandatory when a change:

- introduces a package used across multiple features;
- adds a cross-feature dependency;
- bypasses a repository;
- introduces local persistence;
- changes sync semantics;
- adds background execution;
- changes authentication or authorization;
- creates a new top-level directory;
- violates a current ADR.

## CI pipeline baseline

Minimum pull-request pipeline:

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --coverage
dart run tool/check_architecture.dart
# Still missing, do not add before it exists or resolves:
#   dart run custom_lint              (see the accepted deviation above)
#   dart run tool/check_generated_code.dart  (script not written yet)
```

Conditional jobs:

- integration tests for critical-flow changes;
- Android build for native/config changes;
- iOS build for native/config changes;
- Supabase migration/RLS tests for backend changes;
- golden tests for design-system changes;
- dependency/security scan;
- release artifact build on protected tags/branches.

CI should fail fast on formatting/analyzer errors before expensive builds.
