---
description: "Drive end-to-end feature delivery: Spec → Schema → Tests Red → Impl → Green → Refactor → CI → UAT → Production. SDD+TDD in 8 phases. Persists .madd-ship-state.json for resume + hook enforcement. Recalls prior learnings before spec. Work-type routing: FE→/madd-design, DevOps→/madd-devops, Robot→/madd-robot, Data→/madd-data."
argument-hint: "<feature description> [--member <name>] [--base <branch>] [--no-new-branch] [--resume] [--fresh]"
version: "3.2.1"
changelog: |
  3.2.1 — Resume off-by-one fix: state.phase = last COMPLETED phase, RESUME_FROM = phase+1; resume respects SHIP_MODE skip rules; RESUME_FROM > 8 routes to cleanup
  3.2.0 — Phase bodies split into commands/madd-ship-phases/phase-{1-8}-*.md; orchestrator loads each phase file only when entering that phase. Cuts initial runbook load ~70%
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

This file is the **orchestrator**. Pre-flight (Step 0) is mandatory and inline. Phases 1-8 live in `commands/madd-ship-phases/phase-N-*.md` — load each via `Read` only when entering that phase. Orchestrator is ~390 lines (Step 0 + phase dispatch + agent delegation + commit prefix table + failure modes + caveats), vs the v3.1 monolithic ~975. Phase files are 32-99 lines each, loaded on demand.

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
> cd into a child repo first.

### 0c. Scope resolution (monorepo)

If `MEMBER` set:
- Try `cd packages/$MEMBER`, then `cd apps/$MEMBER`, then `find . -maxdepth 3 -type d -name "$MEMBER" | head -1`
- If found → cd in
- If not → abort with list of detected members

If `MEMBER` empty AND CWD has `AGENTS.md` AND a parent up to 3 levels also has `AGENTS.md` → **monorepo member detected**. Load both.

If `MEMBER` empty AND only parent has `AGENTS.md` → ask: run at root scope / pick member / abort.

### 0d. Read AGENTS.md(s)

`Read`: `<scope>/AGENTS.md`. If monorepo member: also `Read` root `AGENTS.md`.

If primary AGENTS.md missing → stop: "AGENTS.md not found. Run `/madd-init` first."

### 0e. Extract & merge key facts (inheritance)

Parse AGENTS.md into working memory:
- `PACKAGE_MANAGER`, `TEST_CMD`, `BUILD_CMD`, `DEV_CMD`, `DEPLOY_CMD`, `TYPECHECK_CMD`, `LINT_CMD`
- `FF_POLICY`, `COMMENT_STYLE`, `ERROR_POLICY`
- `FRAMEWORK`, `LANGUAGE`, `TEST_RUNNER`

For monorepo member with `## Inherits from`: load root fields first, overlay member fields (member wins).

If any required field missing after merge → ask user to fill or re-run `/madd-init`.

### 0f. Detect package manager drift

`Bash` — collect both signals, then apply precedence:
```bash
PM_FIELD=$(jq -r '.packageManager // empty' package.json 2>/dev/null | sed 's/@.*//')
PM_LOCK=""
for f in pnpm-lock.yaml yarn.lock bun.lockb package-lock.json; do
  if [ -f "$f" ]; then
    case "$f" in
      pnpm-lock.yaml)     PM_LOCK="pnpm"; break ;;
      yarn.lock)          PM_LOCK="yarn"; break ;;
      bun.lockb)          PM_LOCK="bun";  break ;;
      package-lock.json)  PM_LOCK="npm";  break ;;
    esac
  fi
done

# Precedence: lockfile > packageManager field > AGENTS.md > unset
if [ -n "$PM_LOCK" ]; then PM_DETECTED="$PM_LOCK"
elif [ -n "$PM_FIELD" ]; then PM_DETECTED="$PM_FIELD"
else PM_DETECTED=""
fi
echo "PM_FIELD=$PM_FIELD  PM_LOCK=$PM_LOCK  PM_DETECTED=$PM_DETECTED"
```

Compare `PM_DETECTED` against AGENTS.md `PACKAGE_MANAGER`. If mismatch → warn, ask which to trust. **Lockfile wins by default** (codified above): a checked-in `pnpm-lock.yaml` is ground truth even if `packageManager` field disagrees, because CI / `pnpm install --frozen-lockfile` will use the lockfile.

If `PM_FIELD` and `PM_LOCK` both set and disagree → flag as drift; user picks. Lockfile remains the default.

### 0g. Determine work size

`AskUserQuestion`:
- question: "What size is this change?"
- header: "Change scope"
- options:
  - "Standard" — Full 8 phases (default for features)
  - "Quickfix" — Skip Phase 1 spec + Phase 2 schema (typos, deps, doc fixes)
  - "Hotfix" — Skip 1, 2, 7; deploy after Phase 6 (production bug)

Store as `SHIP_MODE`.

### 0h. Branch hygiene — pull base, create feature branch

Parse `--base <branch>` and `--no-new-branch` flags. If `--no-new-branch` → skip to Phase 1.

**Detect base branch** (priority): `--base` arg → AGENTS.md `BASE_BRANCH` → `origin/HEAD` → `main` → `master` → ask.

```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
```

Store as `BASE`.

**Working tree clean check:**
```bash
git status --porcelain
```

If dirty → ask: "Stash changes" / "Commit first" / "Cancel ship".

**Pull latest base:**
```bash
git fetch origin "$BASE"
git checkout "$BASE"
git pull --ff-only origin "$BASE"
```

If diverged → abort, ask user resolve.

**Derive feature branch name** from description: slugify lowercase, spaces → `-`, strip non-`[a-z0-9-]`, prefix per AGENTS.md commit convention (default `feat/`), truncate 50 chars.

`AskUserQuestion`: "Use branch name `<derived>`?" — "Yes — create" / "Edit name" / "Use existing branch".

```bash
git checkout -b "$FEATURE_BRANCH"
```

Store `BASE` + `FEATURE_BRANCH` for Phase 6 (PR target).

### 0i. Detect work type (keyword pass)

Parse feature description for domain keywords:

| WORK_TYPE | Keywords |
|-----------|----------|
| `FE` | component, page, UI, frontend, design, view, layout, style, CSS, Next.js, React, Vue, Svelte, screen, modal, form, button |
| `BE` | API, endpoint, controller, service, NestJS, backend, REST, GraphQL, handler, middleware |
| `DEVOPS` | Dockerfile, docker-compose, CI, pipeline, deploy, infra, k8s, kubernetes, nginx, proxy, workflow, GitHub Actions, GitLab CI |
| `ROBOT` | MQL5, MQL4, EA, Expert Advisor, Arduino, ESP32, firmware, embedded, hardware, mechatronics, flash, microcontroller |
| `DATA` | migration, seed, ETL, backfill, database schema, Sequelize, data job, data pipeline, ALTER TABLE, DROP COLUMN |
| `FULLSTACK` | FE + BE keywords both present |

Default: `BE` if no strong signal.

**If ROBOT keywords** → stop and inform; offer `/madd-robot`. **If DATA keywords** → stop; offer `/madd-data`.

Store keyword pass as `WORK_TYPE_KEYWORD`.

### 0i.5. File-tree work-type signal

```bash
git diff --name-only "$BASE"...HEAD 2>/dev/null | head -50
```

If empty (first ship for branch) → skip; set `tree_signal_resolved = false`. Re-run at Phase 2 commit.

Otherwise classify each path:

| Pattern | Signal |
|---------|--------|
| `Dockerfile`, `docker-compose*`, `.github/workflows/**`, `wrangler.*`, `vercel.json`, `fly.toml`, `terraform/**`, `helm/**`, `k8s/**` | DEVOPS |
| `**/*.tsx`, `**/*.jsx`, `**/*.vue`, `**/*.svelte`, `**/*.astro`, `app/**`, `src/components/**`, `src/pages/**`, `styles/**` | FE |
| `prisma/migrations/**`, `**/*.sql`, `migrations/**`, `seeds/**`, `db/**` | DATA |
| `**/*.mq4`, `**/*.mq5`, `**/*.ino`, `firmware/**`, `arduino/**` | ROBOT |
| `**/api/**`, `**/handlers/**`, `**/controllers/**`, `**/services/**`, `routes/**`, `**/*.py` (non-test), `**/*.go`, `**/*.rs` | BE |

Strict majority → `WORK_TYPE_TREE`. Tie → unset.

### 0i.6. Precedence merge

| KEYWORD | TREE | → WORK_TYPE | Action |
|---------|------|-------------|--------|
| set | unset | KEYWORD | keyword wins |
| unset | set | TREE | tree wins |
| set | set, same | KEYWORD | either |
| set | set, FE/BE mix | FULLSTACK | promote |
| set | set, different | TREE | tree wins; confirm via AskUserQuestion |
| unset | unset | BE | default fallback |

Store final as `WORK_TYPE`.

### 0j. Resume protocol (state file)

```bash
test -f .madd-ship-state.json && cat .madd-ship-state.json || echo MISSING
```

If MISSING → no resume; jump to 0j.c (init fresh state) → load Phase 1.

If present, parse `state.feature`, `state.branch`, `state.phase`, `state.phase_started`.

**Semantics:** `state.phase` records the last **completed** phase (phase files write `phase = N` at the end of phase N). Resume therefore continues at `phase + 1`.

**Reconciliation:**

| state.feature | $ARGS feature | state.branch | current branch | Action |
|---------------|---------------|--------------|----------------|--------|
| matches | matches | matches | matches | Resume offer |
| matches | matches | matches | different | Ask: checkout state.branch then resume? |
| different | different | matches | current | Ask: continue old or checkpoint + new? |
| matches | empty | matches | matches | Resume offer (no args = resume request) |

`AskUserQuestion` (skip if `--resume` or `--fresh` flagged):
- "Existing ship state for `<state.feature>` — phase <state.phase> completed. Resume or fresh?"
- options:
  - "Resume from phase <N+1>" — load state, skip to the next uncompleted phase file
  - "Show state, then decide" — Read full state; loop back
  - "Checkpoint + start fresh" — invoke `/madd-checkpoint --note auto-pre-fresh`, then 0j.c
  - "Start fresh (discard state)" — wipe state, warn loudly, then 0j.c

**Capture `RESUME_FROM`** — on "Resume from phase <N+1>" or `--resume` flag:

```
RESUME_FROM = parseInt(state.phase, 10) + 1
```

`state.phase` is the last completed phase, so resume starts at the next one. If `RESUME_FROM > 8` → ship already complete; offer Phase 8d/8e cleanup instead.

`RESUME_FROM` must be set before phase dispatch (line "Resume case: if 0j set `RESUME_FROM = N`..." below) reads it. On fresh / discard / checkpoint paths, `RESUME_FROM` stays unset → phase dispatch starts at Phase 1.

### 0j.c. Initialize / refresh state

`Write` `.madd-ship-state.json`:

```json
{
  "feature": "<derived from $ARGUMENTS>",
  "feature_description": "<full $ARGUMENTS minus flags>",
  "branch": "<FEATURE_BRANCH>",
  "base": "<BASE>",
  "ship_mode": "<SHIP_MODE>",
  "work_type": "<WORK_TYPE>",
  "member": "<MEMBER or null>",
  "phase": "0",
  "phase_started": "<ISO>",
  "tests_red_confirmed": false,
  "last_test_exit": null,
  "tree_signal_resolved": false,
  "spec": null,
  "conventions": null,
  "_meta": { "madd_version": "3.2.0", "created_at": "<ISO>" }
}
```

Add gitignore if missing:
```bash
grep -q '\.madd-ship-state\.json' .gitignore 2>/dev/null || echo '.madd-ship-state.json' >> .gitignore
grep -q '\.madd-ship-state\.backup-' .gitignore 2>/dev/null || echo '.madd-ship-state.backup-*.json' >> .gitignore
```

### 0j.d. State write helper (used by all phase files)

At each `**[state]**` callout in a phase file:

```bash
node -e "
const fs = require('fs');
const j = JSON.parse(fs.readFileSync('.madd-ship-state.json', 'utf8'));
// updates here, e.g. (phase is set to N only when phase N COMPLETES):
j.phase = '4';
j.phase_started = new Date().toISOString();
j.tests_red_confirmed = true;
fs.writeFileSync('.madd-ship-state.json', JSON.stringify(j, null, 2));
"
```

Hook `madd-phase-guard.sh` reads these fields. Stale or missing → hook misfires.

---

## Phase dispatch

Now load + execute each phase file in order. Use `Read` on the phase file, then follow the runbook within. Skip rules:

| Phase | File | Skip if |
|-------|------|---------|
| 1 | `commands/madd-ship-phases/phase-1-spec.md` | `SHIP_MODE != "Standard"` |
| 2 | `commands/madd-ship-phases/phase-2-schema.md` | `SHIP_MODE == "Quickfix"` |
| 3 | `commands/madd-ship-phases/phase-3-tests-red.md` | never |
| 4 | `commands/madd-ship-phases/phase-4-impl.md` | never |
| 5 | `commands/madd-ship-phases/phase-5-green.md` | never |
| 6 | `commands/madd-ship-phases/phase-6-ci.md` | never |
| 7 | `commands/madd-ship-phases/phase-7-uat.md` | `SHIP_MODE == "Hotfix"` |
| 8 | `commands/madd-ship-phases/phase-8-prod.md` | never |

Resume case: if 0j set `RESUME_FROM = N`, skip directly to phase N's file (N = last completed + 1). Don't re-run earlier phases. Skip rules above still apply — if phase N is skipped for the current `SHIP_MODE`, advance to the next non-skipped phase.

Each phase file ends with "Return to orchestrator → load `phase-<N+1>-*.md`". Follow that pointer.

---

## Agent delegation (when handing off mid-ship)

If user wants to delegate phases 2-6 to a background agent:

### Build handoff prompt (auto-populated)

`Read`: AGENTS.md + current spec from this session + relevant phase files (2-6).

Construct prompt with **real values** (no `<placeholder>` syntax):

```
Branch: <git branch --show-current>

Spec:
<full spec block from Phase 1>

Test list (contract):
<named test list from Phase 1>

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

Phase files to follow (read in order):
- commands/madd-ship-phases/phase-2-schema.md
- commands/madd-ship-phases/phase-3-tests-red.md
- commands/madd-ship-phases/phase-4-impl.md
- commands/madd-ship-phases/phase-5-green.md
- commands/madd-ship-phases/phase-6-ci.md

Task: Execute Phases 2-6. Stop and report before Phase 7 UAT.
```

`Agent` tool, `subagent_type: "general-purpose"`. **Never delegate Phase 1** — spec decisions stay in main.

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

Enforced at tool layer by `madd-commit-prefix.sh` when state file or AGENTS.md opts in.

---

## Failure modes

| Symptom | Cause | Recovery |
|---------|-------|----------|
| AGENTS.md missing | Project not initialized | `/madd-init` |
| AGENTS.md fields missing | Stale or incomplete | Edit or re-run `/madd-init existing` |
| Detected PM ≠ AGENTS.md | Drift since init | Update AGENTS.md; lockfile wins |
| Tests RED for wrong reason | Import / syntax error | Fix stubs/imports first |
| Phase 6 build fails | Type or lint error | Fix locally; do not bypass hooks |
| Phase 7 regression | Adjacent feature broken | Stop; fix or document trade-off |
| Phase 8 deploy fails | Platform error | Check `<DEPLOY_CMD>` output; do not retry blindly |
| Rollback hash missing | Wrong hash entered | Re-fetch from `git log`; verify with `git cat-file -e` |
| Phase file Read fails | Sub-file not installed | Re-run `install.sh` to fetch `commands/madd-ship-phases/` |
| Phase 0j detects orphan state | Earlier session crashed | Resume or `/madd-rollback` to a checkpoint |

---

## Caveats

- This skill makes **real** tool calls. Do not narrate — execute.
- All phase gates use `AskUserQuestion`. Markdown checkboxes are visual; the question tool is the gate.
- `WORKLOG.md` is appended via real `Edit` tool, not reminder text.
- Agent handoff substitutes **real values** before sending — no `<placeholder>` syntax in the final prompt.
- Rollback verifies commit hash exists before reverting.
- `SHIP_MODE` branches behavior — Quickfix/Hotfix skip declared phases.
- `.madd-ship-state.json` is a real load-bearing artifact, not documentation. `madd-phase-guard.sh` reads `tests_red_confirmed` and `last_test_exit` from it to gate `feat:` commits and `git push`. Stale state → hook misfires. The `**[state]**` callouts in phase files are not optional reminders.
- `.madd-ship-state.json` is local-only (gitignored). Do not commit.
- Resume protocol (Step 0j) trusts the state file. If a teammate hands you a branch with no state, run `--fresh` — don't reconstruct state by hand.
- Phase files in `commands/madd-ship-phases/` are not slash commands themselves. They're sub-runbooks loaded via `Read`. The orchestrator stays in control.
