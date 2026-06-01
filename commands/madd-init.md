---
description: "Initialize AGENTS.md + WORKLOG.md for project. Detects stack, asks user, writes files. Required before /madd-ship."
argument-hint: "[new|existing]"
version: "2.1.0"
changelog: |
  2.1.0 — Dogfood patches: parallel-call instruction, find-not-glob, wrangler.json detection, merge-mode gap detection + stale-ref scan + redundant-workflow strip, pnpm ls fallback for dev-dep tools
  2.0.0 — Operational runbook rewrite
  1.1.0 — Aspirational scaffold
  1.0.0 — Template only
---

# Runbook: Initialize MADD for this project

You are executing the `/madd-init` skill. Follow steps in order. Do not skip detection. Do not write AGENTS.md until user confirms all fields.

Argument received: `$ARGUMENTS` (may be `new`, `existing`, or empty)

---

## Step 1 — Mode resolution

If `$ARGUMENTS` is empty, ask user:

Use `AskUserQuestion`:
- question: "Is this a new project or existing project?"
- header: "Project type"
- options:
  - label: "Existing" — description: "Detect stack from package.json / lockfiles / source"
  - label: "New" — description: "Scaffold from scratch via questionnaire"

Store answer as `MODE`.

---

## Step 2 — Pre-flight check

Run via `Bash`. Use guard pattern so missing files don't exit 1:

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
echo "---"
for f in AGENTS.md WORKLOG.md LEARNINGS.md; do
  test -f "$f" && echo "EXISTS: $f ($(wc -c <"$f") bytes)" || echo "MISSING: $f"
done
echo "---"
find . -maxdepth 1 -type f \( \
  -name 'package.json' -o -name 'pnpm-lock.yaml' -o -name 'yarn.lock' -o \
  -name 'package-lock.json' -o -name 'bun.lockb' -o \
  -name 'go.mod' -o -name 'Cargo.toml' -o -name 'pyproject.toml' -o \
  -name 'Pipfile' -o -name 'Gemfile' -o -name 'composer.json' \
\) 2>/dev/null
```

Outcomes:
- **AGENTS.md EXISTS** → `AskUserQuestion`:
  - "Overwrite" — back up to `AGENTS.md.bak.<timestamp>` then regenerate
  - "Abort" — stop, report "AGENTS.md exists; abort"
  - "Merge" — read existing, treat as detection input, run merge-mode gap detection (Step 4b)
- **Not in a git repo** → warn user; ask continue anyway or run `git init` first
- **No manifest files** → likely empty repo; force `MODE = new`

---

## Step 3 — Stack detection (existing mode only)

If `MODE = existing`, run detections **as separate parallel Bash tool calls** (one tool call per command — DO NOT chain with `&&`; chained commands stop on first non-zero exit).

For each command below, make a separate `Bash` invocation.

**Detect package manager (Node/JS):**
```bash
test -f package.json && jq -r '.packageManager // empty' package.json 2>/dev/null
```
```bash
for f in pnpm-lock.yaml yarn.lock bun.lockb package-lock.json; do test -f "$f" && echo "$f"; done
```
Priority: `packageManager` field → pnpm → yarn → bun → npm. If multiple lockfiles, warn user and `AskUserQuestion` to pick.

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

**Detect deployment** — use `find`, NOT shell globs (zsh `nomatch` is not suppressed by `2>/dev/null`):
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

Synthesize detection results. Build a draft `STACK` object. Show user.

---

## Step 4 — Confirm / fill stack

### 4a. Detection presentation

Present detected stack as a list. For each field: confirmed value OR "not detected".

### 4b. Merge-mode gap detection (existing mode with merge)

If user picked **Merge** in Step 2, BEFORE asking questions, run a gap scan against the existing AGENTS.md:

`Read` existing AGENTS.md. Check for:

1. **Stale skill references** — search for old skill names:
   ```bash
   grep -nE '/(ship|init|learn|debug|review|secure|vibe|update)\b(?!/madd-)' AGENTS.md 2>/dev/null
   grep -nE '\b/ship\b' AGENTS.md 2>/dev/null
   ```
   If hits → flag for auto-fix: rename `/ship` → `/madd-ship`, etc.

2. **Embedded workflow doc** — check if AGENTS.md contains full Phase 1-8 inline (redundant with `/madd-ship` runbook):
   ```bash
   grep -cE '^### Phase [0-9]' AGENTS.md
   ```
   If count ≥ 3 → flag for auto-strip; replace with link to `/madd-ship`.

3. **Missing conventions section** — check for required fields:
   ```bash
   grep -qE 'Feature flags|FF_POLICY' AGENTS.md || echo "MISSING: feature-flags"
   grep -qE 'Comment|COMMENT_STYLE' AGENTS.md || echo "MISSING: comments"
   grep -qE 'Error handling|ERROR_POLICY' AGENTS.md || echo "MISSING: errors"
   ```
   Only ask user about MISSING fields.

4. **Missing stack rows** — compare detected vs existing Stack table:
   ```bash
   grep -E '^\| (Test runner|Runtime|Package manager) \|' AGENTS.md
   ```
   Add rows for any detected field not in existing table.

### 4c. Ask user (only missing/changed)

Use `AskUserQuestion` (batch up to 4):

For NEW mode: ask all.
For MERGE mode: ask only flagged gaps from 4b.

**Q1 — Framework:** options: detected, "Other"
**Q2 — Language:** options: detected, "Other"
**Q3 — Package manager** (Node): detected, alternates
**Q4 — Test runner:** detected, "None yet"
**Q5 — Deployment:** Vercel / Netlify / Cloudflare / Docker / AWS / Fly / Render / Other
**Q6 — Feature flags:** "No, direct change" (default) / "Yes, opt-in only" / "Yes, always"
**Q7 — Comment style:** "WHY only" (default) / "When unclear" / "Always document public surface"
**Q8 — Error handling:** "Boundaries only" (default) / "Defensive"

Store as `STACK`.

---

## Step 5 — Validate stack tools

For each detected tool, run actual existence check via `Bash`.

Use a two-tier check: global PATH first, then package-manager-local fallback for Node projects.

```bash
# Global PATH check
for tool in node pnpm yarn npm bun python3 go cargo ruby php; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "GLOBAL: $tool $($tool --version 2>&1 | head -1)"
  fi
done
```

For tools detected as devDependencies but not in global PATH (e.g., `wrangler`, `vitest`, `playwright`):
```bash
# Node devDep tools — verify via pnpm ls
test -f package.json && for tool in wrangler vitest playwright tsx; do
  pnpm ls "$tool" --depth=0 2>/dev/null | grep -q "$tool" && echo "DEVDEP: $tool (via pnpm)"
done
```

If any required tool missing in both global AND devDeps: report to user, ask whether to continue, abort, or accept an alternate command path.

---

## Step 6 — Derive key commands

Build commands table from STACK + detected scripts:

| Purpose | Command |
|---------|---------|
| Dev server | `<pm> run dev` or detected `dev` script |
| Build | `<pm> run build` |
| Test | `<pm> test` or detected; for Python `pytest`, Go `go test ./...`, Rust `cargo test` |
| Type check | `<pm> run typecheck` if present, else `tsc --noEmit` for TS |
| Lint | `<pm> run lint` if present |
| Deploy | extracted from deployment platform (e.g. `pnpm deploy`, `vercel`, `wrangler deploy`) |

If a command isn't found in scripts, `AskUserQuestion` for the canonical one.

---

## Step 7 — Write AGENTS.md

Construct AGENTS.md content (template below), substituting STACK values.

For MERGE mode: apply auto-fixes from 4b:
- Rename stale skill references
- Strip embedded Phase 1-8 section, replace with link to `/madd-ship`
- Add missing rows to Stack table
- Append conventions section

Then `Write` the merged content to `<repo-root>/AGENTS.md`. Always preserve user-added project-specific sections (e.g., "Project metadata", custom workflows) — do NOT silently drop them.

**Template:**

```markdown
# AGENTS.md — {PROJECT_NAME}

Self-onboarding guide for engineers and AI agents. Maintained by `/madd-init` v2.1.0. Updated {ISO_DATE}.

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
- Mode: {MODE}
- MADD version: 1.7.0
```

---

## Step 8 — Write WORKLOG.md (if missing)

Check existence via `Bash`:
```bash
test -f WORKLOG.md && echo EXISTS || echo MISSING
```

If MISSING, `Write` to `<repo-root>/WORKLOG.md`:

```markdown
# WORKLOG.md

Decision log for non-obvious choices. One entry per `/madd-ship` feature. Append-only.

## Entry format

\`\`\`
## <feature-name> — <ISO-date>
- <decision and why>
- <gotcha and resolution>
- <constraint discovered>
\`\`\`

If nothing non-obvious: still write an entry with `- No non-obvious decisions; straightforward impl per spec`.
```

If EXISTS, leave untouched.

---

## Step 9 — Summary & next step

Report to user:

```
✓ AGENTS.md written ({line-count} lines)
✓ WORKLOG.md {created|preserved}
✓ Stack validated: {tools-checked}
{if backup}  ✓ Backup: AGENTS.md.bak.{timestamp}

Next:
  /madd-ship <your first feature description>
```

If any tool validation failed earlier, repeat warning in summary.

---

## Failure modes

| Symptom | Cause | Recovery |
|---------|-------|----------|
| `jq: command not found` | jq missing | Fall back to `grep`/`sed` parsing; warn user to install jq for cleaner output |
| `git rev-parse` fails | Not in git repo | Use `pwd`; warn user; offer `git init` |
| zsh `no matches found` | Glob expansion with no hits | Use `find -name` not glob+`ls` |
| `AskUserQuestion` declined | User cancelled | Abort cleanly; do not write partial AGENTS.md |
| `Write` permission denied | Read-only fs | Report path; suggest alternate location |
| Multiple frameworks detected | Monorepo | Ask user which workspace; consider running `/madd-init` per workspace |
| `command -v wrangler` empty but tool in devDeps | Tool only via package manager | Use Step 5 tier-2 check (`pnpm ls`) |
| Chained `&&` exits early | One detect command returned non-zero | Run each as separate Bash tool call |

---

## Caveats

- This skill makes **real** tool calls. Do not simulate detection — run the Bash commands.
- Detection commands MUST be run as separate Bash invocations (parallel). Chaining with `&&` aborts on first non-zero exit.
- Do not assume detection output; show it to user via `AskUserQuestion` for confirmation.
- Do not write AGENTS.md mid-flow; only at Step 7 with full STACK gathered.
- Backup before overwrite — never destroy existing AGENTS.md without user OK.
- In merge mode, preserve user-added sections — do not silently drop them.
