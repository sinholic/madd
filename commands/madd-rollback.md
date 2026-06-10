---
description: "Restore a /madd-checkpoint snapshot — replaces .madd-ship-state.json from backup and optionally pops the matching git stash. Distinct from /madd-ship Phase 8c rollback (that's production revert)."
argument-hint: "[--stamp <STAMP>] [--state-only] [--list]"
version: "1.0.0"
changelog: |
  1.0.0 — Initial runbook
---

# Runbook: Roll back to a MADD checkpoint

You are executing `/madd-rollback`. Argument: **$ARGUMENTS**

Goal: restore a prior `/madd-checkpoint` snapshot — `.madd-ship-state.json` and (optionally) the matching `git stash`.

This is **local pivot recovery**. Not production rollback (that's `/madd-ship` Phase 8c with `git revert`).

---

## Step 1 — Parse args

- `--stamp <STAMP>` → restore specific snapshot directly (skip the picker).
- `--state-only` → restore JSON only; do not pop stash.
- `--list` → show available checkpoints, exit without restoring.

---

## Step 2 — Locate repo + list snapshots

`Bash`:
```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
```

`Bash`:
```bash
find . -maxdepth 1 -type f -name '.madd-ship-state.backup-*.json' 2>/dev/null | sort
```

Capture as `SNAPSHOTS` list. If empty → report:
> No checkpoints found. Use `/madd-checkpoint` to create one before pivoting.

Exit cleanly.

---

## Step 3 — Build choice list

For each snapshot file, parse the `_checkpoint` metadata block to extract:
- `stamp`
- `note`
- `branch_at_checkpoint`
- `head_at_checkpoint` (short)
- `stash_subject` (may be empty)

`Bash` per file (or single `node -e` reading all):
```bash
node -e "
const fs = require('fs');
const files = process.argv.slice(1);
for (const f of files) {
  try {
    const j = JSON.parse(fs.readFileSync(f, 'utf8'));
    const c = j._checkpoint || {};
    console.log([c.stamp || f, c.note || '', c.branch_at_checkpoint || '?', (c.head_at_checkpoint || '').slice(0, 7), c.stash_subject || ''].join('\t'));
  } catch (e) {
    console.log([f, '<corrupt>', '?', '?', ''].join('\t'));
  }
}
" .madd-ship-state.backup-*.json
```

### 3a. `--list` mode

Print table:

```
STAMP                  NOTE                       BRANCH                    HEAD     STASH
20260611T103000Z       phase-3 sandbox            feat/add-hello-endpoint   abc1234  stash@... (subject)
20260611T120000Z       before bigger refactor     feat/add-hello-endpoint   def5678  (no stash)
```

Exit.

### 3b. Default mode

If `--stamp` provided: jump to Step 4 with that stamp.

Otherwise `AskUserQuestion`:
- question: "Which checkpoint to restore?"
- header: "Rollback"
- options: each entry, label = `<STAMP> — <NOTE>` (max 4 per batch; if more, ask in tranches).

Store choice as `SELECTED_STAMP`.

---

## Step 4 — Confirmation gate

Read selected backup file → `BACKUP_PATH = .madd-ship-state.backup-<SELECTED_STAMP>.json`.
Read current state → `CURRENT_PATH = .madd-ship-state.json` (may not exist).

Show user a 3-line diff:
- `CURRENT: feature=X phase=Y branch=Z` (or `(none)`)
- `BACKUP:  feature=A phase=B branch=C`
- `STASH:   <stash_subject or "(none)">`

`AskUserQuestion`:
- question: "Restore this checkpoint? Current state will be overwritten."
- header: "Confirm"
- options:
  - "Yes — restore state + pop stash (if any)" (Recommended unless `--state-only`)
  - "Yes — state only (skip stash pop)"
  - "Cancel"

If user picks Cancel → exit cleanly.

If `--state-only` flag passed at invocation, skip the question and proceed in state-only mode.

---

## Step 5 — Pre-restore safety net

Before overwriting, snapshot the *current* state so the user can undo a misclicked rollback:

`Bash`:
```bash
PRE_STAMP=$(date -u +"%Y%m%dT%H%M%SZ")
if [ -f .madd-ship-state.json ]; then
  cp .madd-ship-state.json ".madd-ship-state.backup-${PRE_STAMP}-pre-rollback.json"
fi
```

Print to user: "Saved pre-rollback safety snapshot: `.madd-ship-state.backup-<PRE_STAMP>-pre-rollback.json`".

---

## Step 6 — Restore state file

`Bash`:
```bash
cp ".madd-ship-state.backup-${SELECTED_STAMP}.json" .madd-ship-state.json
```

Then strip the `_checkpoint` metadata key from the restored file (it's noise outside the backup):

```bash
node -e "
const fs = require('fs');
const j = JSON.parse(fs.readFileSync('.madd-ship-state.json', 'utf8'));
delete j._checkpoint;
fs.writeFileSync('.madd-ship-state.json', JSON.stringify(j, null, 2));
"
```

---

## Step 7 — Pop stash (if applicable)

Skip if:
- `--state-only` mode
- User picked "state only" in Step 4
- Backup `_checkpoint.stash_subject` is empty

Otherwise resolve subject → current stash ref:

`Bash`:
```bash
SUBJECT="<stash_subject from backup>"
git stash list | grep -F "$SUBJECT" | head -1 | sed 's/:.*//'
```

Capture as `CURRENT_REF` (e.g. `stash@{0}`).

If empty → warn user:
> Stash with subject "<SUBJECT>" not found. It may have been popped, dropped, or never created.
> State file restored; working tree unchanged.

If found:

`AskUserQuestion`:
- question: "Pop stash <CURRENT_REF> ($SUBJECT)? This may produce merge conflicts if current tree has diverged."
- header: "Pop stash"
- options:
  - "Pop (apply + drop)" — `git stash pop <ref>`
  - "Apply (keep stash)" — `git stash apply <ref>`
  - "Skip"

Run chosen command:
```bash
git stash pop "$CURRENT_REF"   # or apply
```

If merge conflicts → report exact conflicting files; tell user to resolve manually. Do NOT auto-abort the stash apply (would lose user's changes).

---

## Step 8 — Update checkpoints log

`Edit` `MADD-CHECKPOINTS.md` — append rollback entry:

```markdown

## Restored <SELECTED_STAMP> at <ISO-now>

- Pre-rollback safety: `.madd-ship-state.backup-<PRE_STAMP>-pre-rollback.json`
- Stash action: <pop|apply|skipped>
- Result: <conflicts? clean?>
```

---

## Step 9 — Summary

```
✓ Restored checkpoint <SELECTED_STAMP>
  State:        .madd-ship-state.json (from backup)
  Stash:        <popped <ref> | applied <ref> | skipped | none>
  Pre-rollback: .madd-ship-state.backup-<PRE_STAMP>-pre-rollback.json

Next:
  - Resume work:  /madd-ship (will detect restored state in Step 0j)
  - Verify state: /madd-status
  - Undo rollback: /madd-rollback --stamp <PRE_STAMP>-pre-rollback
```

---

## Failure modes

| Symptom | Cause | Recovery |
|---------|-------|----------|
| No snapshots found | Never ran `/madd-checkpoint` | Suggest creating one before pivot |
| Backup file corrupt JSON | Bad write or hand-edit | Print raw contents; refuse to restore; ask user to fix or pick another |
| Stash subject not in list | Stash was popped/dropped | Warn; restore state only |
| `git stash apply` conflict | Tree diverged | Print conflicting files; tell user to resolve; stash NOT auto-dropped |
| User picks `--stamp` that doesn't exist | Typo | Suggest `--list` to see valid stamps |

---

## Caveats

- This skill **does** mutate (`Edit` state, `Bash git stash`). Always show the pre-restore diff and require confirmation unless `--stamp` + `--state-only` (script-safe path).
- The pre-rollback safety snapshot is the undo for `/madd-rollback` itself. Do not skip Step 5.
- Restoring does NOT change git HEAD. If the original checkpoint was at a different commit, the user is responsible for `git checkout <head_at_checkpoint>` if needed.
- Production deploy rollback is a different skill — see `/madd-ship` Phase 8c which uses `git revert` against `main`.
- Do not auto-clean old backups. Operator decides when to sweep.
