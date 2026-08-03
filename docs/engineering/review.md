---
id: ENG-REVIEW
status: accepted
owner: engineering
scope:
  - review
load_when:
  - code_review
---

# Code Review Checklist

## Correctness

- Does the code implement the intended behavior?
- Are edge, retry, duplicate and cancellation cases safe?
- Are impossible states prevented?

## Architecture

- Is the code in the owning feature/layer?
- Are repository and domain boundaries preserved?
- Is cross-feature coupling explicit and justified?
- Is complexity appropriate for the feature?

## Flutter and Riverpod

- Is widget state local when it can be?
- Are provider lifecycles appropriate?
- Could rebuilds or subscriptions be broader than necessary?
- Does async code handle disposal/context safely?
- Is navigation kept in presentation?

## Data and sync

- Are DTO/domain mappings explicit?
- Is the source of truth clear?
- Are writes idempotent where retries are possible?
- Are stale/pending/rejected states visible?

## Security and privacy

- Is authorization server-enforced?
- Is sensitive data logged or tracked?
- Are inputs validated at trust boundaries?
- Does the change increase data collection?

## Tests

- Do tests protect behavior rather than implementation?
- Are important negative paths tested?
- Will tests fail for the likely regression?

## Maintainability

- Are names precise?
- Are comments explaining why?
- Is duplication preferable to the proposed abstraction?
- Is the public API smaller than it needs to be?

## Operations

- Can failures be diagnosed?
- Is rollout/rollback safe?
- Are migrations compatible?
