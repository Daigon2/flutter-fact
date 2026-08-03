---
id: REF-GLOSSARY
status: accepted
owner: product
scope:
  - all
load_when:
  - terminology
  - domain_modeling
---

# FACT Glossary

## Product and domain terminology

## Purpose

This glossary defines product language independently of Dart classes, database tables or current PoC naming. Technical models should later align with these definitions.

## Core terms

### FACT

The product and brand. In normal prose, use `FACT` for the application and `fact` or `discovery` for an individual content item, depending on the final product-language decision.

### Fact

A concise, place-linked piece of knowledge about a real-world location. A fact contains at least a title, explanatory content, geographic position and publication status. It may also contain a source, image, audio, category, translations, puzzles and community metadata.

A published fact is not merely any user statement; it has passed the product's required review and trust process.

### Place

The real-world object, building, street, area, landmark or point of interest to which a fact refers.

### Discovery

The user experience of encountering and understanding a fact in its geographic context. The term may also describe a fact that is presented as available nearby.

### Nearby fact

A published fact within a product-defined search distance from the user's current or selected location.

### Collectable fact

A fact for which the user currently satisfies the collection rules, normally including sufficient physical proximity and publication status.

### Collected fact

A fact permanently recorded in the user's collection after a valid collection action. Collection is a user-progress event, not merely opening the detail page.

### Saved fact

A fact bookmarked for later without implying that the user visited or collected it.

### Collection

The user's durable set of collected facts. The UI may present it as a city diary, library, wallet or another metaphor, but the domain meaning remains the same.

### Collection radius

The maximum permitted distance between the user and a fact for collection. The PoC suggests approximately 150 metres, but the production value and accuracy rules remain an explicit product decision.

### Active city

The city context currently used to group facts, progress and tours. It may be detected from location or chosen manually. The relationship between geographic boundaries and editorial city definitions must be specified later.

### City progress

A summary of the user's collected discoveries within an active or selected city. It must be derived from published content and valid collection events.

### Explorer

A person using FACT. Prefer this neutral domain term over `player` except inside explicitly competitive challenge contexts.

### Guest

An explorer without an authenticated account. Guest capabilities and local persistence must be explicitly defined.

### Profile

The account-associated representation of an explorer, including preferences and synchronized progress. Public identity fields are separate from private account data.

## Guidance and route terms

### Guidance

Information helping the explorer reach a discovery, such as distance, direction, map position or audio cues. FACT guidance is not turn-by-turn navigation unless explicitly implemented and labelled as such.

### Tour

An ordered sequence of facts intended to form a coherent self-guided walk. A tour may be fixed, themed or generated from duration, location and availability.

### Tour stop

One fact or place within a tour's ordered sequence.

### Route theme

A topic used to select or organize facts in a tour or challenge, for example markets, churches or unusual history.

### Estimated duration

The expected time needed to complete a tour, including walking and content interaction. It is an estimate, not a guarantee.

## Learning and game terms

### Puzzle

A question or interaction tied to a fact or its physical surroundings. A good puzzle encourages observation or reinforces knowledge.

### Hint

Progressive assistance for solving a puzzle without immediately revealing the answer.

### Challenge

A structured activity with goals, scoring or timing beyond ordinary exploration. Challenges may be solo or involve other people.

### Challenge session

One active instance of a challenge, including participants, route, progress, score and lifecycle state.

### Participant

An explorer or simulated actor taking part in a challenge session.

### Coins / XP

A lightweight reward unit granted for approved product actions. The final production model should choose one primary term and define its economy clearly.

### Level / explorer rank

A progression status calculated from accumulated valid activity. It must not be confused with content quality, authority or factual expertise.

### Trophy

A named achievement unlocked by satisfying explicit criteria. Trophies are optional motivation and should not distort the central learning experience.

## Content and trust terms

### Published fact

A fact approved for public discovery.

### Draft fact

A fact still being created and visible only to its creator or authorized editors.

### Submitted fact

A user contribution sent for review but not yet approved for public discovery.

### Approved fact

A reviewed fact that satisfies publication requirements. Depending on workflow, approval may immediately result in publication or require a separate publishing action.

### Rejected fact

A submitted fact that does not meet publication requirements. Rejection should ideally include a reason or revision path.

### Source

A reference supporting a fact's claims. Source presence alone does not guarantee reliability; source quality and relevance must be evaluated.

### Creator

The explorer or editorial user who submits or authors a fact. This term does not imply that the content is published or trusted.

### Moderator / editor

An authorized person responsible for reviewing contributions, resolving reports and maintaining content quality.

### User-generated content

Any text, image, comment, rating or other material submitted by an explorer rather than the editorial content pipeline.

### Verification status

A clear product-level representation of a fact's review state and trust level. It must not be inferred only from whether a database row exists.

## Audio terms

### Audio guide

The product capability that presents fact or route content through sound while exploring.

### Narration

Spoken rendering of fact content, whether generated through text-to-speech or provided as recorded audio.

### Beacon

An optional sound cue that communicates proximity or direction. This remains an experimental concept until validated.

## Terms to avoid or clarify

### Wallet

The PoC uses a wallet metaphor for the collection. Because `wallet` commonly implies payment or digital identity, production copy should validate whether `Collection`, `City diary` or `Library` is clearer.

### Fact Finder

A PoC label for nearby discovery. Decide whether this is a branded mode or merely internal copy before treating it as a stable domain concept.

### Live

Avoid unless data is truly real-time. A current location or active challenge is not automatically a real-time synchronized experience.

### Verified

Use only when a defined review process has actually been completed. Do not use as a decorative trust label.

## Architecture and engineering terminology

**Feature**  
A cohesive business or product capability with clear ownership.

**Domain**  
The business concepts and rules owned by a feature or bounded context.

**Entity**  
A domain object defined by identity and lifecycle.

**Value object**  
An immutable, validated domain value defined by its attributes.

**DTO**  
A transport or persistence representation. It is not a domain model.

**Repository contract**  
A domain-facing abstraction for loading or changing owned data.

**Repository implementation**  
A data-layer class that implements a repository contract using one or more data sources.

**Data source**  
A narrow adapter to Supabase, local storage, device APIs or another external system.

**Use case**  
An application workflow that coordinates domain behavior and dependencies.

**Domain service**  
Pure domain logic that does not naturally belong to one entity or value object.

**Application service**  
Workflow coordination across repositories or domain services.

**Infrastructure service**  
An app-wide technical capability such as analytics, location or notifications.

**Riverpod provider**  
A declaration that creates/exposes state or a dependency. It is not a business domain concept.

**Notifier**  
A Riverpod-managed presentation/application state owner with explicit commands.

**Presentation state**  
Immutable data required to render and interact with a UI surface.

**View data**  
A UI-specific formatted projection.

**Core**  
A small set of truly generic technical primitives. It is not a shared business dumping ground.

**Source of truth**  
The authoritative owner from which a category of data is derived and reconciled.

**Outbox**  
Durable local queue of mutations awaiting server synchronization.

**Projection/read model**  
A query-oriented representation derived from one or more authoritative domain records.
