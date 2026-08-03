---
id: OPS-RELEASE
status: accepted
owner: operations
scope:
  - release
  - observability
load_when:
  - release
  - incident
  - telemetry
---

# Observability and Release Standard

## Structured observability

Production workflows emit enough context to diagnose failure without exposing sensitive data.

Recommended fields:

- event/operation name;
- feature;
- app version/build;
- environment;
- anonymized session/user reference where lawful;
- operation/correlation ID;
- outcome;
- failure category;
- duration;
- network/offline state where relevant.

## Error taxonomy

Separate:

- expected domain failure;
- validation failure;
- authorization failure;
- connectivity failure;
- timeout;
- data/schema failure;
- unexpected defect.

Only unexpected defects and actionable infrastructure failures become crash/error reports.

## Release environments

Use at least:

- development;
- staging;
- production.

Each environment has isolated backend/configuration and clearly visible app identity where practical.

## Versioning

- App versions follow store-compatible semantic product versioning.
- Build numbers are monotonically increasing.
- Schema and payload versions are independent where required.
- Deep-link compatibility is maintained across supported app versions.

## Release process

1. Merge through protected branch.
2. CI runs quality gates.
3. Produce signed staging build.
4. Run critical journey smoke tests.
5. Review migrations and feature flags.
6. Produce production artifacts.
7. Store symbol/de-obfuscation files securely.
8. Roll out progressively where store tooling allows.
9. Monitor crash, auth, collection and sync signals.
10. Record release notes and known risks.

## Rollback

Mobile binaries cannot be instantly rolled back for all users. Therefore:

- risky behavior uses server-side flags when appropriate;
- backend changes remain backward-compatible through the rollout window;
- migrations avoid destructive changes in the same release;
- kill switches exist for high-risk network features;
- clients handle unknown/new server fields safely.

## Performance

Use profile mode and representative devices for performance investigations.

Measure before optimizing.

Critical areas:

- map frame rendering;
- marker clustering/update;
- cold start;
- first meaningful content;
- image decoding;
- large list scrolling;
- local sync and database queries;
- provider rebuild scope.

## Release verification

Every release has a short checklist covering:

- auth;
- city selection;
- map/discovery;
- fact details;
- collection;
- offline/reconnect;
- profile/progression;
- deep link;
- notification route if enabled;
- crash reporting sanity.
