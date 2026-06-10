# Phase 8 — Production

## 8a. Promote PR/MR + merge to base

Dispatch by `PLATFORM` from Phase 6:

**GITHUB:**
```bash
gh pr ready              # promote draft
# Wait for CI / reviewer if required
gh pr merge --squash     # or --merge / --rebase per AGENTS.md merge policy
```

**GITLAB:**
```bash
glab mr update --ready
# Wait for pipeline / approval
glab mr merge --squash
```

**BITBUCKET / other:** instruct user merge via web UI; wait for confirmation.

After merge, sync local base:
```bash
git checkout "$BASE"
git pull --ff-only origin "$BASE"
```

Then deploy:
```bash
<DEPLOY_CMD>
```

## 8b. Verify live

Check live URL matches acceptance criteria. Report status.

**[state]** After live verify passes: `phase = "8"`, `phase_started = now`, `deployed_at = <ISO>`, `live_url = <if available>`.

## 8c. Rollback path (if live verify fails)

```bash
git log --oneline -5
```

`AskUserQuestion`:
- question: "Rollback required?"
- header: "Rollback"
- options: "No — live verify passed" / "Yes — revert + redeploy"

If yes: second `AskUserQuestion` for commit hash. Verify hash exists:
```bash
git cat-file -e <hash>^{commit} && echo OK || echo MISSING
```

Only if OK:
```bash
git revert -n <hash>
git commit -m "Rollback: <feature>"
git push
<BUILD_CMD>
<DEPLOY_CMD>
```

## 8d. Capture learnings

Always prompt:

> Phase 8 complete. Capture learnings:
>   `/madd-learn <feature-name> --confidence <1-5> --tags <tags>`
> Or interactive:
>   `/madd-learn <feature-name>`

Do not auto-run. `madd-post-learn` skill will also fire passively on merge detection.

## 8e. Cycle cleanup

`AskUserQuestion`:
- question: "Ship complete. Clean up `.madd-ship-state.json` and checkpoints?"
- header: "Cleanup"
- options:
  - "Yes — archive state to `.madd-ship-archive/`" (Recommended)
  - "Yes — delete outright"
  - "No — keep state file"

On archive:
```bash
mkdir -p .madd-ship-archive
mv .madd-ship-state.json ".madd-ship-archive/<feature>-<ISO>.json"
```

On delete:
```bash
rm -f .madd-ship-state.json
```

Leave `.madd-ship-state.backup-*.json` for manual sweep.

Return to orchestrator → ship complete.
