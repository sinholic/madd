---
description: "Save a snapshot of the current MADD ship state + working tree. Use before pivoting mid-feature, swapping branches, or any high-blast-radius experiment you want to bail out of."
argument-hint: "[--note <message>] [--no-stash]"
version: "1.0.0"
changelog: |
  1.0.0 — Initial runbook
---

# Runbook: Checkpoint MADD ship state

You are executing `/madd-checkpoint`. Argument: **$ARGUMENTS**

Goal: capture a fully-restorable snapshot of (1) `.madd-ship-state.json` and (2) the working tree, so the user can `/madd-rollback` later.

Distinct from `/madd-ship` Phase 8c "Rollback" — that's a production revert. This is a local pivot guard.

---

## Step 1 — Parse args

- `--note <message>` → human-readable label stored alongside the snapshot.
- `--no-stash` → skip `git stash`; snapshot the JSON only. Default: stash everything.

If `--note` missing, derive default note from state file (feature + phase) or ask user.

---

## Step 2 — Pre-flight

`Bash`:
```bash
git rev-parse --show-toplevel 2>/dev/null && \
  cd "$(git rev-parse --show-toplevel)" && pwd
```

If not in a git repo → abort: "Run inside a project."

`Bash`:
```bash
test -f .madd-ship-state.json && echo HAS_STATE || echo NO_STATE
```

If NO_STATE → ask user via `AskUserQuestion`:
- "No active ship state. Checkpoint anyway?"
- options:
  - "Yes — snapshot working tree only (no state file)"
  - "No — abort"

If user picks "No" → exit cleanly with hint: "Run `/madd-ship` first to create state, then checkpoint mid-cycle."

---

## Step 3 — Derive snapshot id

`Bash`:
```bash
date -u +"%Y%m%dT%H%M%SZ"
```

Capture as `STAMP`.

Snapshot file: `.madd-ship-state.backup-<STAMP>.json`.

Stash message: `madd-checkpoint <STAMP> <feature> <phase>` (use `manual` for feature/phase if no state).

---

## Step 4 — Copy state file (if present)

`Bash`:
```bash
cp .madd-ship-state.json ".madd-ship-state.backup-$STAMP.json"
```

Then `Edit` the backup to append a `_checkpoint` metadata key:
```json
{
  ...existing fields...,
  "_checkpoint": {
    "stamp": "<STAMP>",
    "note": "<NOTE or empty>",
    "branch_at_checkpoint": "<git branch --show-current>",
    "head_at_checkpoint": "<git rev-parse HEAD>"
  }
}
```

Use jq if available, otherwise rewrite via `node -e`.

---

## Step 5 — Stash working tree (unless `--no-stash`)

`Bash`:
```bash
git status --porcelain | head -1
```

If output empty (clean tree) → record `STASH_REF=""` and skip the stash.

Otherwise:
```bash
git stash push -u -m "madd-checkpoint $STAMP $FEATURE phase=$PHASE: $NOTE"
git stash list | head -1
```

Capture top-of-stash ref (e.g. `stash@{0}`) as `STASH_REF`.

Append `STASH_REF` to the backup JSON's `_checkpoint` block:

```json
"_checkpoint": {
  ...,
  "stash_ref": "stash@{0}",
  "stash_subject": "madd-checkpoint <STAMP> ..."
}
```

(Stash refs reshuffle after later stashes. Stash subject is the durable handle — `/madd-rollback` will resolve subject → current ref before popping.)

---

## Step 6 — Write checkpoint log

Append-only `MADD-CHECKPOINTS.md` at repo root for human auditability:

```bash
test -f MADD-CHECKPOINTS.md && echo EXISTS
```

If missing, `Write` template:
```markdown
# MADD Checkpoints

Local snapshot log written by `/madd-checkpoint`. Append-only. Restore via `/madd-rollback`.
```

`Edit` to append:
```markdown

## <STAMP>

- Feature: <feature or "—">
- Phase: <phase or "—">
- Branch: <branch>
- Head: <short-sha>
- Note: <NOTE>
- Stash: <STASH_REF> (subject: "<stash subject>")
- State backup: `.madd-ship-state.backup-<STAMP>.json`
```

---

## Step 7 — Print summary

```
✓ Checkpoint <STAMP>
  Feature:  <feature>
  Phase:    <phase>
  Branch:   <branch> @ <short-sha>
  Stash:    <STASH_REF or "(clean tree — no stash)">
  Backup:   .madd-ship-state.backup-<STAMP>.json
  Log:      MADD-CHECKPOINTS.md

Restore with: /madd-rollback
```

If `--no-stash`:
```
⚠ State backed up; working tree NOT stashed.
  /madd-rollback will restore state only.
```

---

## Failure modes

| Symptom | Cause | Recovery |
|---------|-------|----------|
| `git stash push` fails — no changes | Tree was clean | Skip stash; record empty STASH_REF |
| `git stash push -u` fails — submodules dirty | Submodule state | Re-run with `--no-stash`; warn user about submodule state not captured |
| Multiple checkpoints same second | User scripted bulk | Append `-<n>` suffix to STAMP |
| `.madd-ship-state.json` malformed | Corrupt | Copy verbatim anyway; print warning; `/madd-rollback` will surface the issue |
| Repo too large for stash | Untracked binaries | Suggest `--no-stash` + manual `git stash -k` (keep-index) |

---

## Caveats

- Checkpoints are **local-only**. Stashes do not push to remote; backup JSON files are gitignored by `/madd-init`. Treat as personal undo buffer.
- Do not pile up checkpoints indefinitely. After a successful ship completion, sweep old snapshots with: `rm .madd-ship-state.backup-*.json` (or extend this command with `--clean` flag in v1.1).
- `--no-stash` mode does not capture untracked files. If you have unsaved sketches outside git, save them manually first.
- Stash subjects, not stash refs, are the durable handle. Refs reshuffle when a new stash lands.
