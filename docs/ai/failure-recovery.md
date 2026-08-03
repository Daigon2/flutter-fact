---
id: AI-RECOVERY
status: accepted
owner: ai
scope:
  - ai
load_when:
  - tool_failure
  - partial_failure
---

# Failure Recovery

## Agent uncertainty

Search existing evidence before asking. Escalate when uncertainty concerns product intent, risk acceptance or irreversible design.

## Tool failure

- retry only when failure is plausibly transient;
- do not repeat destructive commands;
- capture relevant error output;
- continue with safe partial work where possible;
- state what remains unverified.

## Partial implementation

Leave the repository buildable whenever possible. Do not disguise incomplete behavior as complete.

## Conflicting agent results

The orchestrator/main agent compares evidence, not confidence. Escalate unresolved material conflict.

## Bad generated change

Revert or repair the smallest affected scope. Do not layer compensating abstractions over misunderstood code.

## Hook failure

Treat blocking hook failure as a failed operation. Fix the underlying issue or explicitly obtain approval to change the hook; never bypass silently.
