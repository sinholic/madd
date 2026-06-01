---
description: "Drive end-to-end feature delivery: Spec → Schema → Tests Red → Impl → Green → Refactor → CI → UAT → Production. SDD+TDD in 8 phases. Real tool invocations, not docs."
argument-hint: "<feature description>"
version: "2.0.0"
changelog: |
  2.0.0 — Rewrite as operational runbook: real AskUserQuestion gating, real WORKLOG.md Edit, real PM detection, real auto-populated handoff
  1.2.0 — Added madd-learn integration
  1.1.0 — Aspirational auto-validation
  1.0.0 — Initial 8-phase workflow
---

# Runbook: Ship a feature end-to-end

You are executing `/madd-ship`. Feature description: **$ARGUMENTS**

Follow steps in order. Use named tools. Do not advance until current phase passes its gate.

---

## Step 0 — Pre-flight: read AGENTS.md

### 0a. Locate repo root

`Bash`:
```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
```

### 0b. Read AGENTS.md

`Read`: `<repo-root>/AGENTS.md`

If file missing → stop. Report to user:
> AGENTS.md not found. Run `/madd-init` first, then re-run `/madd-ship`.

### 0c. Extract key facts

Parse AGENTS.md sections. Store in working memory:
- `PACKAGE_MANAGER` (from Stack table)
- `TEST_CMD`, `BUILD_CMD`, `DEV_CMD`, `DEPLOY_CMD`, `TYPECHECK_CMD`, `LINT_CMD` (from Key commands)
- `FF_POLICY`, `COMMENT_STYLE`, `ERROR_POLICY` (from Conventions)
- `FRAMEWORK`, `LANGUAGE`, `TEST_RUNNER`

If any field missing → ask user to fill or run `/madd-init` to regenerate.

### 0d. Detect package manager (override AGENTS.md if drift)

`Bash`:
```bash
test -f package.json && jq -r '.packageManager // empty' package.json 2>/dev/null
for f in pnpm-lock.yaml yarn.lock bun.lockb package-lock.json; do test -f $f && echo $f; done
```

If detected PM ≠ AGENTS.md `PACKAGE_MANAGER` → warn user, ask which to trust (default: lockfile wins).

### 0e. Determine work size

`AskUserQuestion`:
- question: "What size is this change?"
- header: "Change scope"
- options:
  - "Standard" — Full 8 phases (default for features)
  - "Quickfix" — Skip Phase 1 spec + Phase 2 schema (typos, deps, doc fixes)
  - "Hotfix" — Skip 1,2,7; deploy after Phase 6 (production bug)

Store as `SHIP_MODE`. If Quickfix or Hotfix: branch behavior at relevant phases below.

---

## Phase 1 — Spec (skip if SHIP_MODE ≠ Standard)

### 1a. Draft spec

Write spec block in conversation:

```
**Feature:** <one sentence>
**Prerequisites:** <list>
**Acceptance criteria:**
  1. <observable outcome>
  2. ...
**Named test list:**
  - test("<exact name>")
  - ...
**Out of scope:** <non-goals>
**Security & compliance:** <auth, validation, secrets, data exposure>
```

Show user. Iterate until accepted.

### 1b. Confirm conventions (real gating)

`AskUserQuestion` (one call, 4 questions):

1. question: "Feature flags for this change?"
   - header: "Flags"
   - options: AGENTS.md default (`{FF_POLICY}`) + explicit alternates

2. question: "Comment policy for this change?"
   - header: "Comments"
   - options: AGENTS.md default (`{COMMENT_STYLE}`) + alternates

3. question: "Error handling boundary?"
   - header: "Errors"
   - options: AGENTS.md default (`{ERROR_POLICY}`) + alternates

4. question: "Rollback plan documented?"
   - header: "Rollback"
   - options:
     - "Git revert + redeploy" — default
     - "DB rollback needed" — schema change
     - "Feature flag kill switch" — if flags enabled
     - "Other — describe"

Store as `SPEC_CONVENTIONS`.

### 1c. Final approval gate

`AskUserQuestion`:
- question: "Spec approved? Phase 2 begins after approval."
- header: "Spec gate"
- options:
  - "Approved — proceed to Phase 2"
  - "Revise spec"
  - "Abort ship"

Only on "Approved" → continue. On "Revise" → loop back to 1a. On "Abort" → stop cleanly.

---

## Phase 2 — Schema (skip if SHIP_MODE = Quickfix)

### 2a. Identify schema surface

For each external input boundary in the spec, identify the type/schema target:
- Function signatures (interfaces, types)
- API request/response shapes
- DB models / migrations
- Form / URL param validators

### 2b. Write schemas

Use `Write` / `Edit` to create type files. No runtime logic yet — just types.

Choose validator based on AGENTS.md `LANGUAGE`:
- TypeScript → Zod (or existing lib in deps)
- Python → Pydantic
- Go → struct tags + go-validator
- Rust → serde + validator

### 2c. Commit

`Bash`:
```bash
git add <schema-files>
git commit -m "schema: add types for <feature>"
```

---

## Phase 3 — Tests (Red)

### 3a. Pre-stub for typed langs

If `LANGUAGE` is statically typed (TS, Go, Rust, Java, etc.): write **empty stub functions** first so tests can import without compile error.

```typescript
// Example stub
export function calculateTotal(items: Item[]): number {
  throw new Error("Not implemented");
}
```

Commit: `stub: <feature> — placeholders for red phase`

### 3b. Write tests from named list

For each test in Phase 1 named test list: create test file via `Write` / `Edit`.

Rules:
- Use AGENTS.md `TEST_RUNNER` syntax
- Test logic in isolation
- Mock external boundaries only

### 3c. Run tests, confirm RED

`Bash`:
```bash
<TEST_CMD>
```

Verify output: all new tests fail with **assertion errors** (not import errors, not syntax errors). If any test fails for wrong reason → fix stub/import → re-run.

`AskUserQuestion`:
- question: "All N tests RED for right reason?"
- header: "Red gate"
- options:
  - "Yes — proceed to Phase 4"
  - "No — fix red phase"

### 3d. Commit

```bash
git add <test-files>
git commit -m "test(red): <feature> — all N tests failing"
```

---

## Phase 4 — Implementation

### 4a. Implement in dependency order

Walk the test list. For each test, implement the minimum code to make it green. Order:
1. Data / persistence layer
2. Service / business logic
3. API / handler layer
4. UI layer (if applicable)

Follow Phase 1 `SPEC_CONVENTIONS` (feature flags, comments, errors). Do not deviate without flagging.

After each test goes green, run `<TEST_CMD>` to confirm no regressions.

### 4b. WORKLOG.md auto-append (real, not reminder)

Before Phase 5, capture decision log via real tool call.

`Bash`:
```bash
test -f WORKLOG.md && echo EXISTS
```

If missing, `Write` to `<repo-root>/WORKLOG.md`:
```markdown
# WORKLOG.md

Decision log for non-obvious choices. Append-only.
```

Then `Edit` WORKLOG.md — append at end:
```markdown

## <feature-name> — <ISO-date>
- <non-obvious decision and why>
- <gotcha encountered and fix>
- <constraint discovered>
```

Fill bullets from actual implementation experience this session. If nothing non-obvious happened, write:
```markdown

## <feature-name> — <ISO-date>
- No non-obvious decisions; straightforward impl per spec
```

### 4c. Commit

```bash
git add <impl-files> WORKLOG.md
git commit -m "feat: <feature>"
```

---

## Phase 5 — Green & Refactor

### 5a. Confirm all green

`Bash`:
```bash
<TEST_CMD>
```

All tests pass. If any fail → loop back to Phase 4.

### 5b. Refactor (only if needed)

Look for:
- Logic repeated 3+ times → extract helper
- Dead code from red phase → delete
- Naming inconsistencies → align with project conventions

Skip this step if nothing qualifies. Do not refactor for taste alone.

### 5c. Type check + lint

`Bash` (run in parallel):
```bash
<TYPECHECK_CMD>
<LINT_CMD>
```

Fix any errors. Re-run until clean.

### 5d. Commit if changed

```bash
git diff --quiet || git commit -am "refactor: <feature> — clean up after green"
```

---

## Phase 6 — CI / Build gate

### 6a. Full check suite

`Bash`:
```bash
<TEST_CMD> && <BUILD_CMD>
```

Both must pass. Do not bypass hooks. Do not skip type errors.

### 6b. Push + open draft PR

`Bash`:
```bash
git push -u origin HEAD
```

Then create draft PR. Detect platform:
```bash
git remote get-url origin
```

If GitHub: `gh pr create --draft --title "feat: <feature>" --body "$(cat <<'EOF'
## Summary
<spec one-liner>

## Acceptance criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

## Test plan
- [ ] All N named tests green
- [ ] Staging UAT pass (Phase 7)
EOF
)"`

---

## Phase 7 — Staging UAT (skip if SHIP_MODE = Hotfix)

### 7a. Regression check

`Bash`:
```bash
<TEST_CMD>
```

Must pass clean.

### 7b. Start preview / staging

`Bash`:
```bash
<DEV_CMD>  # or staging-specific command from AGENTS.md
```

Run in background if long-lived (use `run_in_background: true`).

### 7c. Manual verification

`AskUserQuestion`:
- question: "Verify each acceptance criterion manually. All passing?"
- header: "UAT gate"
- options:
  - "All pass — proceed to Phase 8"
  - "Some failed — abort or fix"

If failed: report which criteria, stop, suggest fixes.

---

## Phase 8 — Production

### 8a. Promote PR + deploy

`Bash` (GitHub):
```bash
gh pr ready
# Wait for CI / reviewer if required
gh pr merge --squash  # or per AGENTS.md merge policy
```

Then deploy:
```bash
<DEPLOY_CMD>
```

### 8b. Verify live

Manually check live URL matches acceptance criteria. Report status.

### 8c. Rollback path (if live verify fails)

Get last good commit:
```bash
git log --oneline -5
```

`AskUserQuestion`:
- question: "Rollback required?"
- header: "Rollback"
- options:
  - "No — live verify passed"
  - "Yes — revert + redeploy"

If yes, get commit hash from user via second `AskUserQuestion`, then verify hash exists:
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

### 8d. Capture learnings

Always prompt:

> Phase 8 complete. Capture learnings to agent memory:
>   `/madd-learn <feature-name> --confidence <1-5> --tags <tags>`
>
> Or run interactively:
>   `/madd-learn <feature-name>`

Do not auto-run — let user decide whether to capture.

---

## Agent delegation (when handing off mid-ship)

If user wants to delegate phases 2-6 to a background agent:

### Build handoff prompt (auto-populated)

`Read`: AGENTS.md + current spec from this session.

Construct prompt by substituting **real values** (no `<placeholder>` syntax):

```
Branch: <actual-branch-name from `git branch --show-current`>

Spec:
<paste full spec block from Phase 1>

Test list (contract):
<paste named test list from Phase 1>

Stack context (from AGENTS.md):
- Package manager: <PACKAGE_MANAGER>
- Test command: <TEST_CMD>
- Build command: <BUILD_CMD>
- Deploy command: <DEPLOY_CMD>
- Language: <LANGUAGE>
- Framework: <FRAMEWORK>

Conventions (Phase 1 confirmed):
- Feature flags: <SPEC_CONVENTIONS.flags>
- Comment policy: <SPEC_CONVENTIONS.comments>
- Error handling: <SPEC_CONVENTIONS.errors>
- Rollback plan: <SPEC_CONVENTIONS.rollback>

Task: Execute Phases 2-6 (Schema → Build gate). Stop and report before Phase 7 UAT.
```

Use `Agent` tool with `subagent_type: "general-purpose"` and the above as prompt.

**Never delegate Phase 1** — spec decisions stay in main conversation.

---

## Commit prefix discipline

| Phase | Prefix |
|-------|--------|
| Schema | `schema:` |
| Stubs (typed langs) | `stub:` |
| Tests red | `test(red):` |
| Implementation | `feat:` |
| Refactor | `refactor:` |
| Hotfix | `fix:` |
| Rollback | `Rollback:` |

---

## Failure modes

| Symptom | Cause | Recovery |
|---------|-------|----------|
| AGENTS.md missing | Project not initialized | Run `/madd-init` |
| AGENTS.md fields missing | Stale or incomplete | Edit manually or re-run `/madd-init existing` |
| Detected PM ≠ AGENTS.md | Drift since init | Update AGENTS.md; lockfile wins by default |
| Tests RED for wrong reason | Import / syntax error | Fix stubs/imports first |
| Phase 6 build fails | Type or lint error | Fix locally; do not bypass hooks |
| Phase 7 regression | Adjacent feature broken | Stop; fix or document trade-off; do not promote |
| Phase 8 deploy fails | Platform error | Check `<DEPLOY_CMD>` output; do not retry blindly |
| Rollback hash missing | Wrong hash entered | Re-fetch from `git log`; verify with `git cat-file -e` |

---

## Caveats

- This skill makes **real** tool calls. Do not narrate — execute.
- All phase gates use `AskUserQuestion`. Markdown checkboxes are visual; the question tool is the gate.
- `WORKLOG.md` is appended via real `Edit` tool, not reminder text.
- Agent handoff substitutes **real values** before sending — no `<placeholder>` syntax in the final prompt.
- Rollback verifies commit hash exists before reverting.
- `SHIP_MODE` branches behavior — Quickfix/Hotfix skip declared phases.
