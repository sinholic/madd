---
description: "Drive end-to-end feature delivery: Spec → Schema → Tests Red → Impl → Green → Refactor → CI → UAT → Production. SDD+TDD in 8 phases. Persists .madd-ship-state.json for resume + hook enforcement. Recalls prior learnings before spec. Work-type routing: FE→/madd-design, DevOps→/madd-devops, Robot→/madd-robot, Data→/madd-data."
argument-hint: "<feature description> [--member <name>] [--base <branch>] [--no-new-branch] [--resume] [--fresh]"
version: "3.1.0"
changelog: |
  3.1.0 — Persistent state (.madd-ship-state.json) + resume protocol (Step 0j); file-tree work-type detection augments Step 0i keyword pass; Phase 1a auto-invokes /madd-recall to surface prior learnings; phase-boundary state writes power madd-phase-guard.sh hook
  3.0.0 — Work-type routing (Step 0i): auto-detect FE/BE/DevOps/Robot/Data; redirect Robot+Data to specialist skills; Phase 7d domain-specific UAT validation
  2.2.0 — Branch hygiene: pull latest base + create feature branch (Step 0h); platform-aware PR/MR (GitHub gh, GitLab glab); merge targets $BASE; --base + --no-new-branch flags
  2.1.0 — Monorepo + workspace support
  2.0.0 — Operational runbook rewrite
  1.2.0 — Added madd-learn integration
  1.1.0 — Aspirational auto-validation
  1.0.0 — Initial 8-phase workflow
---

# Runbook: Ship a feature end-to-end

You are executing `/madd-ship`. Feature description: **$ARGUMENTS**

Follow steps in order. Use named tools. Do not advance until current phase passes its gate.

---

## Step 0 — Pre-flight: read AGENTS.md (workspace-aware)

### 0a. Parse args & locate repo root

Parse `$ARGUMENTS` for `--member <name>` flag. Capture as `MEMBER` (may be empty). Remove flag from feature description.

`Bash`:
```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
```

If outside git repo → abort: "Run inside a project."

### 0b. Workspace parent guard

`Bash`:
```bash
test -f WORKSPACE.md && echo "WORKSPACE_PARENT" || echo "NOT_WORKSPACE_PARENT"
test -f AGENTS.md && echo "HAS_AGENTS" || echo "NO_AGENTS"
```

If `WORKSPACE_PARENT` and `NO_AGENTS` → abort:
> Currently at workspace parent (multi-repo). `/madd-ship` operates per-repo.
> cd into a child repo first:
> `<list child repos from find . -mindepth 2 -maxdepth 2 -name .git -type d>`

### 0c. Scope resolution (monorepo)

If `MEMBER` set:
- Try `cd packages/$MEMBER`, then `cd apps/$MEMBER`, then `find . -maxdepth 3 -type d -name "$MEMBER" | head -1`
- If found → cd in
- If not → abort with list of detected members

If `MEMBER` empty AND CWD has `AGENTS.md` AND a parent dir up to 3 levels also has `AGENTS.md` → **monorepo member detected**. Load both.

If `MEMBER` empty AND only parent has `AGENTS.md` (CWD doesn't) → **at monorepo root or wrong dir**. `AskUserQuestion`:
- "Run at root scope (whole monorepo)"
- "Pick member: <list from find . -maxdepth 3 -name AGENTS.md | grep -v ^./AGENTS.md>"
- "Abort"

### 0d. Read AGENTS.md(s)

`Read`: `<scope>/AGENTS.md`. If monorepo member detected, also `Read` root `AGENTS.md`.

If primary AGENTS.md missing → stop:
> AGENTS.md not found. Run `/madd-init` first, then re-run `/madd-ship`.

### 0e. Extract & merge key facts (inheritance)

Parse AGENTS.md sections into working memory:
- `PACKAGE_MANAGER`, `TEST_CMD`, `BUILD_CMD`, `DEV_CMD`, `DEPLOY_CMD`, `TYPECHECK_CMD`, `LINT_CMD`
- `FF_POLICY`, `COMMENT_STYLE`, `ERROR_POLICY`
- `FRAMEWORK`, `LANGUAGE`, `TEST_RUNNER`

**If monorepo member with inheritance:**
- Member AGENTS.md starts with `## Inherits from` line
- Load root AGENTS.md fields first
- Overlay member fields on top (member wins for any field it defines)
- Skip silently if member has no overrides for a field (use root value)

If any required field still missing after merge → ask user to fill or run `/madd-init` to regenerate.

### 0f. Detect package manager (override AGENTS.md if drift)

`Bash`:
```bash
test -f package.json && jq -r '.packageManager // empty' package.json 2>/dev/null
for f in pnpm-lock.yaml yarn.lock bun.lockb package-lock.json; do test -f $f && echo $f; done
```

If detected PM ≠ AGENTS.md `PACKAGE_MANAGER` → warn user, ask which to trust (default: lockfile wins).

### 0g. Determine work size

`AskUserQuestion`:
- question: "What size is this change?"
- header: "Change scope"
- options:
  - "Standard" — Full 8 phases (default for features)
  - "Quickfix" — Skip Phase 1 spec + Phase 2 schema (typos, deps, doc fixes)
  - "Hotfix" — Skip 1,2,7; deploy after Phase 6 (production bug)

Store as `SHIP_MODE`. If Quickfix or Hotfix: branch behavior at relevant phases below.

### 0h. Branch hygiene — pull base, create feature branch

Parse `$ARGUMENTS` for `--base <branch>` flag. Parse `--no-new-branch` flag (skip this step if user already on feature branch).

If `--no-new-branch` → skip to Phase 1.

**Detect base branch** (priority order):
1. `--base <branch>` arg if provided
2. AGENTS.md `BASE_BRANCH` field if present
3. `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'` (remote default)
4. `main` if exists
5. `master` if exists
6. Ask user via `AskUserQuestion`

`Bash`:
```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
git show-ref --verify --quiet refs/heads/main && echo "main exists"
git show-ref --verify --quiet refs/heads/master && echo "master exists"
```

Store as `BASE`.

**Check working tree clean:**
```bash
git status --porcelain
```

If dirty → `AskUserQuestion`:
- "Stash changes" — `git stash push -m "madd-ship pre-flight"`
- "Commit first" — abort, user commits manually
- "Cancel ship"

**Pull latest base:**
```bash
git fetch origin "$BASE"
git checkout "$BASE"
git pull --ff-only origin "$BASE"
```

If pull fails (diverged) → abort, ask user to resolve.

**Derive feature branch name** from feature description (`$ARGUMENTS` minus flags):
- Slugify: lowercase, spaces → `-`, strip non-`[a-z0-9-]`
- Prefix per AGENTS.md commit convention (default `feat/`)
- Truncate to 50 chars
- Example: "add user profile page" → `feat/add-user-profile-page`

`AskUserQuestion`:
- "Use branch name `<derived>`?"
- options:
  - "Yes — create branch"
  - "Edit name" — ask for custom
  - "Use existing branch" — list local branches; user picks

**Create feature branch:**
```bash
git checkout -b "$FEATURE_BRANCH"
```

Store `BASE` + `FEATURE_BRANCH` for Phase 6 (PR target).

If user picked "Use existing branch": verify it's not `$BASE` itself.

### 0i. Detect work type

Parse feature description (from `$ARGUMENTS` minus flags) for domain keywords:

| WORK_TYPE | Detection keywords |
|-----------|--------------------|
| `FE` | component, page, UI, frontend, design, view, layout, style, CSS, Next.js, React, Vue, Svelte, screen, modal, form, button |
| `BE` | API, endpoint, controller, service, NestJS, backend, REST, GraphQL, handler, middleware |
| `DEVOPS` | Dockerfile, docker-compose, CI, pipeline, deploy, infra, k8s, kubernetes, nginx, proxy, workflow, GitHub Actions, GitLab CI |
| `ROBOT` | MQL5, MQL4, EA, Expert Advisor, Arduino, ESP32, firmware, embedded, hardware, mechatronics, flash, microcontroller |
| `DATA` | migration, seed, ETL, backfill, database schema, Sequelize, data job, data pipeline, ALTER TABLE, DROP COLUMN |
| `FULLSTACK` | FE + BE keywords both present in same description |

Assign `WORK_TYPE`. Default: `BE` if no strong signal.

**If ROBOT keywords detected** → stop and inform:
> Hardware/firmware work detected. `/madd-ship` uses TDD + CI which doesn't apply to hardware.
> `/madd-robot` has the correct flow: spec → static analysis → compile → simulate → flash → validate.

`AskUserQuestion`:
- question: "Use /madd-robot instead?"
- header: "Work type"
- options:
  - "Yes — abort, I'll use /madd-robot"
  - "No — continue with madd-ship (expert mode)"

**If DATA keywords detected** → stop and inform:
> Data migration/pipeline work detected. `/madd-ship`'s TDD flow doesn't fit.
> `/madd-data` has the correct flow: spec → schema analysis → write down+up → idempotency → dry-run → run → validate.

`AskUserQuestion`:
- question: "Use /madd-data instead?"
- header: "Work type"
- options:
  - "Yes — abort, I'll use /madd-data"
  - "No — continue with madd-ship (expert mode)"

**If ambiguous** (keywords match 2+ unrelated types, not FULLSTACK) → `AskUserQuestion`:
- question: "Work type ambiguous. What best describes this change?"
- header: "Work type"
- options:
  - "FE / frontend only"
  - "BE / backend API only"
  - "DevOps / infra"
  - "Full-stack (FE + BE)"

Store keyword pass as `WORK_TYPE_KEYWORD`.

### 0i.5. File-tree work-type signal (lockfile-style precedence)

Keyword-only routing misclassifies a feature whose description doesn't match the actual surface (e.g. "fix prod build" that touches only Dockerfile). Cross-check with the file tree if the branch already has commits.

`Bash`:
```bash
git diff --name-only "$BASE"...HEAD 2>/dev/null | head -50
```

If output empty (first ship for this branch) → skip this sub-step; rely on keyword `WORK_TYPE_KEYWORD`. Re-run this signal at Phase 2 commit (state file tracks `tree_signal_resolved` boolean).

If output non-empty, classify each path:

| Path pattern | Signal |
|--------------|--------|
| `Dockerfile`, `docker-compose*`, `.github/workflows/**`, `wrangler.*`, `vercel.json`, `fly.toml`, `render.yaml`, `app.yaml`, `serverless.yml`, `terraform/**`, `helm/**`, `k8s/**` | DEVOPS |
| `**/*.tsx`, `**/*.jsx`, `**/*.vue`, `**/*.svelte`, `**/*.astro`, `app/**`, `src/components/**`, `src/pages/**`, `src/views/**`, `styles/**`, `*.css`, `*.scss` | FE |
| `prisma/migrations/**`, `**/*.sql`, `migrations/**`, `seeds/**`, `db/**`, `**/*-migration.{js,ts,py}` | DATA |
| `**/*.mq4`, `**/*.mq5`, `**/*.ino`, `firmware/**`, `arduino/**` | ROBOT |
| `**/api/**`, `**/handlers/**`, `**/controllers/**`, `**/services/**`, `**/*.py` (non-test), `**/*.go`, `**/*.rs`, `**/*.java`, `routes/**` | BE |

Tally per category. The category with strictly the most matches → `WORK_TYPE_TREE`. Tie → leave unset.

### 0i.6. Precedence merge

| WORK_TYPE_KEYWORD | WORK_TYPE_TREE | → WORK_TYPE | Action |
|-------------------|----------------|-------------|--------|
| set | unset | KEYWORD | use keyword |
| unset | set | TREE | use tree |
| set | set, same | KEYWORD | use either |
| set | set, FE/BE mix (any pair) | FULLSTACK | promote |
| set | set, different (other) | TREE | tree wins; `AskUserQuestion` to confirm: keyword said X, file tree says Y, which? (tree default) |
| unset | unset | BE | default fallback |

Store final value as `WORK_TYPE`.

The ROBOT / DATA prompts above (in 0i) still fire if EITHER pass detects those — protect against expert mode auto-routing into a TDD flow that doesn't fit.

---

## Step 0j — Resume protocol (state file)

MADD persists ship state to `.madd-ship-state.json` at the repo root so an interrupted ship can resume cleanly and the `madd-phase-guard.sh` hook can enforce gates.

### 0j.a. Detect existing state

`Bash`:
```bash
test -f .madd-ship-state.json && cat .madd-ship-state.json || echo MISSING
```

If MISSING → no resume; jump to 0j.c (initialize fresh state) and continue to Phase 1.

If present, parse:
- `state.feature` → existing feature name
- `state.branch` → branch the ship was running on
- `state.phase` → last completed phase
- `state.phase_started` → ISO timestamp

### 0j.b. Branch / argument reconciliation

| state.feature | $ARGUMENTS feature | state.branch | current branch | Action |
|---------------|--------------------|--------------|----------------|--------|
| matches | matches | matches current | matches | **Resume offer** |
| matches | matches | matches | different | Ask: `git checkout $state.branch` then resume? |
| different | different | matches current | current branch | Ask: continue old or checkpoint + start new? |
| matches | empty (`/madd-ship` no args) | matches current | matches | **Resume offer** (no args treated as resume request) |

`AskUserQuestion` (only if `--resume` not passed and `--fresh` not passed):
- question: "Existing ship state for `<state.feature>` at phase <state.phase>. Resume or start fresh?"
- header: "Ship state"
- options:
  - "Resume from phase <N>" — load state into working memory; skip to that phase
  - "Show state, then decide" — Read state file in full; loop back
  - "Checkpoint + start fresh" — invoke `/madd-checkpoint --note "auto-pre-fresh"` then continue to 0j.c
  - "Start fresh (discard state)" — wipe `.madd-ship-state.json`; warn loudly; continue

If `--resume` passed → skip the question, auto-resume.
If `--fresh` passed → skip the question, auto-discard (still print a warning).

### 0j.c. Initialize / refresh state

Write `.madd-ship-state.json` via `Write` (overwrite is OK after the discard branch above):

```json
{
  "feature": "<derived from $ARGUMENTS>",
  "feature_description": "<full $ARGUMENTS minus flags>",
  "branch": "<FEATURE_BRANCH from Step 0h>",
  "base": "<BASE from Step 0h>",
  "ship_mode": "<SHIP_MODE from Step 0g>",
  "work_type": "<WORK_TYPE from Step 0i.6>",
  "member": "<MEMBER or null>",
  "phase": "0",
  "phase_started": "<ISO from `date -u +%Y-%m-%dT%H:%M:%SZ`>",
  "tests_red_confirmed": false,
  "last_test_exit": null,
  "tree_signal_resolved": false,
  "spec": null,
  "conventions": null,
  "_meta": {
    "madd_version": "3.1.0",
    "created_at": "<ISO>"
  }
}
```

Add the gitignore entry if missing (madd-init does this on initial scaffold, but a manually-cloned repo may lack it):

`Bash`:
```bash
grep -q '\.madd-ship-state\.json' .gitignore 2>/dev/null || echo '.madd-ship-state.json' >> .gitignore
grep -q '\.madd-ship-state\.backup-' .gitignore 2>/dev/null || echo '.madd-ship-state.backup-*.json' >> .gitignore
```

### 0j.d. Phase update helper

Throughout the remaining steps, when a phase boundary is crossed, update the state file. Helper logic — at each marked spot ("**[state]** ..." callouts below):

`Bash` (preferred; jq if available):
```bash
node -e "
const fs = require('fs');
const path = '.madd-ship-state.json';
const j = JSON.parse(fs.readFileSync(path, 'utf8'));
// updates applied here, e.g.:
j.phase = '4';
j.phase_started = new Date().toISOString();
j.tests_red_confirmed = true;
fs.writeFileSync(path, JSON.stringify(j, null, 2));
"
```

The hook `~/.claude/hooks/madd-phase-guard.sh` reads these fields. Stale or missing updates → hook misfires. Always apply at the marked spots.

---

## Phase 1 — Spec (skip if SHIP_MODE ≠ Standard)

### 1a.pre — Recall prior learnings

Before drafting, ask MADD memory whether anything relevant has been captured already.

Invoke `/madd-recall <feature-keywords> --from-ship --limit 5`. Keywords = noun phrases from the feature description (strip stop words: "add", "the", "a", "fix", "to").

Read the structured JSON envelope from `/madd-recall`'s response. If `recall.count > 0`:

`AskUserQuestion`:
- question: "Surface <recall.count> prior learning(s) for related work. Inherit constraints into this spec?"
- header: "Recall"
- options:
  - "Show me the matches first" — print the formatted digest, then re-ask
  - "Apply all as 'must consider'" — copy into spec's `Prerequisites` section
  - "Pick which to apply" — multi-select via second `AskUserQuestion`
  - "Skip — none relevant"

If `recall.count == 0` or `/madd-recall` was unavailable → print one line ("No prior learnings matched.") and continue to 1a draft.

This step is silent during Quickfix / Hotfix (`SHIP_MODE ≠ Standard`).

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

**[state]** On approval, update `.madd-ship-state.json`:
```
phase = "1"
spec = { feature, prerequisites, acceptance_criteria, named_test_list, out_of_scope, security }
conventions = SPEC_CONVENTIONS
phase_started = now
```

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

**[state]** After commit: `phase = "2"`, `phase_started = now`. Re-run Step 0i.5 file-tree signal now that diff exists; set `tree_signal_resolved = true`.

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

**[state]** After RED gate confirmed in 3c AND commit lands: `phase = "3"`, `tests_red_confirmed = true`, `phase_started = now`. This unblocks `feat:` commits per `madd-phase-guard.sh`.

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

**[state]** After commit: `phase = "4"`, `phase_started = now`.

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

**[state]** After 5a green confirmed: capture `last_test_exit = 0` and update `phase = "5"`. (This is the canonical "tests passed" timestamp the push hook reads.)

---

## Phase 6 — CI / Build gate

### 6a. Full check suite

`Bash`:
```bash
<TEST_CMD> && <BUILD_CMD>
```

Both must pass. Do not bypass hooks. Do not skip type errors.

**[state]** Capture exit code of `<TEST_CMD>` (independently of `&&` chain so failure mode is recorded): re-run `<TEST_CMD>; echo "exit=$?"` if needed, then update `last_test_exit = <code>`. If `<BUILD_CMD>` also failed, set `last_build_exit = <code>`. Hook reads `last_test_exit` before allowing `git push`.

### 6b. Push feature branch

`Bash`:
```bash
git push -u origin "$FEATURE_BRANCH"
```

If the push is blocked by `madd-phase-guard.sh`, inspect the structured hook reason. If it cites a stale `last_test_exit`, the recovery is to re-run `<TEST_CMD>` and update state — never bypass the hook with `--no-verify`.

**[state]** After successful push: `phase = "6"`, `phase_started = now`, `pr_url = <captured from 6d>` (after 6d runs).

### 6c. Detect platform

`Bash`:
```bash
git remote get-url origin
```

Classify by remote URL:
- contains `github.com` → `GITHUB`
- contains `gitlab.` (including self-hosted like `gitlab.sprout.co.id`) → `GITLAB`
- contains `bitbucket.org` → `BITBUCKET`
- other → ask user via `AskUserQuestion`

Store as `PLATFORM`.

### 6d. Open draft PR / MR — targets `$BASE`

**GITHUB** (`gh pr create`):
```bash
gh pr create --draft \
  --base "$BASE" \
  --head "$FEATURE_BRANCH" \
  --title "feat: <feature one-liner>" \
  --body "$(cat <<'EOF'
## Summary
<spec one-liner>

## Acceptance criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

## Test plan
- [ ] All N named tests green
- [ ] Staging UAT pass (Phase 7)

🤖 Generated with [Claude Code](https://claude.com/claude-code) via /madd-ship
EOF
)"
```

**GITLAB** (`glab mr create`):
```bash
glab mr create \
  --draft \
  --target-branch "$BASE" \
  --source-branch "$FEATURE_BRANCH" \
  --title "feat: <feature one-liner>" \
  --description "$(cat <<'EOF'
## Summary
<spec one-liner>

## Acceptance criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

## Test plan
- [ ] All N named tests green
- [ ] Staging UAT pass (Phase 7)
EOF
)"
```

If `glab` not installed → fall back to printing the MR URL pattern + manual instruction:
```
Open MR manually:
  https://<gitlab-host>/<group>/<project>/-/merge_requests/new?merge_request[source_branch]=$FEATURE_BRANCH&merge_request[target_branch]=$BASE
```

**BITBUCKET**: Print URL pattern + instruction (no first-class CLI assumed).

Capture returned PR/MR URL. Print to user.

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

**[state]** After "All pass": `phase = "7"`, `phase_started = now`, `uat_passed = true`.

### 7d. Domain-specific validation (WORK_TYPE routing)

**If `WORK_TYPE` = `FE` or `FULLSTACK`:**

`AskUserQuestion`:
- question: "Run design validation against mockups/Figma?"
- header: "Design check"
- options:
  - "Yes — run /madd-design (will check Figma/Jira reference)"
  - "No — skip design check"

If yes: read and follow `/madd-design` runbook. Pass `--diff` to scope to current branch changes.

**If `WORK_TYPE` = `DEVOPS`:**

`AskUserQuestion`:
- question: "Run DevOps config review?"
- header: "Infra check"
- options:
  - "Yes — run /madd-devops (Dockerfile, CI, worker, deploy review)"
  - "No — skip infra check"

If yes: read and follow `/madd-devops` runbook. Pass `--diff` to scope to current changes.

**If `WORK_TYPE` = `BE` or default:**

Standard UAT from Step 7c is sufficient. Skip this step.

---

## Phase 8 — Production

### 8a. Promote PR/MR + merge to base

Platform-dispatch based on `PLATFORM` from Phase 6:

**GITHUB:**
```bash
gh pr ready  # promotes current branch's PR from draft
# Wait for CI / reviewer if required by repo settings
gh pr merge --squash  # or per AGENTS.md merge policy: --merge / --rebase / --squash
```

**GITLAB:**
```bash
glab mr update --ready  # un-draft
# Wait for pipeline / approval per project settings
glab mr merge --squash  # or per AGENTS.md merge policy
```

**BITBUCKET / other:** instruct user to merge via web UI; wait for confirmation before continuing.

After merge, sync local base:
```bash
git checkout "$BASE"
git pull --ff-only origin "$BASE"
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

Do not auto-run — let user decide whether to capture. The `madd-post-learn` skill will also fire passively when the merge is detected and offer the same.

**[state]** After 8b live verify passes: `phase = "8"`, `phase_started = now`, `deployed_at = <ISO>`, `live_url = <if available>`.

### 8e. Cycle cleanup

After successful production verify (and after `/madd-learn` is offered), offer cleanup:

`AskUserQuestion`:
- question: "Ship complete. Clean up `.madd-ship-state.json` and checkpoints?"
- header: "Cleanup"
- options:
  - "Yes — archive state to `.madd-ship-archive/`" (Recommended; preserves audit trail without leaving live state around to confuse the next ship)
  - "Yes — delete outright"
  - "No — keep state file as is"

On archive:
```bash
mkdir -p .madd-ship-archive
mv .madd-ship-state.json ".madd-ship-archive/<feature>-<ISO>.json"
```

On delete:
```bash
rm -f .madd-ship-state.json
```

In both cases, leave `.madd-ship-state.backup-*.json` files for the user to sweep manually.

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
- `.madd-ship-state.json` is a real load-bearing artifact, not documentation. `madd-phase-guard.sh` reads `tests_red_confirmed` and `last_test_exit` from it to gate `feat:` commits and `git push`. Stale state → hook misfires. The "**[state]**" callouts after each phase are not optional reminders; the runbook depends on the writes landing.
- `.madd-ship-state.json` is local-only (gitignored). Do not commit it.
- Resume protocol (Step 0j) trusts the state file. If a teammate hands you a branch with no state, run `--fresh` — don't reconstruct state by hand.
