---
id: ARCH-OFFLINE
status: accepted
owner: architecture
scope:
  - flutter
  - backend
load_when:
  - offline
  - sync
  - collection
  - tour
---

# Offline Capability Matrix

Status: architectural baseline; detailed sync design remains open.

| Capability | Offline read | Offline write | Source of truth | Sync notes |
|---|---:|---:|---|---|
| Authentication | Limited session reuse | No new login | Supabase Auth | Expired sessions require network |
| City catalogue | Yes, cached | No | Supabase | Refresh opportunistically |
| Fact catalogue/details | Yes, selected cache | No authoring | Supabase | Cache by city/version; stale allowed |
| Discovery/map results | Partial | Local filters only | Supabase + device | Nearby results may be stale |
| Collection history | Yes | Yes | Server with local outbox | Idempotent collection command |
| Collect fact action | Yes, queued when eligible | Yes | Server authoritative | Pending state visible; anti-abuse rules server-side |
| Progression summary | Yes | Indirect only | Server projection/ledger | Optimistic display only with reconciliation |
| Challenges | Cached active definitions | Limited progress queue | Server | Time windows require trusted server time |
| Tours | Cached enrolled/downloaded tour | Progress queue | Server | Stop completion must be idempotent |
| Profile | Yes, cached | Limited edit queue | Server | Conflict policy per field |
| Settings | Yes | Yes | Local, optionally synced | Local-first for device preferences |
| Images/media | Selected cache | No | Remote storage | Quotas and eviction policy required |
| Analytics | N/A | Queued | Analytics vendor | Consent-aware, bounded queue |

## Sync baseline

Use a local outbox for offline mutations that matter.

Each queued mutation needs:

- stable operation ID;
- user/account scope;
- aggregate/entity ID;
- operation type;
- payload version;
- creation timestamp;
- retry state;
- idempotency support;
- terminal failure handling.

## Conflict baseline

- Server-generated progression is authoritative.
- Collection operations are additive and idempotent.
- Settings use last-write-wins only where harmless.
- Profile conflicts are resolved per field or through server versioning.
- Challenge/tour completion validates server time and eligibility.
- Silent data loss is forbidden.

## UI states

Relevant screens distinguish:

- synchronized;
- pending synchronization;
- stale cached content;
- retrying;
- rejected by server;
- offline unavailable.

## Deferred technology choice

Do not select Drift, Isar, Hive or another database until the implementation spike validates:

- required spatial/filter queries;
- relational needs;
- schema migrations;
- background access;
- encryption requirements;
- testability;
- package maintenance;
- outbox implementation.
