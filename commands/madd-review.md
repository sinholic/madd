---
description: "Review source code for bugs, security issues, code quality. Produces REVIEW.md with severity-classified findings. Real tool calls."
argument-hint: "[--diff | --files <paths> | --pr <num>] [--severity high|all] [--fix]"
version: "1.0.0"
changelog: |
  1.0.0 — Initial runbook: scoped review, severity classification, optional auto-fix
---

# Runbook: Source code review

You are executing `/madd-review`. Args: **$ARGUMENTS**

Goal: surface bugs, security issues, and quality problems. Classify by severity. Optionally auto-fix.

---

## Step 0 — Pre-flight

`Bash`:
```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
git status --short
```

`Read`: `AGENTS.md` — extract `LANGUAGE`, `FRAMEWORK`, conventions (`COMMENT_STYLE`, `ERROR_POLICY`).

---

## Step 1 — Determine review scope

Parse $ARGUMENTS for scope flag:

- `--diff` → unstaged + staged changes only
- `--files <paths>` → explicit paths (space-separated)
- `--pr <num>` → fetch PR diff via `gh pr diff <num>`
- (no flag) → ask user

If no flag → `AskUserQuestion`:
- "What to review?"
- Options:
  - "Unstaged + staged diff" — `git diff HEAD`
  - "Last commit" — `git show HEAD`
  - "Current PR" — auto-detect via `gh pr view --json number -q .number`
  - "Specific files" — ask path

Build `SCOPE` = list of files + diff content.

`Bash` (per scope choice):
```bash
# Diff:
git diff HEAD --name-only && git diff HEAD

# Last commit:
git show --stat HEAD && git show HEAD

# PR:
gh pr diff <num>

# Files:
ls <path-1> <path-2> && git diff HEAD -- <paths>
```

---

## Step 2 — Read files in scope

For each file in `SCOPE`: `Read` full file. Hold contents for analysis.

If scope is too large (>20 files): warn user, suggest narrowing via `--files`.

---

## Step 3 — Analyze across review dimensions

For each file, check:

### 3a. Correctness bugs
- Off-by-one errors
- Null / undefined access without guard
- Race conditions (async without await, shared mutable state)
- Wrong comparison operators (`==` vs `===`, `<` vs `<=`)
- Type coercion footguns
- Resource leaks (unclosed handles, listeners)

### 3b. Security issues
- SQL injection (string concat into query)
- XSS (unescaped user input → HTML)
- Path traversal (user input → fs path)
- Command injection (user input → shell)
- Secrets in source (API keys, tokens, passwords)
- Missing auth checks on protected endpoints
- Permissive CORS / CSP
- Insecure deserialization

### 3c. Quality / maintainability
- Duplication (3+ instances of same logic)
- Dead code (unused exports, unreachable branches)
- Inconsistent naming vs project conventions
- Comments that lie (describe stale behavior)
- Missing tests for new logic
- Violation of AGENTS.md conventions (feature flags, comment style, error handling)

### 3d. Performance (high-impact only)
- N+1 queries
- Sync I/O in hot path
- O(n²) where O(n) trivially achievable
- Memory leaks (unbounded caches, retained references)

**Skip:** taste-based stylistic feedback. Skip nitpicks. Severity floor.

---

## Step 4 — Classify findings

For each issue, assign:

- **CRITICAL** — security vulnerability, data loss risk, prod outage path
- **HIGH** — correctness bug, missing auth, broken edge case
- **MEDIUM** — duplication, dead code, missing test, convention violation
- **LOW** — comment rot, minor naming, opportunistic cleanup

Filter by `--severity high|all` flag (default: `all`).

---

## Step 5 — Write REVIEW.md

`Write` to `<repo-root>/REVIEW.md`:

```markdown
# Code Review — <ISO date>

**Scope:** <scope summary>
**Files reviewed:** <count>
**Findings:** <total> (Critical: N, High: N, Medium: N, Low: N)

---

## CRITICAL

### 1. <one-line title>
**File:** `<path>:<line>`
**Issue:** <description>
**Why critical:** <impact>
**Fix:**
\`\`\`<lang>
<code suggestion>
\`\`\`

---

## HIGH

### 2. ...

---

## MEDIUM

### 3. ...

---

## LOW

### 4. ...

---

## Summary

- Total findings: N
- Recommend fix order: Critical → High → Medium
- Files needing most attention: <top 3>
```

If no findings → write a short REVIEW.md saying "No issues found at <severity> level in <scope>."

---

## Step 6 — Report + optional fix

Print summary to user. Then:

If `--fix` in args OR `AskUserQuestion`:
- "Apply fixes now?"
- Options:
  - "Apply Critical + High" — auto-fix top severities
  - "Apply all" — auto-fix everything REVIEW.md flagged
  - "Selective" — per-finding confirm
  - "No — review only"

For each finding to fix:
1. `Read` target file
2. `Edit` with suggested fix
3. Re-run `<TEST_CMD>` if applicable
4. Mark fixed in REVIEW.md (strikethrough or "FIXED" tag)

After fixes:
```bash
git diff
```

Show user. Then `AskUserQuestion`:
- "Commit fixes?"
- Options:
  - "Yes — single commit"
  - "Yes — one commit per finding"
  - "No — leave staged"

If commit: prefix with `fix:` per finding type, or `refactor:` for quality fixes.

---

## Step 7 — Optional: post to PR

If `--pr <num>` was used `AskUserQuestion`:
- "Post REVIEW.md as PR comment?"
- Options:
  - "Yes" — `gh pr comment <num> --body-file REVIEW.md`
  - "No"

---

## Failure modes

| Symptom | Recovery |
|---------|----------|
| Scope too large | Narrow via `--files`; do in batches |
| `gh` not authenticated | `gh auth login`; or use `--diff` instead |
| File not readable | Skip, log to REVIEW.md as "skipped: permission denied" |
| All findings LOW | Optional; user may skip review |
| Auto-fix breaks tests | Revert fix; mark finding "manual fix needed" |

---

## Caveats

- Severity floor — do not flag taste-based nits.
- Auto-fix is opt-in. Default = review-only.
- REVIEW.md overwrites prior review. Archive manually if you need history.
- Never auto-fix Critical findings without explicit user OK (high risk of misunderstanding).
