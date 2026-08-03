---
id: ENG-PACKAGES
status: accepted
owner: engineering
scope:
  - dependencies
load_when:
  - add_dependency
  - upgrade_dependency
---

# Package Governance

## Principle

Every dependency adds maintenance, security, build and architectural cost.

## Adding a package

A proposal must state:

- problem being solved;
- why standard Flutter/Dart APIs are insufficient;
- alternatives considered;
- maintenance activity;
- platform support;
- license;
- native permissions/code;
- transitive dependency impact;
- testability;
- exit/migration strategy.

## Approval levels

### Feature-local, low-risk package

May be approved in normal review if mature, narrow and removable.

### Cross-cutting package

Requires engineering-lead/architecture review.

### Persistence, auth, navigation, state, analytics or code-generation framework

Requires an ADR or update to an existing ADR.

## Version policy

- Pin through `pubspec.lock` for application builds.
- Use intentional compatible constraints in `pubspec.yaml`.
- Dependency updates are reviewed, tested and not blindly automated into production.
- Major updates receive migration notes.
- Security updates are prioritized.

## Package removal

Remove packages that:

- are unused;
- duplicate an existing capability;
- are unmaintained without a controlled fork;
- introduce unacceptable permissions or vulnerabilities;
- can be replaced with simpler first-party APIs.

## Vendor wrappers

Wrap a vendor when:

- it is cross-cutting;
- vendor types would otherwise spread across features;
- testing requires replacement;
- privacy/configuration must be centralized.

Do not wrap simple stable APIs merely to create an interface.
