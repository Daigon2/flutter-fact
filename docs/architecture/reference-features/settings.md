---
id: ARCH-REF-SETTINGS
status: accepted
owner: architecture
scope:
  - flutter
load_when:
  - reference_feature
---

# Reference Feature: Settings

## Purpose

Demonstrates the smallest acceptable feature architecture.

## Structure

```text
features/settings/
├── presentation/
│   ├── pages/settings_page.dart
│   ├── notifiers/settings_notifier.dart
│   └── state/settings_state.dart
└── data/
    └── settings_store.dart
```

## Responsibilities

`SettingsState` contains immutable device/app preferences.

`SettingsNotifier`:

- loads local preferences;
- updates preferences;
- persists through `SettingsStore`;
- exposes no business rules.

`SettingsStore` wraps the selected local preference mechanism.

## Why no domain/application layer?

The feature has no meaningful domain invariants or multi-step workflows. Adding interfaces and use cases would create ceremony without protecting complexity.

## Promotion triggers

Add a domain layer if:

- settings synchronize across accounts;
- privacy preferences gain legal/business invariants;
- policies depend on city/account state.

Add an application layer if:

- updating a setting coordinates multiple services;
- changes require migration, remote write or rollback.
