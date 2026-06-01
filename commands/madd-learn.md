---
description: "Capture learnings from completed /madd-ship feature. Stores to agent memory MCP (primary) with LEARNINGS.md fallback. Real tool calls."
argument-hint: "<feature-name> [--confidence 1-5] [--tags tag1,tag2] [--from-worklog]"
version: "2.0.0"
changelog: |
  2.0.0 — Runbook rewrite: correct MCP tool names, real availability detection, real WORKLOG parser, schema validation
  1.0.0 — Aspirational doc (wrong tool name, no detect)
---

# Runbook: Capture MADD feature learnings

You are executing `/madd-learn`. Argument: **$ARGUMENTS**

Goal: store post-ship learnings (what worked, what failed, decisions) to agent memory for future recall.

---

## Step 1 — Parse arguments

Parse `$ARGUMENTS` for:
- `<feature-name>` — first positional arg (required unless `--from-worklog`)
- `--confidence <1-5>` — numeric (default: ask user)
- `--tags <comma,separated>` — tag list (default: ask user)
- `--from-worklog` — auto-extract last WORKLOG entry

If `<feature-name>` missing and no `--from-worklog`: ask user via `AskUserQuestion`.

---

## Step 2 — Locate repo root

`Bash`:
```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
git branch --show-current
```

Capture: `REPO_ROOT`, `BRANCH`.

---

## Step 3 — Collect learning content

### 3a. If `--from-worklog`

`Bash`:
```bash
test -f WORKLOG.md && \
  awk '/^## /{n++; if(n>1) exit} n==1 || /^## /' WORKLOG.md | tail -n +1
```

Extract last `## <feature> — <date>` block. Parse bullets as raw content.

Show extracted block to user. `AskUserQuestion`:
- question: "Use this WORKLOG entry as learning source?"
- header: "Source"
- options:
  - "Use as-is"
  - "Edit before storing"
  - "Cancel — provide manually"

### 3b. Otherwise — interactive collection

`AskUserQuestion` (batch up to 4):

1. question: "What worked? Bullet list (decisions, patterns that helped)"
   - header: "Worked"
   - options: free-text via "Other"

2. question: "What failed? Bullet list (blockers, gotchas + how resolved)"
   - header: "Failed"
   - options: free-text via "Other"

3. question: "Confidence in these learnings?"
   - header: "Confidence"
   - options: "1 — uncertain" / "2" / "3 — default" / "4" / "5 — highly confident"

4. question: "Tags (comma-separated)? e.g. astro, vitest, schema-migration"
   - header: "Tags"
   - options: common defaults + "Other"

Build `LEARNING` object:
```
{
  feature: <feature-name>,
  date: <ISO from `date -u +%Y-%m-%d`>,
  branch: <BRANCH>,
  worked: [bullet1, bullet2, ...],
  failed: [bullet1, bullet2, ...],
  confidence: <1-5>,
  tags: [tag1, tag2, ...]
}
```

---

## Step 4 — Detect MCP availability

Check whether agent memory MCP is connected.

The Claude Code MCP tools surface as `mcp__<server>__<tool>` names. Available memory servers (by priority):

| Priority | Server | Save tool name |
|----------|--------|----------------|
| 1 | agentmemory | `mcp__agentmemory__memory_lesson_save` |
| 2 | agentmemory | `mcp__agentmemory__memory_save` (general save) |
| 3 | openmemory-local | `add_memory` (some envs expose without prefix) |

Detection: attempt highest-priority tool. If `InputValidationError: tool not found` → try next. If all fail → fall through to Step 6 (file fallback).

You can also inspect `<system-reminder>` blocks earlier in the session for surfaced MCP tool names matching `mcp__.*memory.*`.

---

## Step 5 — Store to MCP (if available)

### 5a. Schema-shape the payload

For `mcp__agentmemory__memory_lesson_save`, construct:

```
content: "MADD Feature: <feature-name>
Worked:
- <bullet 1>
- <bullet 2>
Failed:
- <bullet 1>
- <bullet 2>
Branch: <branch>
Date: <ISO date>"

type: "pattern"  # or "anti-pattern" if tagged so
confidence: <1-5 mapped to 0.0-1.0>  // e.g. 4 → 0.8
context: "<framework> + <test-runner> (project: <repo basename>)"
concepts: "madd,feature-delivery,<framework>,<test-runner>,<primary tags>"
tags: [<feature-name>, "madd", <all user tags>]
```

Confidence map: 1→0.2, 2→0.4, 3→0.6, 4→0.8, 5→1.0.

### 5b. Validate before send

- `content`: non-empty, <4000 chars
- `confidence`: numeric 0.0-1.0
- `tags`: array of strings, all lowercase, no spaces (replace with `-`)
- `concepts`: comma-separated string

If invalid → trim/coerce. Never send malformed payload.

### 5c. Call MCP tool

Use the actual MCP tool. If `mcp__agentmemory__memory_lesson_save` returns success → record success, proceed to Step 7.

If it errors → try `mcp__agentmemory__memory_save` with simplified payload:
```
content: <same as above>
metadata: {feature, branch, date, tags, confidence}
```

If both error → fall to Step 6.

---

## Step 6 — File fallback (LEARNINGS.md)

If MCP unavailable or all save attempts errored:

### 6a. Check / create LEARNINGS.md

`Bash`:
```bash
test -f LEARNINGS.md && echo EXISTS
```

If missing, `Write` to `<REPO_ROOT>/LEARNINGS.md`:
```markdown
# LEARNINGS.md

Captured learnings from `/madd-ship` features. MCP fallback when agent memory unavailable.

Append-only. One entry per feature.
```

### 6b. Append entry via `Edit`

Append at end of file:

```markdown

## <feature-name> — <ISO-date>

**Branch:** <branch>
**Confidence:** <1-5>/5
**Tags:** <comma-separated tags>

**What worked:**
- <bullet>
- <bullet>

**What failed:**
- <bullet>
- <bullet>

---
```

### 6c. Note for later sync

`Bash` (only if MCP was tried and failed):
```bash
echo "<ISO-date> <feature-name>" >> .madd-pending-sync 2>/dev/null
```

This marks entries for future MCP retry (could be picked up by a `/madd-sync` cmd later).

---

## Step 7 — Summary

Report to user:

```
✓ Learning captured: <feature-name>
  Storage: <MCP: agentmemory | File: LEARNINGS.md>
  Confidence: <1-5>/5
  Tags: <tags>

  {if MCP}  Recall via: memory_smart_search("<feature> <tag>")
  {if file} View: cat LEARNINGS.md
```

If both MCP attempts failed:
```
⚠ MCP unavailable — stored to LEARNINGS.md as fallback
  Pending sync: .madd-pending-sync
```

---

## Failure modes

| Symptom | Cause | Recovery |
|---------|-------|----------|
| `tool not found` for MCP | Server not connected in this env | Fall to next priority; eventually file fallback |
| `WORKLOG.md not found` with `--from-worklog` | Feature didn't use `/madd-ship` v2.0.0+ | Switch to interactive mode |
| Empty `worked` and `failed` lists | User skipped both | Ask again — at least one bullet required |
| `LEARNINGS.md` perm denied | Read-only fs | Report to user; suggest alt path |
| `git branch --show-current` empty | Detached HEAD | Use `git rev-parse --short HEAD` instead |

---

## Recall later

To retrieve stored learnings in future sessions:

`mcp__agentmemory__memory_smart_search` with query like:
- "MADD astro schema migration"
- "MADD <framework> patterns"
- "MADD anti-pattern <topic>"

Or read `LEARNINGS.md` directly in repo.

`/madd-ship` future runs may auto-query relevant learnings during Phase 1 to surface prior gotchas.

---

## Caveats

- This skill makes **real** MCP calls when available. Do not simulate.
- Schema-validate **before** sending — malformed payloads waste round-trips and pollute memory.
- File fallback is not a "lesser" mode — it's a first-class persistence path, just local.
- Never silently drop a learning. If both MCP and file fail → loud error to user with raw payload printed so they can save manually.
