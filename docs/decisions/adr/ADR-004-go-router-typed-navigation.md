---
id: ADR-004
status: accepted
owner: architecture
scope:
  - decision
load_when:
  - relevant_decision
---

# ADR-004: go_router with Typed Routes

Status: **Accepted**  
Date: 2026-07-19

## Context

FACT needs auth redirects, deep links, independent bottom-tab stacks and stable links to facts, tours and challenges.

## Decision

Use go_router with go_router_builder typed routes. Compose root routing centrally while features own route branches.

## Alternatives considered

- Navigator API directly
- auto_route
- raw named/string routes

## Consequences

- Compile-time route parameters and clearer deep-link contracts.
- Code generation is required.
- Routing composition needs explicit conventions to avoid a large monolithic file.

## Rules

- No raw route strings outside routing infrastructure.
- Business/domain code never navigates.
- Auth/onboarding redirects are centralized.
- Major domain objects receive stable routes.
- Notification links resolve into typed destinations.

## Review triggers

- Typed route generation prevents required modularization.
- Navigation model changes materially, such as web becoming a primary platform.
- Package maintenance or Flutter compatibility becomes inadequate.
