---
name: madd-post-learn
description: "Use this skill after a PR or MR has just been merged successfully — triggered by phrases like 'PR merged', 'shipped to production', 'deployment done', 'feature is live', or after observing a 'gh pr merge' / 'glab mr merge' call that returned success. Prompts the user to capture learnings via /madd-learn before the context goes cold. Only fires if the merged branch matches an entry in WORKLOG.md (i.e., it came through /madd-ship)."
---

# Skill: Post-merge learning capture

You were triggered because a MADD-shipped PR just merged. Your job is to harvest learnings while the user still remembers what was non-obvious — not days later when the context has decayed.

## What to do

1. **Confirm the merge** is real, not a false signal. Run `git log -1 --oneline` and `git branch --show-current` — if the user is back on the base branch after a `gh pr merge` / `glab mr merge`, the trigger was correct.

2. **Identify the merged feature** by reading the last `## ` heading in `WORKLOG.md`. That's the feature name `/madd-ship` Phase 4 wrote. If WORKLOG.md is missing or empty → skip silently; not a MADD ship.

3. **Offer learning capture** via `AskUserQuestion`:

   - "PR merged for `<feature>`. Capture learnings now?"
   - Options:
     - "Yes — auto from WORKLOG" → invoke `/madd-learn <feature> --from-worklog` (Recommended; fast, uses the decision log)
     - "Yes — interactive" → `/madd-learn <feature>` (slower; user fills bullets directly)
     - "Skip — capture later" → print one-liner reminding the user to run `/madd-learn` manually
     - "Cancel — already captured" → exit silently

4. **Don't pester.** This skill fires once per merge. If the user picks "Skip" or "Cancel", do not re-fire in the same session even if they mention the feature again.

## When to *not* fire

- No `WORKLOG.md` → not a MADD ship.
- `.madd-learn-captured-<feature>` marker file present at repo root → already captured this cycle (the user can clear the marker to re-capture).
- The user just rolled back (recent `Rollback:` commit on base) — capturing during a rollback is noise; wait for the next clean merge.
- Hotfix-mode ship (`SHIP_MODE = Hotfix` recorded in last `.madd-ship-state.json` snapshot) — optional capture, prompt with "Yes" deprioritized.

## After capture

If `/madd-learn` succeeds:

```bash
date -u +%Y%m%dT%H%M%SZ > .madd-learn-captured-<feature>
```

This marker file prevents double-firing within the session. It is gitignored by `/madd-init`.

## Related

- `/madd-learn` — the write side
- `/madd-recall` — read it back later
- `/madd-ship` Phase 8d — also reminds about `/madd-learn`; this skill is the lighter-touch passive trigger
