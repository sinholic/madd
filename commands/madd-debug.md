---
description: "Systematic debugging session. Reproduces bug, isolates, fixes, validates. Real tool calls, persistent state in DEBUG.md."
argument-hint: "<bug description>"
version: "1.0.0"
changelog: |
  1.0.0 — Initial runbook: scientific method, persistent state, real tool calls
---

# Runbook: Systematic debug session

You are executing `/madd-debug`. Bug: **$ARGUMENTS**

Goal: reproduce → isolate → fix → validate. Track state in `.madd-debug.md` so session survives context resets.

---

## Step 0 — Pre-flight

`Bash`:
```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
git status --short
git rev-parse --short HEAD
```

`Read`: `AGENTS.md` — extract `TEST_CMD`, `BUILD_CMD`, `DEV_CMD`, `LANGUAGE`, `FRAMEWORK`.

If AGENTS.md missing → still proceed, but skip auto-detected commands.

---

## Step 1 — Check for active debug session

`Bash`:
```bash
test -f .madd-debug.md && cat .madd-debug.md | head -30
```

If exists: `AskUserQuestion`:
- "Resume existing debug session?"
- Options:
  - "Resume" — read state, continue from last step
  - "Archive + start fresh" — move to `.madd-debug.<timestamp>.md`, new session
  - "Discard + start fresh" — delete, new session

If no session, create scaffold via `Write` to `.madd-debug.md`:

```markdown
# Debug session — <ISO date>

## Bug
<$ARGUMENTS>

## Reproduction
- [ ] Reproduced reliably
- Steps:
  -

## Hypotheses
1.

## Tested
-

## Root cause


## Fix


## Validation
- [ ] Bug no longer reproduces
- [ ] No regressions in adjacent features
- [ ] Test added covering this bug
```

---

## Step 2 — Reproduce

### 2a. Gather reproduction info

`AskUserQuestion` (batch up to 4):

1. "How to trigger bug?"
   - free text via "Other"
2. "Expected behavior?"
   - free text
3. "Actual behavior?"
   - free text
4. "First seen when?"
   - Options: "Just now" / "After recent change" / "Always existed" / "Unknown"

### 2b. Run reproduction

Based on info, try to trigger bug:
- For UI bugs: `<DEV_CMD>` background, then open browser/use Playwright MCP if available
- For logic bugs: write minimal repro script, run via `<TEST_CMD>` or direct invocation
- For build bugs: run `<BUILD_CMD>` and capture output
- For test failures: run failing test in isolation

Capture actual output via `Bash`.

### 2c. Update state

`Edit` `.madd-debug.md`:
- Mark "Reproduced reliably" checkbox if successful
- Fill Steps section with confirmed reproduction commands

If can't reproduce → stop. Tell user: "Cannot reproduce. Need more info or different environment." Do not guess fixes for unreproducible bugs.

---

## Step 3 — Isolate

### 3a. Bisect git history (if "After recent change")

`Bash`:
```bash
git log --oneline -20
```

`AskUserQuestion`:
- "Bisect to find breaking commit?"
- Options:
  - "Yes — `git bisect`" — manual bisect
  - "No — already know suspect"
  - "Skip — not regression"

If bisect: guide through `git bisect start` → mark good/bad → run repro at each step.

### 3b. Form hypotheses

Based on reproduction + recent code: write 3+ specific hypotheses about root cause.

Format each as falsifiable claim:
- "Bug caused by X because Y. Falsifiable by Z test."

`Edit` `.madd-debug.md` → fill Hypotheses section.

### 3c. Test hypotheses one at a time

For each hypothesis:
1. Design minimal test (log statement, isolated function call, modified input)
2. Execute via `Bash` / `Read` / instrumented run
3. Record result in `.madd-debug.md` Tested section
4. If hypothesis confirmed → proceed to Step 4
5. If rejected → next hypothesis

**Rule:** never skip to fix without confirmed root cause. Guessing wastes time.

---

## Step 4 — Fix

### 4a. Document root cause

`Edit` `.madd-debug.md` → fill Root cause section. One sentence: "X happens because Y."

### 4b. Apply fix

Use `Edit` to change the actual source. Minimal change — fix the root cause, not symptoms.

Rules:
- No "defensive" guards around unrelated code
- No reformatting / drive-by cleanup
- Comment only if WHY is non-obvious (per AGENTS.md comment policy)

### 4c. Add regression test

Write test that would have caught this bug. Use AGENTS.md `TEST_RUNNER` syntax.

Verify test FAILS without fix, PASSES with fix:
```bash
git stash
<TEST_CMD> -- <new-test>   # Should FAIL
git stash pop
<TEST_CMD> -- <new-test>   # Should PASS
```

---

## Step 5 — Validate

### 5a. Confirm bug gone

Re-run Step 2 reproduction. Bug must not reproduce.

### 5b. Full test suite

`Bash`:
```bash
<TEST_CMD>
```

All tests pass. If any regressed → loop back to Step 4.

### 5c. Update state

`Edit` `.madd-debug.md`:
- Tick "Bug no longer reproduces"
- Tick "No regressions"
- Tick "Test added"
- Fill Fix section with summary

---

## Step 6 — Commit + cleanup

### 6a. Commit

`Bash`:
```bash
git add <fix-files> <test-files>
git commit -m "fix: <one-line bug summary>

Root cause: <one-line cause>
Test: <test name>"
```

### 6b. Archive debug session

`Bash`:
```bash
mkdir -p .madd-debug-archive
mv .madd-debug.md .madd-debug-archive/$(date -u +%Y%m%d-%H%M%S)-<bug-slug>.md
```

### 6c. Suggest capture

> Bug fixed + tested. Capture as learning?
>   `/madd-learn <bug-name> --tags bug,debugging --confidence 5`

---

## When to escalate

Stop the runbook and ask user if:
- 3+ hypotheses tested, none confirmed (need fresh eyes or different domain knowledge)
- Bug only reproduces in production (need staging/prod access or logs)
- Fix would require architectural change (escalate to `/madd-ship` proper)
- Bug touches security boundary (escalate to `/madd-secure`)

---

## Failure modes

| Symptom | Recovery |
|---------|----------|
| Can't reproduce | Ask for more info; never fix unreproducible bugs |
| Bisect fails (multiple causes) | Document, manually inspect each suspect commit |
| All hypotheses rejected | Add instrumentation (logs/traces); ask user for prod observations |
| Fix breaks other tests | Wrong root cause OR fix has wider impact than expected — re-investigate |
| `.madd-debug.md` corrupted | Delete; start fresh; lose state |

---

## Caveats

- Persistent state in `.madd-debug.md` — survives context resets. Resume anytime.
- Hypotheses must be falsifiable. "Probably a race condition" doesn't qualify.
- Never commit a fix without a regression test (unless explicit AGENTS.md exemption).
- Never `git stash drop` debug-related changes without user OK.
