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
- Riverpod lint via `custom_lint`;
- no ignored analyzer warnings without reason.

## Custom boundary checks

Create a repository script, initially simple and deterministic, that fails CI for:

1. `supabase_flutter` imports below `features/**/presentation`.
2. Flutter imports below `features/**/domain`.
3. Riverpod imports below `features/**/domain`.
4. Imports of another feature's `/presentation/`.
5. Imports of another feature's `/data/`.
6. Feature-domain imports from `core`.
7. direct `GetIt` or `injectable` dependencies.
8. raw `context.go('/...')` patterns outside routing infrastructure.
9. production `print()` calls.

A later custom lint package is justified only if scripts become too weak.

## CI gates

Every pull request:

```text
dart format --output=none --set-exit-if-changed .
flutter analyze
dart run custom_lint
flutter test
architecture boundary script
generated-code consistency check
```

Critical backend migrations additionally run Supabase policy/function tests.

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
dart format --output=none --set-exit-if-changed .
flutter analyze
dart run custom_lint
flutter test --coverage
dart run tool/check_architecture.dart
dart run tool/check_generated_code.dart
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
