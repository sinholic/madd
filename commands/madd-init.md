---
description: "Initialize AGENTS.md + WORKLOG.md + .claude/settings.json (with MADD phase + commit-prefix + no-debug-code hooks) for project. Detects stack + shape (single repo / monorepo / multi-repo workspace), asks user, writes files. Required before /madd-ship."
argument-hint: "[new|existing] [--member <pkg>] [--all-members]"
version: "2.5.0"
changelog: |
  2.5.0 — Step 1.6 (monorepo) + Step 1.7 (workspace) extracted to commands/madd-init-shapes/{monorepo,workspace}.md; orchestrator reads sub-files only when shape matches. SINGLE path (most common) drops ~25% baseline load.
  2.4.0 — Step 8.5b registers three MADD phase-discipline hooks (madd-phase-guard, madd-commit-prefix, madd-no-debug-code) in generated settings.json; Step 8.5c gitignores .madd-ship-state.json + checkpoints
  2.3.0 — Step 8.5: write .claude/settings.json with model routing + forbidden-ops hooks (Sonnet default, Haiku confirmations, git push/npm publish/migrate/rm-rf gates)
  2.2.0 — Workspace + monorepo support: classify shape (single/mono/multi-repo), per-package AGENTS.md mode, root index for workspaces
  2.1.0 — Dogfood patches: parallel-call, find-not-glob, wrangler.json, merge gap detection, pnpm ls fallback
  2.0.0 — Operational runbook rewrite
  1.1.0 — Aspirational scaffold
  1.0.0 — Template only
---

# Runbook: Initialize MADD for this project

You are executing the `/madd-init` skill. Follow steps in order. Do not skip detection. Do not write AGENTS.md until user confirms all fields.

Argument received: `$ARGUMENTS` (may include `new`, `existing`, `--member <name>`, `--all-members`, or empty)

---

## Step 1 — Mode resolution

If `$ARGUMENTS` lacks `new` or `existing`:

`AskUserQuestion`:
- question: "New project or existing project?"
- header: "Project type"
- options:
  - "Existing" — Detect stack from manifests
  - "New" — Scaffold from scratch via questionnaire

Store as `MODE`.

---

## Step 1.5 — Workspace shape classification

**Critical:** Determine if CWD is a single repo, monorepo, or multi-repo workspace BEFORE proceeding. Misclassification produces wrong AGENTS.md structure.

### 1.5a. Detection bash (separate calls, not chained)

`Bash` 1 — parent git repo check:
```bash
TOP=$(git rev-parse --show-toplevel 2>/dev/null)
CWD=$(pwd)
if [ "$TOP" = "$CWD" ]; then echo "PARENT_GIT: yes"
elif [ -n "$TOP" ]; then echo "PARENT_GIT: inside-repo at $TOP"
else echo "PARENT_GIT: no"
fi
```

`Bash` 2 — sibling git repos:
```bash
find . -mindepth 2 -maxdepth 2 -name .git -type d 2>/dev/null | sed 's|/.git$||' | sort
```

`Bash` 3 — workspace markers at root:
```bash
for f in pnpm-workspace.yaml turbo.json nx.json lerna.json go.work; do
  test -f "$f" && echo "MARKER: $f"
done
test -f package.json && jq -e '.workspaces' package.json >/dev/null 2>&1 && echo "MARKER: package.json (workspaces field)"
test -f Cargo.toml && grep -q '^\[workspace\]' Cargo.toml && echo "MARKER: Cargo.toml [workspace]"
test -f pyproject.toml && grep -qE '\[tool\.(uv|hatch|rye)\.workspace\]' pyproject.toml && echo "MARKER: pyproject.toml workspace"
```

### 1.5b. Classify

| PARENT_GIT | MARKER present | CHILD repos > 0 | → `SHAPE` |
|------------|----------------|-----------------|-----------|
| yes        | yes            | (any)           | `MONOREPO` |
| yes        | no             | 0               | `SINGLE` |
| yes        | no             | >0              | `SINGLE` (children are submodules; warn) |
| no         | (any)          | >1              | `WORKSPACE` |
| no         | (any)          | 0-1             | `LOOSE` (just a folder) |
| inside-repo | (any)         | (any)           | `INSIDE` (CWD is within a larger repo) |

### 1.5c. Branch per shape

**SINGLE** → continue to Step 2 (current single-repo flow).

**MONOREPO** → Step 1.6.

**WORKSPACE** → Step 1.7.

**LOOSE** → Report to user:
> Empty/loose folder. Suggest:
>   - `/madd-vibe` for new prototype
>   - Or cd into an existing repo first

Then exit.

**INSIDE** → Report to user:
> Currently inside larger repo at `<TOP>`. Suggest:
>   - cd to `<TOP>` and re-run for root-level init
>   - Or run with `--member <current-subdir>` if monorepo member init intended

Ask via `AskUserQuestion`: continue here as SINGLE, or abort.

---

## Step 1.6 — Monorepo flow

SHAPE = MONOREPO. `Read` `commands/madd-init-shapes/monorepo.md` and follow it. Returns control here at Step 2 once `MONO_STRATEGY` and `SELECTED_MEMBERS` are set.

---

## Step 1.7 — Multi-repo workspace flow

SHAPE = WORKSPACE. `Read` `commands/madd-init-shapes/workspace.md` and follow it. Returns control here at Step 2 for any chosen per-repo loops, or directly to write `WORKSPACE.md` for index-only mode.

---

## Step 2 — Pre-flight check (single repo / per-member)

This step assumes you are in a single repo's working dir (set by Step 1.5c branch or by Step 1.6d / 1.7c loop).

`Bash`:
```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
echo "---"
for f in AGENTS.md WORKLOG.md LEARNINGS.md; do
  test -f "$f" && echo "EXISTS: $f ($(wc -c <"$f") bytes)" || echo "MISSING: $f"
done
test -f .claude/settings.json && echo "EXISTS: .claude/settings.json" || echo "MISSING: .claude/settings.json"
echo "---"
find . -maxdepth 1 -type f \( \
  -name 'package.json' -o -name 'pnpm-lock.yaml' -o -name 'yarn.lock' -o \
  -name 'package-lock.json' -o -name 'bun.lockb' -o \
  -name 'go.mod' -o -name 'Cargo.toml' -o -name 'pyproject.toml' -o \
  -name 'Pipfile' -o -name 'Gemfile' -o -name 'composer.json' \
\) 2>/dev/null
```

Outcomes:
- **AGENTS.md EXISTS** → `AskUserQuestion`: Overwrite (with backup) / Abort / Merge
- **Not in git repo** → warn user; ask continue or `git init` first
- **No manifest files** → likely empty; force `MODE = new`

---

## Step 3 — Stack detection (existing mode only)

Run detections **as separate parallel Bash tool calls** — DO NOT chain with `&&` (chained commands stop on first non-zero exit).

**Detect package manager (Node/JS):**
```bash
test -f package.json && jq -r '.packageManager // empty' package.json 2>/dev/null
```
```bash
for f in pnpm-lock.yaml yarn.lock bun.lockb package-lock.json; do test -f "$f" && echo "$f"; done
```

Priority: `packageManager` field → pnpm → yarn → bun → npm.

**Detect language / runtime:**
```bash
test -f tsconfig.json && echo "typescript"
```
```bash
test -f package.json && jq -r '.type // empty, .engines // empty | tostring' package.json 2>/dev/null
```
```bash
test -f go.mod && head -3 go.mod
test -f Cargo.toml && head -5 Cargo.toml
test -f pyproject.toml && head -10 pyproject.toml
test -f Pipfile && head -10 Pipfile
test -f Gemfile && head -5 Gemfile
```

**Detect framework (Node):**
```bash
test -f package.json && jq -r '(.dependencies // {}) + (.devDependencies // {}) | to_entries | .[] | .key' package.json 2>/dev/null | \
  grep -E '^(astro|next|react|vue|svelte|nuxt|remix|express|fastify|hono|nest|gatsby|@sveltejs/kit)$' | head -5
```

**Detect test runner:**
```bash
test -f package.json && jq -r '(.dependencies // {}) + (.devDependencies // {}) | to_entries | .[] | .key' package.json 2>/dev/null | \
  grep -E '^(vitest|jest|@playwright/test|cypress|mocha|tap|ava|uvu|bun:test)$' | head -5
```
```bash
test -f pytest.ini && echo "pytest"
test -f go.mod && echo "go test (built-in)"
test -f Cargo.toml && echo "cargo test (built-in)"
```

**Detect scripts (Node):**
```bash
test -f package.json && jq -r '.scripts // {} | to_entries | .[] | "\(.key): \(.value)"' package.json 2>/dev/null
```

**Detect deployment** — use `find`, NOT shell globs:
```bash
find . -maxdepth 2 -type f \( \
  -name 'vercel.json' -o -name 'netlify.toml' -o \
  -name 'wrangler.toml' -o -name 'wrangler.json' -o -name 'wrangler.jsonc' -o \
  -name 'fly.toml' -o -name 'render.yaml' -o -name 'Dockerfile' -o \
  -name 'app.yaml' -o -name 'serverless.yml' \
\) 2>/dev/null
find .github/workflows -type f -name 'deploy*.yml' 2>/dev/null
find .github/workflows -type f -name 'deploy*.yaml' 2>/dev/null
```

**Detect directory structure:**
```bash
find . -maxdepth 2 -type d \
  -not -path '*/node_modules*' -not -path '*/.git*' -not -path '*/dist*' -not -path '*/.next*' \
  -not -path '*/target*' -not -path '*/__pycache__*' -not -path '*/.venv*' \
  -not -path '*/build*' -not -path '*/.svelte-kit*' -not -path '*/.astro*' \
  2>/dev/null | sort | head -30
```

**Detect commit convention:**
```bash
git log --oneline -20 2>/dev/null | awk '{print $2}' | sort -u | head -10
```

Synthesize `STACK`.

---

## Step 4 — Confirm / fill stack

### 4a. Presentation

Show detected stack as list — confirmed value or "not detected" per field.

### 4b. Merge-mode gap detection

If user picked **Merge** in Step 2, before asking questions:

`Read` existing AGENTS.md. Check:

1. **Stale skill refs:**
   ```bash
   grep -nE '\b/ship\b' AGENTS.md 2>/dev/null
   ```
   If hits → flag for auto-fix `/ship` → `/madd-ship`.

2. **Embedded workflow doc:**
   ```bash
   grep -cE '^### Phase [0-9]' AGENTS.md
   ```
   If count ≥ 3 → flag for auto-strip; replace with link to `/madd-ship`.

3. **Missing conventions:**
   ```bash
   grep -qE 'Feature flags|FF_POLICY' AGENTS.md || echo "MISSING: flags"
   grep -qE 'Comment|COMMENT_STYLE' AGENTS.md || echo "MISSING: comments"
   grep -qE 'Error handling|ERROR_POLICY' AGENTS.md || echo "MISSING: errors"
   ```

4. **Missing stack rows:** compare detected vs existing Stack table.

### 4c. Ask user

For NEW: ask all 8 fields.
For MERGE: ask only gaps from 4b.
For MONOREPO hybrid + per-member call: ask only override fields (not shared ones already in root).

(Q1-Q8 unchanged from v2.1.0)

---

## Step 5 — Validate stack tools

Two-tier check.

Global PATH:
```bash
for tool in node pnpm yarn npm bun python3 go cargo ruby php; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "GLOBAL: $tool $($tool --version 2>&1 | head -1)"
  fi
done
```

DevDep fallback (Node):
```bash
test -f package.json && for tool in wrangler vitest playwright tsx; do
  pnpm ls "$tool" --depth=0 2>/dev/null | grep -q "$tool" && echo "DEVDEP: $tool (via pnpm)"
done
```

---

## Step 6 — Derive key commands

Build commands table from STACK + scripts.

| Purpose | Command |
|---------|---------|
| Dev server | `<pm> run dev` or detected script |
| Build | `<pm> run build` |
| Test | `<pm> test`, `pytest`, `go test ./...`, `cargo test` |
| Type check | `<pm> run typecheck` or `tsc --noEmit` |
| Lint | `<pm> run lint` |
| Deploy | extracted from platform |

If missing: `AskUserQuestion`.

---

## Step 7 — Write AGENTS.md

### 7a. Single repo / per-member full

Use template below. Substitute STACK values.

For MERGE: apply 4b auto-fixes (rename refs, strip workflow, add missing rows, append conventions). Preserve user-added sections.

`Write` to `<scope>/AGENTS.md`.

### 7b. Monorepo root index (when `MONO_STRATEGY = per-package`)

Write minimal root AGENTS.md:

```markdown
# AGENTS.md — {monorepo-name}

Monorepo root. Per-package AGENTS.md in each member dir.

## Members

| Member | Path | Stack |
|--------|------|-------|
| {name-1} | [./packages/{name-1}/AGENTS.md](./packages/{name-1}/AGENTS.md) | {framework} |
| {name-2} | [./apps/{name-2}/AGENTS.md](./apps/{name-2}/AGENTS.md) | {framework} |

## Shared

- Package manager: {pm}
- Monorepo tool: {turbo|nx|lerna|pnpm-workspace|none}
- Root commands:
  \`\`\`bash
  {pm} install
  {pm} -r build   # or turbo run build / nx run-many
  \`\`\`

## MADD scope

Use `/madd-ship --member <name>` to scope ship to a member. Without `--member`, ship operates at root.
```

### 7c. Monorepo hybrid root + per-member

Root AGENTS.md gets full template (stack, conventions, commands shared across monorepo). Each member AGENTS.md gets:

```markdown
# AGENTS.md — {member-name}

Inherits from [`../AGENTS.md`](../AGENTS.md) (or `../../AGENTS.md`). Below = overrides only.

## Overrides

| Field | Override | Reason |
|-------|----------|--------|
| ... | ... | ... |

## Member-specific

- ...
```

### 7d. Full template (single / per-member full / monorepo root-only)

```markdown
# AGENTS.md — {PROJECT_NAME}

Self-onboarding guide for engineers and AI agents. Maintained by `/madd-init` v2.3.0. Updated {ISO_DATE}.

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | {FRAMEWORK} |
| Language | {LANGUAGE} |
| Package manager | {PACKAGE_MANAGER} {PM_VERSION} |
| Test runner | {TEST_RUNNER} |
| Deployment | {DEPLOYMENT} ({DEPLOY_CONFIG_FILE}) |
| Runtime | {RUNTIME} |

## Key commands

\`\`\`bash
{DEV_CMD}        # Dev server
{BUILD_CMD}      # Production build
{TEST_CMD}       # Run tests
{TYPECHECK_CMD}  # Type check
{LINT_CMD}       # Lint
{DEPLOY_CMD}     # Deploy
\`\`\`

## Directory structure

\`\`\`
{TREE_OUTPUT}
\`\`\`

## Delivery workflow

Drive features via [`/madd-ship <description>`](https://github.com/sinholic/madd). 8-phase SDD+TDD.

Other MADD skills:
- `/madd-init` — this scaffold
- `/madd-learn` — post-ship learning capture
- `/madd-debug` — systematic debug session
- `/madd-review` — source code review
- `/madd-secure` — security review
- `/madd-vibe` — prototype mode (new projects)
- `/madd-update` — update MADD skills

## Conventions

| Convention | Policy |
|------------|--------|
| Feature flags | {FF_POLICY} |
| Comments | {COMMENT_STYLE} |
| Error handling | {ERROR_POLICY} |
| Commit prefixes | `schema:` / `test(red):` / `feat:` / `refactor:` / `fix:` |

## Agent delegation

| Work type | Mode |
|-----------|------|
| Exploratory / uncertain | Main conversation |
| Spec-complete + named tests | Background agent OK |
| `/madd-ship` Phase 1 (Spec) | Never delegate |

## Documentation standards

- `AGENTS.md` — regenerated by `/madd-init` when stack changes
- `WORKLOG.md` — `/madd-ship` Phase 4 auto-appends per feature
- `LEARNINGS.md` — `/madd-learn` fallback when MCP unavailable
- `REVIEW.md` / `SECURITY.md` — `/madd-review` / `/madd-secure` outputs

## Project metadata

- Initialized: {ISO_DATE}
- Shape: {SHAPE}  ({single|monorepo-root|monorepo-member|workspace-repo})
- Mode: {MODE}
- MADD version: 2.3.0
```

---

## Step 8 — Write WORKLOG.md (if missing)

Per-scope. Single repo → one WORKLOG.md. Monorepo per-package mode → WORKLOG.md per member (where feature work happens). Workspace → per-repo, same as single.

Check:
```bash
test -f WORKLOG.md && echo EXISTS || echo MISSING
```

If MISSING, `Write` standard WORKLOG.md template (unchanged from v2.1.0).

---

## Step 8.5 — Write .claude/settings.json (Claude Code safety defaults)

Per-scope. Writes cost-control + forbidden-ops config for Claude Code. Applies to every scope that gets an AGENTS.md (single repo, monorepo member, workspace repo).

### 8.5a. Check existing

`Bash`:
```bash
test -f .claude/settings.json && echo EXISTS || echo MISSING
mkdir -p .claude
```

If EXISTS → `AskUserQuestion`:
- question: "`.claude/settings.json` exists. What to do?"
- header: "Settings"
- options:
  - "Skip — keep existing" (Recommended if already customized)
  - "Overwrite — replace with MADD defaults"
  - "Merge — add missing keys only (preserves custom hooks)"

Store as `SETTINGS_MODE`. If Skip → jump to Step 9.

### 8.5b. Write / merge

**Overwrite or MISSING** — `Write` to `<scope>/.claude/settings.json`:

```json
{
  "model": "sonnet",
  "permissions": {
    "ask": [
      "Bash(git push *)",
      "Bash(npm publish)",
      "Bash(npx sequelize db:migrate)",
      "Bash(rm -rf *)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Forbidden op: git push. Confirm intentional: $ARGUMENTS",
            "if": "Bash(git push *)",
            "model": "haiku"
          },
          {
            "type": "prompt",
            "prompt": "Confirm npm publish: $ARGUMENTS. Package version correct + ready?",
            "if": "Bash(npm publish)",
            "model": "haiku"
          },
          {
            "type": "prompt",
            "prompt": "DB migration: $ARGUMENTS. Rollback plan documented? Safe to run?",
            "if": "Bash(npx sequelize db:migrate)",
            "model": "haiku"
          },
          {
            "type": "prompt",
            "prompt": "DESTRUCTIVE: rm -rf $ARGUMENTS. Backup exists? Last chance to abort.",
            "if": "Bash(rm -rf *)",
            "model": "haiku"
          },
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/madd-phase-guard.sh"
          },
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/madd-commit-prefix.sh"
          }
        ]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/madd-no-debug-code.sh"
          }
        ]
      }
    ]
  },
  "attribution": {
    "commit": "Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>",
    "pr": ""
  }
}
```

**Merge** — `Read` existing file, then apply only missing top-level keys:
- No `"model"` → add `"model": "sonnet"`
- No `permissions.ask` → add the full array above
- No `hooks.PreToolUse` → add the full hooks block above
- `hooks.PreToolUse` present but missing MADD entries → append the three MADD hooks (`madd-phase-guard`, `madd-commit-prefix` under `Bash` matcher; `madd-no-debug-code` under `Edit|Write` matcher). Deduplicate by `command` path so re-runs are idempotent.
- No `attribution` → add attribution block
- Preserve all existing keys

### 8.5c. .gitignore guard

`Bash`:
```bash
test -f .gitignore && grep -q '\.claude/settings\.json' .gitignore && echo SETTINGS_GITIGNORED || echo SETTINGS_NOT_IGNORED
test -f .gitignore && grep -q '\.madd-ship-state\.json' .gitignore && echo STATE_GITIGNORED || echo STATE_NOT_IGNORED
```

For settings.json: if `SETTINGS_NOT_IGNORED` → `AskUserQuestion`:
- question: "`.claude/settings.json` contains `model` + personal hooks. Add to .gitignore?"
- header: "Gitignore"
- options:
  - "Yes — gitignore (personal; team uses settings.local.json overrides)" (Recommended)
  - "No — commit to repo (team-wide model routing for everyone)"

If Yes:
```bash
echo '.claude/settings.json' >> .gitignore
```

For MADD state files: if `STATE_NOT_IGNORED` → always add (no question; these are local-only operational artifacts):

```bash
cat >> .gitignore <<'EOF'

# MADD operational state — local-only, do not commit
.madd-ship-state.json
.madd-ship-state.backup-*.json
.madd-pending-sync
.madd-learn-captured-*
.madd-recall-cache.json
.madd-ship-archive/
.madd-debug.md
MADD-CHECKPOINTS.md
EOF
```

**Note on team settings:** If you want team-wide hooks committed, use `.claude/settings.json`. For personal model override on top, use `.claude/settings.local.json` (gitignored, loads last, wins for overriding keys).

**Note on MADD-CHECKPOINTS.md:** Some teams may want this committed for shared visibility into local pivots. If so, remove the gitignore line manually after init. Default is local-only because checkpoints are personal recovery state.

---

## Step 9 — Summary & next step

Report per shape:

**Single repo:**
```
✓ AGENTS.md written
✓ WORKLOG.md created/preserved
✓ .claude/settings.json written (model: sonnet, forbidden-ops + MADD phase hooks)
✓ .gitignore updated (MADD state files local-only)
Hooks registered:
  - madd-phase-guard (blocks feat: commits before RED gate, push before green)
  - madd-commit-prefix (enforces schema:/stub:/test(red):/feat:/refactor:/fix:)
  - madd-no-debug-code (rejects console.log/print/debugger in non-test source)
Next: /madd-ship <feature>
```

**Monorepo:**
```
✓ Root AGENTS.md written
✓ N member AGENTS.md written: <list>
✓ WORKLOG.md(s) created
✓ .claude/settings.json written per scope
Next: cd <member> && /madd-ship <feature>
      or /madd-ship --member <name> <feature> from root
```

**Workspace:**
```
✓ WORKSPACE.md written at parent
✓ N repos initialized: <list>
✓ Skipped existing: <list>
✓ .claude/settings.json written in each initialized repo
Next: cd <repo> && /madd-ship <feature>
```

---

## Failure modes

| Symptom | Cause | Recovery |
|---------|-------|----------|
| Chained `&&` exits early | One detect returned non-zero | Run each as separate Bash call |
| zsh `no matches found` | Glob with no hits | Use `find -name` |
| `command -v X` empty + X in devDeps | Tool via pnpm only | Step 5 tier-2 check |
| Monorepo member glob unexpanded | Marker uses `packages/*` | Expand via `find packages -maxdepth 1 -type d` |
| Workspace has nested monorepo | Mixed shape | Treat outer as WORKSPACE; cd into the monorepo child and re-run for MONOREPO handling |
| `MEMBERS` count = 0 in monorepo | Marker present but no resolved packages | Warn user; fall through to root-only mode |
| User picks per-package but no member responses | Empty selection | Re-ask or default to all |
| `INSIDE` shape | CWD nested in larger repo | Warn; user picks: continue here as SINGLE / abort / cd to root |
| settings.json invalid JSON after merge | Bad existing file | Show jq parse error; ask to overwrite or fix manually |
| `.claude/` dir missing | Fresh repo | `mkdir -p .claude` before write (already in 8.5a bash) |
| hooks don't fire after write | Session started before file existed | Tell user to open `/hooks` in Claude Code UI or restart session |
| MADD phase hook references missing script | install.sh skipped hooks/ copy, or user installed commands/ only | Re-run `install.sh` or `/madd-update --include-hooks`. Until then, hook lines no-op silently — phase discipline reverts to AskUserQuestion gates only. |
| `madd-commit-prefix.sh` doesn't block | Not opted-in (no state file AND AGENTS.md doesn't mention MADD) | This is by design — running `/madd-ship` once will create the state file and activate the hook. For repos that want the prefix discipline before first ship, manually `echo MADD >> AGENTS.md`. |

---

## Caveats

- This skill makes **real** tool calls. Do not simulate detection — run Bash.
- Detection commands MUST be run as separate Bash invocations (parallel). Chaining with `&&` aborts on first non-zero exit.
- Step 1.5 SHAPE classification is mandatory — wrong shape → wrong AGENTS.md structure → all downstream MADD skills misbehave.
- For WORKSPACE: never write AGENTS.md at parent (parent is not a project). Only WORKSPACE.md index.
- For MONOREPO hybrid: per-member AGENTS.md MUST start with `## Inherits from` so `/madd-ship` Phase 0 knows to read root too.
- In merge mode, preserve user-added sections — do not silently drop them.
- Backup before overwrite — never destroy existing AGENTS.md without user OK.
- Step 8.5 writes `.claude/settings.json` per-scope (not at workspace parent — workspace parent is not a project). For monorepo per-package mode, write one settings.json per member scope (not root), since `/madd-ship` operates at member level.
- `.claude/settings.json` sets `"model": "sonnet"` — never auto-escalates to Opus. User must explicitly `/model opus` to override.
- Forbidden-ops hooks use Haiku (cheapest model) for confirmation prompts — intentional: fast, cheap, non-blocking for the confirmation itself.
- MADD phase hooks (`madd-phase-guard`, `madd-commit-prefix`, `madd-no-debug-code`) require the install.sh to have copied them to `~/.claude/hooks/`. If a user did manual install of `commands/` only, the hook lines will reference missing scripts — silent no-op. Run `install.sh` (or `/madd-update --include-hooks`) to fix.
- `madd-commit-prefix.sh` activates only when `.madd-ship-state.json` exists OR `AGENTS.md` references MADD. New `/madd-init` runs will produce both — but a manually-cloned repo without `/madd-init` won't trigger the prefix hook.
- `madd-no-debug-code.sh` is global (not gated on MADD opt-in) because debug code is a project-wide concern. Per-repo opt-out via `touch .madd-no-debug-code.disabled`.
- Step 8.5c gitignore additions for MADD state files are unconditional — these files are purely operational and should never be committed. Override manually if a team policy requires shared state visibility.
