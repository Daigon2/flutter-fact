---
id: AI-OPERATING
status: accepted
owner: ai
scope:
  - ai
load_when:
  - ai_system_change
  - orchestration
---

# AI Operating Model

## Purpose

The AI system supports engineering judgment without becoming a parallel source of truth.

## Control layers

### 1. Repository truth

Product, ADR, architecture, engineering and feature documents define durable decisions.

### 2. Instructions

`CLAUDE.md` contains compact facts that matter in almost every task. Path-scoped rules activate only for relevant files.

### 3. Skills

Skills encode repeatable procedures such as feature implementation, bug fixing and review.

### 4. Agents

Agents isolate specialized exploration, implementation and review. They do not own product decisions.

### 5. Hooks and CI

Hooks provide deterministic lifecycle checks. CI is the authoritative merge gate.

### 6. Human authority

Humans own product intent, risk acceptance and high-impact decisions.

## Standard task lifecycle

```text
Intake
→ classify
→ gather bounded context
→ identify decisions
→ plan
→ execute
→ self-review
→ verify
→ independent review
→ summarize
→ update durable knowledge when warranted
```

## Non-goals

- autonomous product strategy;
- invisible architecture changes;
- agent-to-agent debate without accountable synthesis;
- storing every task history as permanent memory;
- replacing CI or human risk ownership with prompts.
