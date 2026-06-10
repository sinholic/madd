# Phase 5 — Green & Refactor

## 5a. Confirm all green

```bash
<TEST_CMD>
```

All tests pass. If any fail → loop back to Phase 4 (`phase-4-impl.md`).

## 5b. Refactor (only if needed)

Look for:
- Logic repeated 3+ times → extract helper
- Dead code from red phase → delete
- Naming inconsistencies → align with project conventions

Skip if nothing qualifies. Do not refactor for taste alone.

## 5c. Type check + lint

`Bash` (parallel):
```bash
<TYPECHECK_CMD>
```
```bash
<LINT_CMD>
```

Fix errors. Re-run until clean.

## 5d. Commit if changed

```bash
git diff --quiet || git commit -am "refactor: <feature> — clean up after green"
```

**[state]** After 5a green confirmed: capture `last_test_exit = 0` and update `phase = "5"`. This is the canonical "tests passed" timestamp the push hook reads.

Return → load `phase-6-ci.md`.
