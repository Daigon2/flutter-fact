---
id: AI-MEMORY
status: accepted
owner: ai
scope:
  - ai
load_when:
  - memory_update
  - documentation_change
---

# Repository Memory

## Durable memory

Durable knowledge is version-controlled and reviewable:

- product decisions;
- ADRs;
- architecture;
- engineering standards;
- glossary;
- feature contracts;
- runbooks;
- open decisions.

## Working memory

Temporary task state belongs in the task/PR:

- current hypothesis;
- inspected files;
- temporary plan;
- experiment output;
- unresolved implementation detail.

Delete or close it when the task ends.

## Auto memory policy

Claude Code auto memory may store personal workflow learnings and debugging hints, but it is not authoritative.

Do not rely on auto memory for:

- product decisions;
- security policy;
- architecture;
- public contracts;
- team-wide conventions.

Promote a learning to repository documentation when it is:

- repeated;
- broadly useful;
- verified;
- stable;
- relevant to future contributors.

## Memory hygiene

Never persist:

- secrets;
- access tokens;
- personal user data;
- speculative claims;
- transient branches or line numbers;
- duplicated rules;
- unverified incident conclusions.
