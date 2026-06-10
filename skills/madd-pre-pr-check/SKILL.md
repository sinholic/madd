---
name: madd-pre-pr-check
description: "Use this skill when the user is about to open a pull request or push a feature branch — phrases like 'open a PR', 'create the PR', 'push this branch', 'gh pr create', 'glab mr create', 'ready for review', 'time to merge'. Runs /madd-review and /madd-secure on the current diff before the PR opens so reviewers see clean code. Only fires when AGENTS.md is MADD-initialized AND the diff against the base branch is non-empty."
---

# Skill: Pre-PR check

You were triggered because the user is preparing to open a PR / push a feature branch. Your job is to run review + security audits on the current diff before the PR is visible to humans — catching findings while it's cheap to fix.

## What to do

1. **Confirm scope** with a single `AskUserQuestion`:

   - "Run pre-PR check (review + security) on current diff against `<base>`?"
   - Options:
     - "Yes — both" (Recommended)
     - "Review only"
     - "Security only"
     - "Skip — proceed to PR"

   Use `$BASE` from `.madd-ship-state.json` if present, otherwise `git symbolic-ref refs/remotes/origin/HEAD`.

2. **Run review** (if selected): invoke `/madd-review --diff <base>...HEAD`. Wait for `REVIEW.md` to land. Surface findings by severity.

3. **Run security** (if selected): invoke `/madd-secure --diff <base>...HEAD`. Wait for `SECURITY.md`. Surface findings by severity.

4. **Gate the PR**:

   - If either skill reports a `CRITICAL` finding → `AskUserQuestion`:
     - "Critical finding(s) detected. Open PR anyway?"
     - Options:
       - "No — fix first" (Recommended)
       - "Yes — flag in PR description"
       - "Cancel"

   - If only `HIGH` / `MEDIUM` / `LOW` → present count summary; let user proceed with one-tap "Open PR" or fix iteratively.

5. **If user proceeds**, do not block. Hand back to `/madd-ship` Phase 6 (or whichever skill triggered this) with the findings summary in scope so it can be included in the PR description.

## When to *not* fire

- No diff against base (`git diff --quiet <base>...HEAD`) → silently skip; nothing to review.
- AGENTS.md missing or doesn't reference MADD → not a MADD project, don't impose.
- User already ran `/madd-review` and `/madd-secure` in this session and both came back clean → don't re-run; just confirm the prior run still applies.
- User flagged `--draft` or PR is "WIP/draft" → fire but lower urgency; allow critical-but-flagged.

## Related

- `/madd-review` — source review runbook
- `/madd-secure` — security audit runbook
- `/madd-ship` Phase 6 — where the PR actually opens
