---
id: PROD-OVERVIEW
status: accepted
owner: product
scope:
  - product
load_when:
  - product_design
  - feature_planning
  - onboarding
---

# FACT — Product Overview

## Document status

- Status: Draft for product alignment
- Source basis: current Flutter proof of concept and its repository documentation
- Website verification: pending because `https://fact-guide.com/` currently blocks automated access
- Technical implementation details are intentionally excluded unless they define user-visible behavior

## Product in one sentence

FACT is a location-based mobile city guide that helps people notice, understand and remember the places around them by discovering short, verified stories directly at their real-world locations.

## Product promise

FACT turns a walk through a city into an active discovery experience. Instead of presenting a conventional list of sights, the app reveals contextual knowledge around the user, encourages them to physically approach places, and lets them build a personal collection of discoveries.

## Problem

People often move through cities without knowing the stories behind buildings, streets, monuments and everyday places. Traditional city guides require active planning, long-form reading or fixed tours. Search engines can answer specific questions, but they rarely create spontaneous awareness of what is directly nearby.

## Target outcome

After using FACT, a person should:

1. notice more details in their surroundings;
2. learn memorable, location-specific stories;
3. feel motivated to explore on foot;
4. retain a personal record of discovered places;
5. optionally experience the city together or competitively with others.

## Primary target groups

### Independent city explorers

Residents or visitors who want to discover interesting nearby places without booking a guided tour or planning a fixed itinerary.

### Tourists

Visitors who need concise, multilingual and location-aware context while moving through an unfamiliar city.

### Curious locals

People who already know a city superficially but want to uncover hidden stories, unusual details and lesser-known locations.

### Groups and friends

Users who want a shared, playful activity through challenges, routes and puzzles.

## Core product pillars

### 1. Discover in context

Facts are connected to real places. The user sees what is nearby and understands why a location is interesting while standing close to it.

### 2. Move through the real world

The product rewards walking and physical presence. A discovery is not merely opened from a list; proximity is part of the experience.

### 3. Collect and remember

Discovered facts become part of a personal city diary or collection. Progress, coins, ranks and trophies provide lightweight motivation.

### 4. Learn without friction

Content should be concise, understandable and available in the user's language. Audio allows the app to accompany walking without requiring constant screen attention.

### 5. Explore alone or together

Users can follow a suggested tour, solve location-based puzzles, or participate in solo and group challenges.

### 6. Contribute responsibly

Users may propose their own facts with a place, description, image and optional source. Contributions require review before becoming trusted public content.

## Core experience loop

1. The app determines the user's location.
2. The user sees nearby discoveries or receives guidance toward the next one.
3. The user approaches a place.
4. FACT reveals its story, optionally through audio.
5. The user solves a puzzle or confirms the discovery.
6. The fact is added to the user's collection.
7. The user receives progress, coins or another lightweight reward.
8. The app suggests the next meaningful discovery.

## Product boundaries

### The product is

- a native-feeling Flutter application for iOS and Android;
- a contextual city-discovery companion;
- location-driven rather than catalogue-first;
- suitable for spontaneous exploration and guided routes;
- multilingual, with German and English as the current baseline;
- backed by curated and reviewable location-based content.

### The product is not

- a general-purpose navigation app;
- a booking platform for tours or attractions;
- a long-form encyclopedia;
- a social network as its primary purpose;
- a replacement for authoritative historical or safety information;
- a web application in the future product architecture.

## Product principles

1. **The real place comes first.** Features should strengthen awareness of the surroundings rather than pull attention permanently onto the screen.
2. **Context beats quantity.** A relevant nearby story is more valuable than a large undifferentiated content catalogue.
3. **Trust is part of the product.** Sources, moderation and clear content status matter for user-contributed facts.
4. **Playfulness supports learning.** Coins, ranks and challenges should motivate exploration without overwhelming the cultural content.
5. **Walking must remain safe.** The interface must not demand complex interaction while a user is moving.
6. **Guest exploration should be possible.** Account creation should be required only for features that genuinely need identity or synchronization.
7. **Mobile is the product.** iOS and Android share one Flutter codebase; the former web PoC is reference material only.

## Current proof-of-concept capabilities

The existing Flutter PoC contains evidence for the following product areas:

- onboarding, login and guest exploration;
- map-based nearby discovery;
- proximity-gated collecting;
- detailed fact presentation;
- saved and collected facts;
- coins, levels and trophies;
- audio guide and mini player;
- planned tours;
- solo, group, team and versus challenge concepts;
- location-based puzzles and hints;
- user-created fact submissions;
- comments, ratings or upvote-related concepts;
- profile, language and theme settings.

These capabilities do not automatically define the first production release. Prioritization is documented separately in `feature-inventory.md`.

## Success criteria to define

The product currently lacks agreed measurable success criteria. Candidate metrics for later validation include:

- percentage of users who reach and collect a first fact;
- median number of facts discovered per active walk;
- completion rate of started tours;
- returning explorers within 7 and 30 days;
- percentage of sessions with audio usage;
- content-quality acceptance rate for user submissions;
- permission opt-in and location failure rates;
- crash-free sessions and battery impact during active exploration.

## Open product decisions

1. Which city or cities define the initial launch market?
2. What is the minimum useful density of facts per launch city?
3. Is the first release primarily for tourists, locals, or both equally?
4. Which features require an account in the production version?
5. How visible should gamification be relative to cultural discovery?
6. Are user-created facts part of the first public release?
7. Are group challenges part of the first public release?
8. Which content review and sourcing rules define a trusted fact?
9. Does the app need usable exploration when connectivity is poor?
10. Which location behavior is allowed in the background?
