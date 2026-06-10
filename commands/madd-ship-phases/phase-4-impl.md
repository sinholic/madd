# Phase 4 — Implementation

## 4a. Implement in dependency order

Walk the test list. For each test, implement minimum code to make it green. Order:
1. Data / persistence layer
2. Service / business logic
3. API / handler layer
4. UI layer (if applicable)

Follow Phase 1 `SPEC_CONVENTIONS`. Do not deviate without flagging.

After each test goes green, run `<TEST_CMD>` to confirm no regressions.

## 4b. WORKLOG.md auto-append

```bash
test -f WORKLOG.md && echo EXISTS
```

If missing, `Write` to `<repo-root>/WORKLOG.md`:
```markdown
# WORKLOG.md

Decision log for non-obvious choices. Append-only.
```

`Edit` WORKLOG.md — append:
```markdown

## <feature-name> — <ISO-date>
- <non-obvious decision and why>
- <gotcha encountered and fix>
- <constraint discovered>
```

Fill bullets from actual implementation experience. If nothing non-obvious:
```markdown

## <feature-name> — <ISO-date>
- No non-obvious decisions; straightforward impl per spec
```

## 4c. Commit

```bash
git add <impl-files> WORKLOG.md
git commit -m "feat: <feature>"
```

**[state]** After commit: `phase = "4"`, `phase_started = now`.

Return → load `phase-5-green.md`.
