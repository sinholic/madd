# Phase 3 — Tests (Red)

## 3a. Pre-stub for typed langs

If `LANGUAGE` ∈ {TS, Go, Rust, Java, etc.}: write empty stub functions so tests can import.

```typescript
export function calculateTotal(items: Item[]): number {
  throw new Error("Not implemented");
}
```

Commit: `stub: <feature> — placeholders for red phase`

## 3b. Write tests

For each entry in Phase 1 named test list: create test file via `Write` / `Edit`.

Rules:
- AGENTS.md `TEST_RUNNER` syntax
- Test logic in isolation
- Mock external boundaries only

## 3c. Confirm RED

```bash
<TEST_CMD>
```

Verify: all new tests fail with **assertion errors** (not import/syntax errors). If wrong reason → fix stub/import → re-run.

`AskUserQuestion`:
- question: "All N tests RED for right reason?"
- header: "Red gate"
- options: "Yes — proceed to Phase 4" / "No — fix red phase"

## 3d. Commit

```bash
git add <test-files>
git commit -m "test(red): <feature> — all N tests failing"
```

**[state]** After RED gate confirmed AND commit lands: `phase = "3"`, `tests_red_confirmed = true`, `phase_started = now`. This unblocks `feat:` commits per `madd-phase-guard.sh`.

Return → load `phase-4-impl.md`.
