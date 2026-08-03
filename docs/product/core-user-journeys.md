---
id: PROD-JOURNEYS
status: accepted
owner: product
scope:
  - product
  - ux
load_when:
  - feature_implementation
  - acceptance_criteria
  - integration_testing
---

# FACT — Core User Journeys

## Journey 1: First discovery as a guest

### User goal

Understand the value of FACT without creating an account.

### Preconditions

- The app is installed.
- The user is in or near an area containing published facts.

### Main flow

1. The user opens FACT.
2. The app briefly communicates the promise: discovering what is around them.
3. The user selects a language.
4. The user chooses to explore without an account.
5. FACT asks for location access with a clear explanation.
6. The map opens and shows the user's position and nearby discoveries.
7. FACT identifies a suitable nearby fact and communicates distance and direction.
8. The user walks toward the location.
9. At the permitted distance, the fact becomes collectable.
10. The user opens the story and collects it.
11. The fact appears in the personal collection.
12. FACT proposes a natural next action: continue nearby, start a tour, or stop.

### Required failure states

- location permission denied;
- location services disabled;
- no GPS fix;
- no facts nearby;
- poor or no network connection;
- fact data unavailable;
- user is outside the collectable radius.

### Product success signal

The user collects a first fact and understands why physical proximity matters.

## Journey 2: Returning explorer continues a collection

### User goal

Resume exploring and see meaningful personal progress.

### Main flow

1. The user opens FACT after a previous session.
2. Existing collected facts and preferences are restored.
3. The app centers on the current area or active city.
4. Already collected and undiscovered facts are visually distinguishable.
5. The user selects a nearby undiscovered fact.
6. The app guides the user there.
7. The user collects it and sees updated city progress.

### Account behavior

Guest progress may remain local. When the user chooses to create an account, the product must define whether and how local progress merges with server progress.

## Journey 3: Listen while walking

### User goal

Learn about a place without continuously reading the screen.

### Main flow

1. The user opens a discovered or available fact.
2. The user starts audio playback.
3. Playback continues while the user returns to the map or locks attention away from the detail screen, subject to platform rules.
4. Clear controls allow pause, resume and stop.
5. The app avoids overlapping spoken guidance and fact narration.

### Required considerations

- audio focus and interruptions;
- silent mode and accessibility expectations;
- language and pronunciation quality;
- generated versus pre-recorded audio provenance;
- user control over mobile data usage.

## Journey 4: Plan and complete a short tour

### User goal

Turn available time into a coherent self-guided city walk.

### Main flow

1. The user chooses the tour mode.
2. The user selects a duration or route theme.
3. FACT proposes a route of reachable facts.
4. The user reviews the expected duration and number of stops.
5. The tour starts with a clearly identified next stop.
6. At each stop, the user discovers and collects the fact.
7. The app advances to the next stop.
8. The user can pause or abandon the route without losing collected facts.
9. After the final stop, FACT summarizes the completed tour and discoveries.

### Required failure states

- route cannot be generated;
- a fact is unavailable or inaccessible;
- location accuracy is insufficient;
- the user leaves the planned area;
- time estimate changes substantially.

## Journey 5: Create an account after seeing value

### User goal

Preserve progress across devices or access identity-dependent features.

### Main flow

1. A guest encounters a feature that benefits from an account.
2. FACT explains the concrete benefit rather than blocking exploration generically.
3. The user registers or logs in.
4. Existing local progress is preserved or merged according to an explicit rule.
5. The user returns to the interrupted task.

### Required product decision

The merge behavior between guest and account data must be deterministic, reversible where practical, and explained to the user.

## Journey 6: Submit a new fact

### Status

Later-scope journey; not recommended as a core launch dependency.

### User goal

Share a relevant story about a real place.

### Main flow

1. An authenticated user starts a contribution.
2. The user captures or selects a place and location.
3. The user adds a title and explanatory text.
4. The user optionally adds an image and a source.
5. FACT previews the submission and explains review status.
6. The user submits it.
7. The contribution is stored as pending, not immediately presented as verified public content.
8. The user can later see whether it was accepted, rejected or needs revision.

### Required safeguards

- moderation and reporting;
- source and copyright requirements;
- image rights and personal-data handling;
- duplicate detection;
- protection of private or sensitive locations;
- transparent use of AI assistance;
- no reward that incentivizes low-quality spam.

## Journey 7: Complete a puzzle or challenge

### Status

Later-scope journey.

### User goal

Engage more actively with a place through observation or competition.

### Main flow

1. The user starts a challenge or reaches a puzzle-enabled fact.
2. FACT asks a question that can be answered from the place or fact context.
3. The user enters or selects an answer.
4. Optional hints become available progressively.
5. FACT provides immediate, understandable feedback.
6. Completion contributes to the user's progress or challenge score.

### Quality rule

A puzzle must deepen observation or understanding. It must not be arbitrary trivia that could be solved equally well away from the location.

## Cross-journey experience requirements

- Users must always understand whether an action requires proximity, connectivity or an account.
- The app must not encourage unsafe screen interaction while walking or crossing roads.
- Collection, rewards and synchronization must be idempotent; repeated requests must not duplicate progress.
- Permission requests must be contextual and recoverable.
- All critical states require German and English copy.
