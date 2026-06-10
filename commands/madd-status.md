---
description: "One-screen MADD status digest. Reads .madd-ship-state.json + .madd-debug.md + WORKLOG.md last entry + git state. No mutations."
argument-hint: "[--terse] [--json]"
version: "1.0.0"
changelog: |
  1.0.0 — Initial runbook
---

# Runbook: Show MADD status

You are executing `/madd-status`. Argument: **$ARGUMENTS**

Goal: in one screen, tell the user where every MADD-touched workflow stands so they can resume cold.

Read-only. No edits, no commits, no MCP writes.

---

## Step 1 — Parse args

- `--terse` → print only 1-line headline per source.
- `--json` → emit structured JSON instead of formatted digest. Useful for skills (e.g. `madd-ship-resume`) parsing it.

---

## Step 2 — Locate repo + project context

`Bash` (parallel calls — not chained):

```bash
git rev-parse --show-toplevel 2>/dev/null
```
```bash
git branch --show-current 2>/dev/null
```
```bash
git status --porcelain 2>/dev/null | wc -l
```
```bash
git log --oneline -5 2>/dev/null
```

If not in a git repo → report: "Not in a git repository. /madd-status needs a project." Exit.

Capture: `REPO_ROOT`, `BRANCH`, `DIRTY_COUNT`, `RECENT_LOG`.

---

## Step 3 — Read state sources (parallel)

`Bash` calls — separate, parallel, do not chain with `&&`:

### 3a. Ship state

```bash
test -f .madd-ship-state.json && cat .madd-ship-state.json || echo MISSING
```

Parse JSON. Capture:
- `SHIP_FEATURE`, `SHIP_PHASE`, `SHIP_MODE`, `SHIP_WORK_TYPE`
- `SHIP_BRANCH`, `SHIP_STARTED`
- `SHIP_RED_OK`, `SHIP_LAST_TEST_EXIT`

If MISSING → `SHIP_PHASE = "none"`.

### 3b. Debug state

```bash
test -f .madd-debug.md && head -20 .madd-debug.md || echo MISSING
```

If present, extract first heading + last hypothesis line. Capture `DEBUG_TOPIC`, `DEBUG_LAST_LINE`.

### 3c. WORKLOG last entry

```bash
test -f WORKLOG.md && awk '/^## / { last = $0 } END { print last }' WORKLOG.md || echo MISSING
```

Capture `WORKLOG_LAST` (e.g. `## add-hello-endpoint — 2026-06-11`).

### 3d. Pending learn sync

```bash
test -f .madd-pending-sync && wc -l < .madd-pending-sync || echo 0
```

Capture `PENDING_LEARN` count.

### 3e. AGENTS.md presence

```bash
test -f AGENTS.md && echo OK || echo MISSING
```

Capture `AGENTS_OK`. If MISSING flag prominently: project not MADD-initialized.

### 3f. Checkpoint snapshots

```bash
find . -maxdepth 1 -name '.madd-ship-state.backup-*.json' 2>/dev/null | wc -l
```

Capture `CHECKPOINT_COUNT`.

---

## Step 4 — Print digest

### 4a. Full mode (default)

```
MADD status — <project basename>
Branch: <BRANCH> (<DIRTY_COUNT> uncommitted)

┌─ Ship ────────────────────────────────────────────
│ Feature:   <SHIP_FEATURE or "—">
│ Phase:     <SHIP_PHASE> (<SHIP_MODE>, <SHIP_WORK_TYPE>)
│ Started:   <SHIP_STARTED>
│ RED gate:  <SHIP_RED_OK ? "confirmed" : "not yet">
│ Last test: exit <SHIP_LAST_TEST_EXIT> <or "—">
│ Checkpoints: <CHECKPOINT_COUNT>
└──────────────────────────────────────────────────

┌─ Debug ───────────────────────────────────────────
│ Topic: <DEBUG_TOPIC or "no active session">
│ Last:  <DEBUG_LAST_LINE>
└──────────────────────────────────────────────────

┌─ Learn ───────────────────────────────────────────
│ WORKLOG last: <WORKLOG_LAST or "—">
│ Pending sync: <PENDING_LEARN> entries
└──────────────────────────────────────────────────

┌─ Hygiene ─────────────────────────────────────────
│ AGENTS.md: <AGENTS_OK>
│ Recent commits:
│   <RECENT_LOG indented>
└──────────────────────────────────────────────────

Next:
  - Resume ship       → /madd-ship <feature>            (Step 0j will offer resume)
  - Continue debug    → /madd-debug
  - Capture learning  → /madd-learn <feature>
  - Recall prior      → /madd-recall <keywords>
```

If `SHIP_PHASE = "none"` and `DEBUG_TOPIC = ""` → drop the "Next" section for ship/debug; just show:

```
No active ship or debug session. Use /madd-ship <feature> to start.
```

### 4b. Terse mode (`--terse`)

One line per active source. Format:
```
ship: <feature> phase=<N> | debug: <topic> | worklog: <last> | pending-learn: <N>
```

Use `—` for empty sources. If all empty:
```
MADD idle on <branch>
```

### 4c. JSON mode (`--json`)

Emit:
```json
{
  "project": "<basename>",
  "branch": "<BRANCH>",
  "dirty_count": <N>,
  "ship": { "feature": "...", "phase": "...", "mode": "...", "work_type": "...", "started": "...", "red_ok": true, "last_test_exit": 0, "checkpoint_count": 0 },
  "debug": { "topic": "...", "last_line": "..." },
  "learn": { "worklog_last": "...", "pending_sync": 0 },
  "hygiene": { "agents_md": true, "recent_commits": ["...", "..."] }
}
```

When invoked by another skill, prefer JSON mode for downstream parsing.

---

## Failure modes

| Symptom | Cause | Recovery |
|---------|-------|----------|
| All sources MISSING | Fresh repo with no MADD use | Suggest `/madd-init` + first `/madd-ship` |
| JSON parse fails on state file | Corrupt write or hand-edit | Show raw file contents; suggest `/madd-rollback` |
| `git branch --show-current` empty | Detached HEAD | Use `git rev-parse --short HEAD` as fallback display |
| Pending sync file present without LEARNINGS.md | `/madd-learn` partially completed | Hint user to re-run `/madd-learn --from-worklog` |

---

## Caveats

- This skill makes **real** Bash calls. Do not simulate the file reads.
- No mutations. If a state file looks wrong, point at it — do not heal silently.
- Parallel Bash for Step 3 — not chained `&&`. Chained aborts on first non-zero exit and silently zeros out the next sources.
