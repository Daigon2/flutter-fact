---
id: ARCH-OVERVIEW
status: accepted
owner: architecture
scope:
  - flutter
  - backend
load_when:
  - structural_change
  - new_feature
  - architecture_review
---

# FACT Architecture v1.0

## 1. Purpose

FACT is a gamified urban discovery application for tourists and locals. The application helps users discover nearby facts, explore cities, collect knowledge, complete challenges and tours, and progress through a rewarding experience.

This document defines the target software architecture for the native Flutter application. The former React/PWA application and the existing Flutter proof of concept may be used as behavioral references, but they do not define the target architecture.

## 2. Architectural goals

The architecture optimizes for:

- maintainability by a small team;
- safe AI-assisted development;
- rapid feature delivery without uncontrolled coupling;
- testability of domain and application logic;
- multi-city expansion after the initial Munich launch;
- selective offline capability;
- predictable navigation and deep linking;
- clear ownership of business concepts;
- production readiness for iOS and Android;
- low operational complexity.

## 3. Non-goals

Version 1 does not optimize for:

- microservices;
- independent deployment of client modules;
- extreme global scale before product-market fit;
- a universal offline-first architecture for every feature;
- abstraction over every external package;
- strict ceremonial Clean Architecture in small features;
- web support as a first-class target.

## 4. Architectural principles

### 4.1 Features before technical layers

The repository is organized primarily by business capability. Developers and agents should locate code by asking which feature owns the behavior.

### 4.2 Architecture grows with complexity

A feature starts with the minimum structure that keeps it understandable. Layers are added only when they solve a concrete complexity, testability or ownership problem.

### 4.3 Domain ownership is explicit

Every business concept has one owning domain. Shared business models are not moved into `core` merely to make imports convenient.

### 4.4 Dependencies point inward

Technical implementations depend on domain contracts. The domain never depends on Flutter, Riverpod, Supabase, routing, persistence or analytics.

### 4.5 Data sources are implementation details

Widgets and notifiers do not know whether data came from Supabase, a local database, memory or a cache.

### 4.6 One source of truth per data category

For each data category, the owning repository defines the authoritative source and synchronization behavior.

### 4.7 Explicit over magical

Dependencies, mappings, side effects and feature boundaries should be easy to find and reason about. Hidden service locators and implicit cross-feature state changes are forbidden.

### 4.8 Readability before abstraction

A little duplication is preferable to a premature shared abstraction that couples unrelated features.

### 4.9 AI changes must be reviewable

The architecture should make an agent's change surface obvious. A feature change should normally remain inside one feature plus explicitly shared infrastructure.

### 4.10 Decisions can be revisited

ADRs are current decisions, not permanent dogma. Each ADR defines review triggers.

## 5. High-level structure

```text
Flutter application
│
├── app/
│   ├── bootstrap
│   ├── routing
│   ├── theme
│   ├── localization
│   └── app-wide composition
│
├── core/
│   ├── error and result primitives
│   ├── logging contracts
│   ├── shared technical types
│   └── genuinely reusable UI primitives
│
├── services/
│   ├── analytics
│   ├── crash reporting
│   ├── notifications
│   ├── deep-link ingress
│   ├── feature flags
│   └── background work
│
├── map/
│   ├── domain (intentions, camera contract)
│   └── presentation (map surface, avatar)
│
└── features/
    ├── identity
    ├── city
    ├── discovery
    ├── facts
    ├── collection
    ├── progression
    ├── challenges
    ├── tours
    ├── puzzles
    ├── profile
    └── settings
```

`services/` contains application-wide technical capabilities. Business services remain inside their owning feature.

`map/` is the map host, added on 2026-08-28. Four features draw on the same map,
and putting the host inside one of them would force the other three to import
that feature's presentation, which rule 8 forbids. The host therefore belongs to
no business domain: it owns the map surface and the camera, features hand it
intentions through `map/domain`, and `map/presentation` and `map/data` are
internal. `domain-map.md` §7 is unaffected, `map` is still not a business
domain. Rules 18 and 19 in `dependency-rules.md` enforce the boundary.

`map/application/` arrived with step 12 and is the first `application/` folder
in the repository. It is an exception to the definition in §7 below and says so
out loud: it holds **composition** for the map host, namely the registry through
which a feature reaches the host and the two providers over it. There are no use
cases in it, and there will not be: a use case in the map host would be business
logic in a place that owns no business domain.

## 6. Feature architecture

A feature may contain:

```text
feature/
├── presentation/
├── application/
├── domain/
└── data/
```

These folders are not mandatory by default.

### Level 1 – presentation only

Use for a small, local feature with no dedicated data access or business rules.

### Level 2 – presentation and data

Use when a simple feature reads or writes data but has no meaningful domain rules.

### Level 3 – presentation, domain and data

Use when the feature owns business models, repository contracts or rules.

### Level 4 – presentation, application, domain and data

Use when workflows coordinate multiple domain operations, repositories or side effects.

A feature is promoted to a higher level when at least one of these is true:

- domain rules need independent tests;
- multiple screens share application behavior;
- multiple data sources must be coordinated;
- workflows have retries, optimistic updates or synchronization;
- the feature is becoming hard to understand without explicit boundaries.

## 7. Layer responsibilities

### Presentation

Owns widgets, pages, route adapters, view-specific state, formatting and Riverpod notifiers used by the UI.

It may depend on application and domain code. It must not use Supabase or local storage directly.

### Application

Owns use cases and workflow coordination. It defines transaction-like application actions, coordinates repositories and returns domain-oriented results.

It may depend only on domain code and narrow shared primitives.

One documented exception exists: `map/application/` carries the composition of
the map host and no use cases, see §5. The map host owns no business domain, so
it has no workflows to coordinate; what it does have is one object that must be
reachable from features and from `map/presentation/` at once.

### Domain

Owns entities, value objects, policies, repository contracts, failures and pure domain services.

It must contain no Flutter, Riverpod, Supabase, JSON, database or routing imports.

### Data

Owns repository implementations, remote and local data sources, DTOs, serialization, mappers and synchronization adapters.

It implements domain contracts and depends on technical infrastructure.

## 8. Standard data flow

```text
Widget
  ↓ invokes
Riverpod Notifier
  ↓ invokes
Use Case
  ↓ invokes
Repository contract
  ↓ implemented by
Repository implementation
  ↓ coordinates
Remote and/or local data source
  ↓
Supabase / local storage / device API
```

Simple read-only flows may omit a use case. A use case is required when a workflow contains domain rules, multiple dependencies, multiple writes, synchronization or meaningful reuse.

## 9. State management

Riverpod 3 is used for shared feature and application state.

- `setState` or Flutter-local state is used for ephemeral widget state.
- `Notifier` is used for synchronous mutable feature state.
- `AsyncNotifier` is used for asynchronous feature workflows.
- `Provider` is used for stateless dependencies.
- State is immutable.
- Riverpod types do not enter the domain layer.
- A notifier coordinates; it does not become a general-purpose business service.
- Navigation is initiated by presentation code, not from domain or data code.

## 10. Dependency injection

Riverpod is the only dependency-injection mechanism.

- No GetIt.
- No injectable.
- No global mutable service locator.
- Classes use constructor injection.
- Providers compose the object graph.
- Tests replace dependencies through provider overrides.

## 11. Navigation

`go_router` and generated typed routes are used.

- No raw route strings in feature code.
- Root routing composition lives in `app/routing`.
- Features own their route declarations or route branches.
- Authentication and onboarding redirects are centralized.
- Major domain objects receive stable deep-link routes.
- Bottom-navigation branches use independent navigation stacks.
- Modals and full-screen pages are routing decisions, not business decisions.

## 12. Multi-city architecture

Munich is the initial launch city, not a hard-coded system assumption.

- City identity is explicit in domain models and queries where relevant.
- Feature configuration may vary by city.
- Content, availability, map bounds and campaigns are city-scoped.
- No global `currentMunich` constants or Munich-specific business branches.
- The current city is resolved through a city context, not inferred ad hoc by each feature.

## 13. Cross-cutting concerns

Cross-cutting capabilities are exposed through narrow contracts and providers. Features must not bind directly to vendors unless the vendor API is intentionally confined to the data or service implementation.

Examples:

- analytics events;
- crash reporting;
- logging;
- permissions;
- location;
- feature flags;
- push notification handling;
- app configuration;
- localization.

## 14. Offline policy

FACT is selectively offline-capable.

- Offline behavior is defined per capability.
- Cached reads and queued writes are separate decisions.
- Collection and progression actions require idempotency.
- The UI must communicate stale, pending and failed synchronization states where relevant.
- A local database choice is deferred until concrete query and sync requirements are finalized.

## 15. Testing boundaries

- Domain rules: pure unit tests.
- Use cases: unit tests with fakes.
- Repository implementations: integration/contract tests.
- Notifiers: provider-container tests.
- Widgets: focused widget tests.
- Navigation and critical journeys: integration tests.
- Supabase schema, policies and functions: backend tests outside widget tests.

## 16. Architectural enforcement

The implementation phase must add:

- `flutter_lints` or a stricter agreed lint baseline;
- CI validation for formatting, analysis, tests and generated code;
- import-boundary checks;
- a script rejecting Supabase imports in presentation/domain;
- a script rejecting Flutter/Riverpod imports in domain;
- ownership checks for cross-feature imports;
- ADR review when a rule must be broken.

`riverpod_lint` and `custom_lint` were part of this list. They are currently not
installable because of a conflict between the pinned Flutter SDK,
`supabase_flutter` and the lint packages. The verified dependency chain, the
rules that stay unenforced and the condition under which the requirement returns
are recorded in `../engineering/quality-gates.md`, section "Accepted deviation:
no Riverpod lint". `tool/check_architecture.dart` covers the import-boundary and
ownership items above; it does not cover the Riverpod-specific rules.

## 17. Decision protocol

When architecture does not give a direct answer:

1. Keep the change inside the owning feature.
2. Choose the simplest design that preserves testability.
3. Avoid a new shared abstraction until two real consumers exist.
4. Do not introduce a new framework without an ADR.
5. Record a local assumption when product behavior is unclear.
6. Escalate only decisions that change product semantics, persistence, security, cost or public contracts.

## 18. Current open decisions

The following are intentionally deferred:

- guest mode and guest-to-account migration;
- local database technology;
- detailed sync protocol;
- final result/failure library;
- final immutable model/code-generation choice;
- analytics and crash-reporting vendors;
- push provider and campaign tooling;
- map tile caching;
- background synchronization constraints;
- final reward economy.

See `open-decisions.md`.
