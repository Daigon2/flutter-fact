---
id: ARCH-DATA-FLOW
status: accepted
owner: architecture
scope:
  - flutter
  - backend
load_when:
  - repository_change
  - modeling
  - sync
---

# Model and Data Flow

## 1. Model categories

### Remote DTO

Represents Supabase rows, RPC responses or API payloads. It may contain nullable, backend-oriented and serialized fields.

### Local DTO / record

Represents local persistence schema. It is optimized for storage and migration, not business semantics.

### Domain entity

Represents a business concept with stable meaning and invariants.

### Value object

Represents validated domain values such as `FactId`, `CityId`, coordinates, XP amount or collection timestamp.

### Application result

Represents the outcome of a use case, including expected domain failures.

### Presentation state

Represents data needed to render and interact with a screen. It may combine multiple domain models.

### View data

A formatted, UI-specific projection such as labels, icon choices or grouped rows.

## 2. Standard inbound flow

```text
Supabase row / RPC JSON
    ↓ parse
Remote DTO
    ↓ map + validate
Domain entity/value object
    ↓ use case/repository
Presentation state or view data
    ↓ render
Widget
```

## 3. Standard outbound flow

```text
User intent
    ↓
Notifier method
    ↓
Use case command
    ↓
Domain validation
    ↓
Repository contract
    ↓
Data-layer request DTO
    ↓
Supabase/local persistence
```

## 4. Mapping rules

- Mapping occurs at boundaries.
- DTOs do not expose backend naming to the domain.
- Invalid backend data becomes a typed data failure, not a partially valid domain entity.
- Domain entities do not implement Supabase serialization by default.
- Presentation formatting does not modify domain objects.
- Time is stored and transported in UTC and converted for display at the presentation boundary.
- Coordinates use a validated domain value object.
- IDs are strongly typed where confusion would be costly.
- Coins and XP use integer value types; floating point is forbidden.
- User-visible localized strings are created in presentation.

## 5. Result and failure direction

Target shape:

```text
Future<Result<T, Failure>>
```

The exact implementation package is open. Requirements:

- expected failures are typed;
- unexpected exceptions retain stack traces;
- domain failures contain no localized text;
- data-layer errors are mapped before crossing into domain/application;
- cancellation is distinguishable where relevant;
- UI maps failures to localized messages and recovery actions.

## 6. Code generation direction

Recommended baseline:

- Riverpod code generation for providers;
- `json_serializable` for transport DTOs;
- immutable state/entities through `freezed` where unions/copy semantics materially help;
- avoid generated unions for tiny value objects when plain Dart is clearer.

This remains subject to a lightweight implementation spike before final dependency locking.
