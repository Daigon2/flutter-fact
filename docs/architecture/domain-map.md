---
id: ARCH-DOMAINS
status: accepted
owner: architecture
scope:
  - domain
load_when:
  - new_feature
  - cross_feature_change
  - domain_modeling
---

# FACT Domain Map

## 1. Purpose

This document assigns ownership to FACT's main business concepts and defines permitted domain relationships. It prevents duplicate models, unclear feature boundaries and cyclic feature dependencies.

## 2. Bounded domains

### Identity

Owns:

- authentication session;
- account identity;
- sign-in and sign-out;
- account linking;
- guest identity if adopted;
- account deletion;
- authentication recovery.

Does not own public profile presentation, rewards or collected facts.

### City

Owns:

- city identity;
- city availability;
- city configuration;
- supported map bounds;
- content availability metadata;
- active city selection;
- future city rollout state.

City is a foundational context, not merely a settings field.

### Facts

Owns:

- fact identity and canonical content;
- location and geographic eligibility;
- categories and tags;
- publication and availability state;
- fact detail retrieval;
- fact media references;
- knowledge provenance metadata exposed to the app.

The external AI knowledge-generation pipeline publishes content consumed by this domain, but is not implemented inside the Flutter client.

### Discovery

Owns:

- nearby and relevant fact discovery;
- discovery filters;
- map/list exploration;
- ranking inputs and presentation;
- search and exploration sessions;
- recommendation orchestration.

Discovery references facts and city context. It does not own canonical fact content.

### Collection

Owns:

- whether and when a user collected a fact;
- collection eligibility workflow;
- collection history;
- pending collection synchronization;
- collection views.

It references Fact IDs and User IDs. It does not own fact text or the reward economy.

### Progression

Owns:

- XP;
- levels;
- coins or other soft currency;
- achievements;
- streaks if adopted;
- reward events and progression ledger;
- progression rules.

Progression consumes domain events such as `FactCollected`, but collection does not directly mutate profile counters.

### Challenges

Owns:

- challenge definitions;
- challenge participation;
- objectives and completion;
- challenge rewards;
- challenge time windows.

Challenges may reference facts, cities, tours and progression rewards through IDs or contracts.

### Tours

Owns:

- tour definitions;
- ordered or flexible tour stops;
- tour enrollment/session;
- tour progress;
- tour completion;
- city-scoped tour availability.

Tours reference Fact IDs rather than embedding owned fact models.

Challenges also owns the **session state of a running hunt**: current station,
distance, hints bought. `Discovery` reads that state through a public read-only
contract of Challenges and never writes it. See ADR-007.

### Puzzles

Owns:

- puzzle definitions for the six puzzle types;
- evaluation policy;
- hint levels;
- puzzle difficulty and operand value objects.

Added on 2026-08-31 by ADR-006. Puzzles is a shared domain with two consumers,
Tours and Challenges, which depend on its domain and application contracts only.
Puzzles never references Tours or Challenges, so the graph stays acyclic.

Puzzles evaluates, it does not reward: a puzzle reward is a specification owned
by the consuming feature, and applying it belongs to Progression.

### Profile

Owns:

- public and private user profile information;
- display name and avatar;
- user-facing summary projections;
- preferences that describe the person rather than app behavior.

Profile may display collection/progression summaries through read models, but does not own those rules.

### Settings

Owns:

- app preferences;
- language;
- accessibility preferences;
- notification preferences;
- privacy controls;
- map display preferences.

Settings is intentionally small and may remain a Level 1 or Level 2 feature.

## 3. Supporting technical capabilities

The following are not business domains:

- map rendering;
- geolocation provider;
- analytics SDK;
- push transport;
- crash reporting;
- local database;
- Supabase client;
- image loading.

Map rendering was assigned to Discovery presentation, with the reservation that a broader technical module could take it over. That reservation took effect on 2026-08-28: the map host lives in `lib/map/` as app and UI infrastructure, owns the camera and the map surface, and exposes `map/domain` to features. Discovery still owns what is shown on the map and why; it no longer owns the host. §7 below is unchanged by this: the map host is a technical capability, not an independent business domain.

## 4. Relationships

```text
Identity ───────────────┐
                       ├──> Collection ──event──> Progression
City ───────┬───────────┤
            ├──> Facts ─┼──> Discovery
            ├──> Tours  │
            └──> Challenges
Facts ─────────> Collection
Facts ─────────> Tours
Facts ─────────> Challenges
Puzzles <─────── Tours
Puzzles <─────── Challenges
Challenges ────> Discovery read model (active hunt, ADR-007)
Progression ───> Profile read model
Collection ────> Profile read model
```

Arrows indicate allowed conceptual references, not permission to import another feature's presentation or data layer.

## 5. Cross-domain communication rules

Preferred mechanisms:

1. Stable IDs and value objects.
2. Domain/application contracts.
3. Read-model repositories.
4. Explicit domain events inside one application process.
5. Backend projections for aggregate dashboards.

Forbidden mechanisms:

- Feature A calling Feature B's notifier.
- Importing another feature's widgets to access its state.
- Writing another domain's database records from an unrelated repository.
- Duplicating canonical entities under multiple features.
- Placing business models in `core`.

## 6. Ownership examples

- `Fact` belongs to Facts.
- `CollectedFact` or `CollectionEntry` belongs to Collection.
- `FactCardViewData` belongs to the consuming presentation layer.
- `RewardEvent` belongs to Progression.
- `ChallengeReward` belongs to Challenges as a reward specification, while applying it belongs to Progression.
- `TourStop` belongs to Tours and references a `FactId`.
- `Puzzle` and its evaluation policy belong to Puzzles; a `PuzzleReward` is a
  specification owned by the consuming feature, and applying it belongs to
  Progression.
- `ActiveHunt` belongs to Challenges; the read model Discovery watches on the map
  belongs to Challenges as well, not to the consuming presentation layer, because
  Discovery must not restate what a hunt is.
- `CityId` belongs to City and may be used as a shared domain value type through an explicit public domain contract.

## 7. Initial domain decisions made by architecture

- `map` is not an independent business domain in v1.
- XP, coins, achievements and levels form the `progression` domain.
- `collection` is distinct from progression.
- `profile` presents summaries but does not own collection or progression.
- the AI content-generation pipeline is an external upstream system.
- city is a first-class domain context.
