---
id: PROD-ROADMAP
status: accepted
owner: product
scope:
  - product
load_when:
  - feature_planning
  - scope_review
---

# FACT — Feature Inventory

## Purpose

This document separates the product capabilities visible in the PoC from a recommended production scope. It is a product prioritization draft, not an implementation plan.

## Priority model

- **Core** — required to prove the central FACT experience.
- **Launch candidate** — valuable for the first store release after the core is stable.
- **Later** — meaningful, but should not block the first reliable release.
- **Re-evaluate** — PoC concept whose product value or operating cost is not yet proven.

## Feature inventory

| Product area | Capability | PoC evidence | Proposed priority | Notes |
|---|---|---:|---|---|
| Entry | Language selection | Yes | Core | German and English are the current baseline. |
| Entry | Explore without account | Yes | Core | Reduces friction before the value is understood. |
| Identity | Email registration and login | Yes | Launch candidate | Needed for cross-device progress and contribution. |
| Identity | Password reset | Yes | Launch candidate | Required when account login ships. |
| Identity | Apple and Google sign-in | Planned | Later | Useful for conversion, but not essential for validating the core loop. |
| Discovery | Detect current location | Yes | Core | Must include clear permission, denied and unavailable states. |
| Discovery | Show nearby facts on a map | Yes | Core | Central orientation and discovery surface. |
| Discovery | Show nearest meaningful fact | Yes | Core | Supports exploration without browsing many markers. |
| Discovery | Direction and distance guidance | Yes | Core | Should minimize screen attention while walking. |
| Discovery | Notify or signal when close | Partial | Launch candidate | Background behavior needs a separate privacy and battery decision. |
| Facts | Open fact detail | Yes | Core | Must include story, place and source status. |
| Facts | Proximity-gated collecting | Yes | Core | Current PoC indicates an approximately 150 m gate; final threshold is a product decision. |
| Facts | Save fact for later | Yes | Launch candidate | Useful but secondary to discovery. |
| Facts | Rate, comment or upvote | Partial | Later | Requires moderation, abuse handling and clear purpose. |
| Collection | Personal discovered-facts library | Yes | Core | The durable memory of a user's exploration. |
| Collection | City-specific progress | Yes | Launch candidate | Supports repeated use and travel across cities. |
| Gamification | Coins or XP | Yes | Launch candidate | Keep simple until retention value is proven. |
| Gamification | Levels or explorer rank | Yes | Later | Depends on a coherent progression economy. |
| Gamification | Trophy catalogue | Yes | Later | Large catalogue increases product and content complexity. |
| Audio | Text-to-speech fact playback | Yes | Launch candidate | Strong accessibility and walking use case. |
| Audio | Persistent mini player | Yes | Launch candidate | Needed only if audio is in launch scope. |
| Audio | Directional or stereo beacon | Partial | Re-evaluate | Technically and ergonomically complex; product value should be tested. |
| Tours | Choose a duration | Yes | Launch candidate | Turns nearby facts into an intentional route. |
| Tours | Generate or select a route | Yes | Launch candidate | Requires reliable ordering and route quality. |
| Tours | Complete sequential stops | Yes | Launch candidate | Natural extension of the core loop. |
| Puzzles | Solve a fact-related observation puzzle | Yes | Later | Valuable differentiation, but content coverage is currently limited. |
| Puzzles | Progressive hints | Yes | Later | Depends on broad and high-quality puzzle data. |
| Challenges | Solo challenge | Yes | Later | Could be tested after normal tours work reliably. |
| Challenges | Group lobby and shared session | Partial | Re-evaluate | Real-time coordination and fairness substantially increase complexity. |
| Challenges | Teams or versus modes | Concept | Re-evaluate | Not required to validate the product promise. |
| Contribution | Create a fact with title and description | Yes | Later | Requires moderation, content ownership and abuse processes. |
| Contribution | Capture or choose an image | Yes | Later | Adds storage, rights and privacy requirements. |
| Contribution | Detect contribution location | Yes | Later | Must allow correction and protect sensitive locations. |
| Contribution | Add a source | Yes | Later | Source quality rules must be defined before public use. |
| Contribution | AI-assisted text or source suggestions | Yes | Re-evaluate | Must not replace factual review; creates cost and compliance concerns. |
| Profile | View progress and preferences | Yes | Launch candidate | Keep focused on information users understand and value. |
| Profile | Real-name visibility control | Yes | Later | Relevant only when social or public contribution features ship. |
| Settings | Light and dark mode | Yes | Launch candidate | Platform-consistent behavior preferred. |
| Settings | Replay onboarding or audio help | Yes | Launch candidate | Helpful for a novel location/audio interaction model. |

## Recommended first production milestone

### Milestone A — Core discovery validation

- German and English;
- guest entry;
- location permission and robust fallback states;
- map with nearby facts;
- nearest-fact guidance;
- fact detail;
- proximity-gated collection;
- local collection history;
- one carefully populated launch city;
- privacy, analytics and crash reporting foundations;
- iOS and Android release pipeline.

### Milestone B — Account and guided exploration

- account login and synchronization;
- saved facts;
- profile and city progress;
- simple coins or XP;
- audio playback;
- fixed or generated tours;
- additional launch cities.

### Milestone C — Participation and game modes

- observation puzzles and hints;
- solo challenges;
- user-created facts with moderation;
- comments or voting only if a clear product need remains;
- group and versus features only after technical and product validation.

## Scope rules for implementation planning

1. A PoC feature is not automatically a committed production feature.
2. Features that require moderation, real-time sessions, background location or AI calls need explicit product and operating approval.
3. Store readiness, accessibility, privacy and failure handling are part of each milestone, not a later cleanup phase.
4. The initial launch should optimize density and quality in a small geographic area rather than maximize city count.
