# MADD — Misua AI Development Driven

Framework for SDD+TDD end-to-end feature delivery. Ships commands, hooks, and skills as a complete `.claude/` control center.

---

## Current version: 2.0.1

Released: 2026-06-11

---

## Skills (commands + hooks + auto-trigger skills)

### Slash commands

| Skill | Version | Status | Purpose |
|-------|---------|--------|---------|
| `madd-init` | 2.5.0 | Active runbook | Detection + scaffold; workspace shape classification (1.6/1.7 in `commands/madd-init-shapes/`); registers MADD hooks in `.claude/settings.json`; gitignores state + cache files |
| `madd-ship` | 3.2.0 | Active runbook | 8-phase delivery; phase bodies in `commands/madd-ship-phases/`; orchestrator loads each phase on demand; persistent state; Step 0j resume protocol; Step 0i.5 file-tree work-type signal; Phase 1a auto-`/madd-recall` |
| `madd-learn` | 2.0.0 | Active runbook | Post-ship capture; MCP primary, LEARNINGS.md fallback |
| `madd-recall` | 1.1.0 | Active runbook | Read-side of memory loop; cache layer + MCP + LEARNINGS.md grep fallback |
| `madd-status` | 1.1.0 | Active runbook | One-line digest by default (`--full` for box-drawing) |
| `madd-checkpoint` | 1.0.0 | **NEW** runbook | Local snapshot of state file + git stash before pivoting |
| `madd-rollback` | 1.0.0 | **NEW** runbook | Restore from checkpoint; distinct from prod revert |
| `madd-debug` | 1.0.0 | Active runbook | Systematic debug; scientific method, `.madd-debug.md` state |
| `madd-review` | 1.0.0 | Active runbook | Source review; severity-classified REVIEW.md |
| `madd-secure` | 1.0.0 | Active runbook | Security audit; SECURITY.md |
| `madd-vibe` | 1.0.0 | Active runbook | Prototype scaffold; skip discipline |
| `madd-update` | 1.0.0 | Active runbook | Fetcher; git/curl/local source, diff preview, backups |
| `madd-design` | 1.0.0 | Active runbook | Frontend design validation |
| `madd-devops` | 1.0.0 | Active runbook | Infra/CI review |
| `madd-data` | 1.0.0 | Active runbook | DB migration / pipeline flow |
| `madd-robot` | 1.0.0 | Active runbook | Embedded/firmware flow |
| ~~`madd-install`~~ | — | Removed | Circular; replaced by `/madd-update` |

### Hooks (`~/.claude/hooks/`)

| Hook | Event | Version | Purpose |
|------|-------|---------|---------|
| `madd-phase-guard.sh` | PreToolUse Bash | 2.0.0 | Reads `.madd-ship-state.json`; blocks `feat:` commits before Phase 3 RED gate confirmed; blocks `git push` when `last_test_exit != 0` |
| `madd-commit-prefix.sh` | PreToolUse Bash(git commit) | 2.0.0 | Enforces MADD prefix discipline; opt-in via state file or AGENTS.md mention |
| `madd-no-debug-code.sh` | PreToolUse Edit\|Write | 2.0.0 | Rejects `console.log`/`print(`/`dbg!(`/`debugger;` in non-test source; per-repo opt-out via `.madd-no-debug-code.disabled` |

### Auto-trigger skills (`~/.claude/skills/`)

| Skill | Trigger | Action |
|-------|---------|--------|
| `madd-ship-resume` | User opens project with `.madd-ship-state.json` and asks about current work | Runs `/madd-status`; offers resume |
| `madd-pre-pr-check` | User about to `gh pr create` / `glab mr create` / push feature branch | Runs `/madd-review` + `/madd-secure` on diff |
| `madd-post-learn` | After successful `gh pr merge` / `glab mr merge` | Prompts `/madd-learn --from-worklog` |

---

## Version history

### 2.0.1 (2026-06-11) — Token-efficiency pass

**Theme:** cut baseline runbook load on hot paths without changing behavior. Same artifacts, smarter file layout, smarter defaults.

**Shipped:**

- **`madd-ship` v3.2.0 — phase bodies extracted:**
  - 8 phase files at `commands/madd-ship-phases/phase-{1-spec, 2-schema, 3-tests-red, 4-impl, 5-green, 6-ci, 7-uat, 8-prod}.md`
  - Orchestrator drops 975 → 379 lines. Each phase 32-99 lines, `Read`-loaded only when entering that phase.
  - Worst case (full Standard ship): orchestrator + 5-8 phases ≈ 600 lines spread across calls. Cache-friendly.
  - Best case (Hotfix or resume from late phase): orchestrator + 1-2 phases ≈ 450 lines.
- **`madd-init` v2.5.0 — shape sub-runbooks:**
  - `commands/madd-init-shapes/{monorepo,workspace}.md` extracted from inline Step 1.6 / 1.7
  - SINGLE-repo path (most common) drops 811 → 681 lines; never loads sub-files.
  - MONOREPO / WORKSPACE paths read their respective sub-file on demand.
- **`madd-status` v1.1.0 — default terse:**
  - Box-drawing digest behind `--full`. Default = one-line `ship: <feat> phase=<N> | debug: ... | worklog: ...`.
  - Routine status checks drop ~80%.
- **`madd-recall` v1.1.0 — cache layer:**
  - `.madd-recall-cache.json` keyed on sha1(`KEYWORDS|LIMIT|MIN_CONF|SOURCE`). Default TTL 1h.
  - Phase 1 spec-iteration loops within an hour skip MCP + file pass entirely.
  - Cache sweeps entries > 7 days old on each write. Local-only; gitignored.
- **`install.sh` v2.1:**
  - Fetches `commands/madd-ship-phases/` (8 files) and `commands/madd-init-shapes/` (2 files) into matching dirs under `~/.claude/commands/`.
  - Backwards-compat: missing sub-files fail soft per-file rather than aborting.

**Estimated savings (real ships, RTK active):**
- Full Standard ship (8 phases): 50-150k → **30-90k tokens** (40% reduction baseline; better with cache hits on recall)
- `/madd-init` SINGLE: 20-40k → **14-28k** (25-30% reduction)
- `/madd-status` (per-check): 3-8k → **0.5-1.5k** (~80% reduction)
- `/madd-recall` cache hit (within TTL): 5-10k → **<1k**

**No behavior changes** — same gates, hooks, state writes. Files just live in different places.

### 2.0.0 (2026-06-11) — Control center: hooks, skills, state, recall

**Theme:** MADD becomes a complete `.claude/` control center — commands + hooks + skills + state — instead of commands-only. Closes 6 gaps surfaced in the v1.9 → v2.0 review.

**Shipped — new artifacts:**

- 3 PreToolUse hooks (`hooks/`):
  - `madd-phase-guard.sh` — reads `.madd-ship-state.json`; blocks `feat:` commits before RED, blocks push on red tests
  - `madd-commit-prefix.sh` — enforces `schema:/stub:/test(red):/feat:/refactor:/fix:/Rollback:` per `/madd-ship` Commit prefix discipline table
  - `madd-no-debug-code.sh` — rejects `console.log`/`print(`/`dbg!(`/`debugger;` in non-test source, with per-repo opt-out
- 3 auto-trigger skills (`skills/`, Anthropic SKILL.md format):
  - `madd-ship-resume` — surfaces existing ship on project open
  - `madd-pre-pr-check` — runs review + security before PR opens
  - `madd-post-learn` — prompts learn capture after merge
- 4 new slash commands (`commands/`):
  - `/madd-recall` — closes roadmap 1.10.0; reads agentmemory MCP smart_search + LEARNINGS.md fallback
  - `/madd-status` — one-screen digest of all MADD state
  - `/madd-checkpoint` — snapshot state + working tree before pivots
  - `/madd-rollback` — restore from checkpoint (distinct from prod revert)

**Shipped — runbook upgrades:**

- `madd-ship` v3.0 → v3.1:
  - Step 0i.5: file-tree work-type signal via `git diff --name-only` — augments keyword pass; tree wins on conflict
  - Step 0i.6: precedence merge table (keyword / tree / both / neither)
  - **Step 0j: state file resume protocol** — reads `.madd-ship-state.json`, offers resume/fresh/checkpoint; auto-flags `--resume` / `--fresh`
  - Phase 1a.pre: auto-invokes `/madd-recall` before drafting spec; surfaces matched learnings via `AskUserQuestion`
  - State writes at each phase boundary (1c, 2c, 3c, 4c, 5d, 6a, 6b, 7c, 8b) — hook-readable, resume-capable
  - Phase 8e: cycle cleanup (archive or delete state file post-ship)
- `madd-init` v2.3 → v2.4:
  - Step 8.5b: extended generated `settings.json` to register the 3 MADD hooks (`Bash` + `Edit|Write` matchers, dedupe-on-merge)
  - Step 8.5c: gitignores `.madd-ship-state.json`, `.madd-ship-state.backup-*.json`, `.madd-pending-sync`, `.madd-learn-captured-*`, `.madd-ship-archive/`, `.madd-debug.md`, `MADD-CHECKPOINTS.md`
  - Step 9 summary lists the registered hooks
- `install.sh` v1 → v2:
  - Extended from 4 commands to 16 (covers `madd-debug`/`madd-review`/`madd-secure`/`madd-vibe`/`madd-design`/`madd-devops`/`madd-data`/`madd-robot` previously missing)
  - Now installs `hooks/` to `~/.claude/hooks/` with `chmod +x`
  - Now installs `skills/` to `~/.claude/skills/`
  - Per-artifact skip + count summary

**Gap analysis (closed by 2.0):**

| # | v1.9 gap | v2.0 resolution |
|---|----------|----------------|
| 1 | Phase gates `AskUserQuestion`-only — bypassable | `madd-phase-guard.sh` + state file enforce gates at tool layer |
| 2 | `/madd-learn` writes; nothing reads | `/madd-recall` + Phase 1a.pre close the loop |
| 3 | No mid-ship resume | `.madd-ship-state.json` + Step 0j + `/madd-status` / `/madd-checkpoint` / `/madd-rollback` |
| 4 | Work-type routing keyword-only | Step 0i.5 file-tree signal + 0i.6 precedence |
| 5 | No `skills/` dir | 3 auto-trigger skills ship in `skills/` |
| 6 | `install.sh` shipped 4 of 11 commands | Now ships 16 + 3 hooks + 3 skills |

**Verification:**

Hooks unit-tested with smoke fixtures (state-driven block on `feat:` pre-RED, push pre-green; commit-prefix opt-in gate; no-debug-code basename + extension rules). End-to-end on a fresh repo + dogfood on `/Users/sproutoffice/apps/personal/misua-id` pending v2.0.1.

### 1.9.0 (2026-06-02) — Branch hygiene + platform-aware PR/MR

**`madd-ship` v2.2.0:**
- New **Step 0h** — branch hygiene before Phase 1:
  - Detect base branch (priority: `--base` arg → AGENTS.md `BASE_BRANCH` → `origin/HEAD` → `main` → `master` → ask)
  - Stash-or-commit gate if working tree dirty
  - `git fetch + checkout BASE + pull --ff-only` to sync latest
  - Derive feature branch name from feature description (slugify + prefix from convention)
  - `git checkout -b $FEATURE_BRANCH` from latest base
- New flags: `--base <branch>` (override default), `--no-new-branch` (skip Step 0h if already on feature branch)
- **Phase 6 platform detection** — classify remote URL: GITHUB / GITLAB / BITBUCKET / other
- **Phase 6 PR/MR creation:**
  - GitHub → `gh pr create --draft --base $BASE --head $FEATURE_BRANCH`
  - GitLab (including self-hosted) → `glab mr create --draft --target-branch $BASE --source-branch $FEATURE_BRANCH`
  - Bitbucket / other → print URL pattern for manual creation
- **Phase 8 merge** — platform-dispatched: `gh pr merge` / `glab mr merge` / web UI; then `git checkout $BASE && git pull` to sync local

**New global hook:** `git-branch-guard.sh` (replaces bouchon-specific):
- Agnostic — uses CWD-based git detection
- Config priority: `$PWD/.git-branch-guard.json` → `$REPO_ROOT/.git-branch-guard.json` → `~/.config/git-branch-guard.json` → built-in
- Defaults: protected `main`/`master`/`develop`; allowed prefixes `feat/`/`fix/`/`hotfix/`/`release/`/`chore/`/`docs/`/`refactor/`/`test/`/`ci/`
- Bouchon protected branches (kejaksaan, v2-imini, zelda-dev) preserved via repo-local override
- Old `bouchon-branch-guard.sh` kept as backup; settings.json updated

### 1.8.0 (2026-06-01) — Workspace + monorepo support

**Shape detection added:**
- New Step 1.5 in `madd-init` classifies repo shape:
  - `SINGLE` — one git repo, no workspace marker → current flow
  - `MONOREPO` — one git repo + workspace marker (pnpm-workspace / turbo / nx / lerna / go.work / Cargo `[workspace]` / package.json `workspaces`)
  - `WORKSPACE` — parent dir not a repo, ≥2 sibling repos with own `.git`
  - `LOOSE` — folder with nothing → suggest `/madd-vibe`
  - `INSIDE` — CWD nested in larger repo → warn + ask

**Monorepo flow:**
- 3 strategies: `root only` / `per-package` / `hybrid` (root shared + per-pkg overrides)
- Member enumeration parses each workspace marker (pnpm yaml, package.json workspaces, go.work `use` directives, Cargo `members`, lerna packages, glob expansion via `find`)
- Per-package AGENTS.md inherits from root via `## Inherits from ../AGENTS.md`
- Root-only mode: minimal index AGENTS.md with member table

**Workspace flow:**
- Lists sibling repos, shows AGENTS.md presence per-repo
- 4 strategies: per-repo pick / all-repos auto / WORKSPACE.md index only / cancel
- Per-repo loop runs full single-repo flow inside each
- Writes parent-level `WORKSPACE.md` index (markdown table of repos + stacks)

**`/madd-ship` v2.1.0 monorepo/workspace awareness:**
- `--member <name>` flag for explicit scoping
- Phase 0b: workspace parent guard — refuses to run at WORKSPACE.md root
- Phase 0c: scope resolution — detects monorepo member from `## Inherits from`, or asks if at root without --member
- Phase 0e: inheritance merge — root fields loaded first, member fields overlay
- All downstream phases unchanged (use merged STACK as before)

### 1.7.0 (2026-06-01) — Dogfood pass + new skills

**Shipped:**
- 3 new skills: `madd-debug`, `madd-review`, `madd-secure` (cover GSD overlap removal)
- 1 new mode: `madd-vibe` for prototype/throwaway projects with graduation path
- Removed 17 overlapping GSD skills (backed up to `~/.claude/.gsd-removed-backup-<ts>/`)
- Dogfood test of `/madd-init existing` on misua-id surfaced 8 friction points → patched in `madd-init` v2.1.0

**`madd-init` v2.1.0 patches (from dogfood):**
- Step 2: split file existence check per-file (avoid `ls` exit 1 chain break)
- Step 3: explicit "parallel separate calls, NOT chained `&&`" instruction
- Step 3: `find` instead of shell glob (zsh `no matches found` not suppressed by `2>/dev/null`)
- Step 3: added `wrangler.json` / `wrangler.jsonc` to deployment detection (Cloudflare moved from `.toml`)
- Step 4b: explicit merge-mode gap detection sub-step
  - Stale skill reference scan (`/ship` → `/madd-ship` auto-rename)
  - Redundant inline workflow detection (Phase 1-8 sections → auto-strip)
  - Missing-field gap detection (only ask about gaps, not all)
- Step 5: tier-2 tool check via `pnpm ls` for dev-deps not in global PATH

**`misua-id` dogfood artifacts:**
- AGENTS.md regenerated (138 → 122 lines, conventions added, workflow stripped)
- WORKLOG.md created
- Backup: `AGENTS.md.bak.20260601-151659` (138-line original preserved)

### 1.6.0 (2026-06-01) — Updater + install deletion

**Shipped:**
- Deleted `madd-install` (circular, no-op)
- New `madd-update` v1.0.0 — real fetcher (git / curl / local path)
  - Source resolution priority: `--source` arg → `MADD_SOURCE` env → `~/.claude/MADD.config` → AskUserQuestion
  - `--check` mode: diff-only, no writes
  - `--force` mode: skip confirmation (script-safe)
  - Backups to `~/.claude/commands/.backup/<skill>.bak.<timestamp>` before overwrite
  - Semver-aware: classifies as NEW / UPGRADE / SAME / DOWNGRADE / REMOTE_MISSING
  - Per-skill selective apply via AskUserQuestion
  - Step 7: optional project-copy sync
  - Shows changelog snippets after upgrade
  - Never silent overwrite; never stale fallback

### 1.5.0 (2026-06-01) — `madd-learn` runbook rewrite

**Shipped:**
- `madd-learn` v2.0.0 — full runbook (272 lines)
  - Correct MCP tool names: `mcp__agentmemory__memory_lesson_save` (primary), `mcp__agentmemory__memory_save` (fallback)
  - Real availability detection via tool-not-found cascade
  - Real `--from-worklog` parser: `awk` to extract last entry block
  - `AskUserQuestion` interactive mode for worked/failed/confidence/tags
  - Schema validation before MCP send (length, type, tag-shape)
  - Confidence mapping: 1-5 → 0.2-1.0 for MCP payload
  - File fallback path writes to `LEARNINGS.md` via real `Edit`
  - Pending-sync marker (`.madd-pending-sync`) for retry later
  - Never silently drop a learning — prints raw payload if all paths fail

### 1.4.0 (2026-06-01) — `madd-ship` runbook rewrite

**Shipped:**
- `madd-ship` v2.0.0 — full runbook rewrite (515 lines)
  - Step 0 pre-flight: real `Read` of AGENTS.md, parse facts into working memory
  - Step 0d: detect package manager drift via Bash + jq
  - Step 0e: `SHIP_MODE` selector (Standard / Quickfix / Hotfix) via AskUserQuestion
  - Phase 1 gating: 3 AskUserQuestion calls (conventions batch + final approval gate)
  - Phase 3: pre-stub step for typed langs (TS/Go/Rust) — fixes "RED for right reason" impossibility
  - Phase 4 WORKLOG.md: real `Edit` tool call, not reminder text
  - Phase 6: real `gh pr create --draft` with acceptance criteria heredoc
  - Phase 8 rollback: validates commit hash via `git cat-file -e <hash>^{commit}` before reverting
  - Agent handoff: substitutes **real values** (no `<placeholder>` syntax in final prompt); uses `Agent` tool
  - Removed misua-specific "conversational surface" bleed from Phase 4

**Known debt remaining:**
- `madd-learn` MCP tool name still wrong (`mcp__agentmemory__memory_lesson_save`)
- `madd-install` still circular
- No real end-to-end test on a fresh project yet

**Next:** `madd-learn` v2.0.0 with correct MCP tool + availability detection.

### 1.3.0 (2026-06-01) — Reference implementation milestone

**Roast findings addressed:**
- `madd-init` v2.0.0 — Rewritten as operational runbook (real Bash detection, real AskUserQuestion calls, real Write). Pattern for future rewrites.
- `madd-install` flagged as deprecated (circular — can't install itself)
- Roadmap honesty pass — removed false "planned" claims that didn't ship

**Known debt:**
- `madd-ship` still aspirational; Phase 1 checklist not real gating; agent handoff still has `<placeholders>`
- `madd-learn` MCP tool name wrong (`memory_lesson_save` → should be `mcp__agentmemory__memory_lesson_save`); no availability detection
- 8 phases overkill for typos/hotfixes — need `/madd-quickfix` lane
- Phase 4 "conversational surface" is misua-specific bleed
- Phase 3 RED-first impossible for typed langs without stubs
- Overlap with GSD ecosystem not reconciled

**Next priority:** Rewrite `madd-ship` v2.0.0 as runbook; fix `madd-learn` MCP tool name.

### 1.2.0 (2026-06-01)

**New features:**
- `madd-learn` skill — capture learnings after `/madd-ship` (MCP primary, file fallback)
- Phase 8 integration — suggests learning capture after production deploy
- Learnings storage: what worked, what failed, decisions made, confidence scoring, tags

**Skills updated:**
- `madd-ship` v1.1.0 → v1.2.0 (adds madd-learn integration)

### 1.1.0 (2026-06-01)

**New features:**
- `madd-init` now auto-scaffolds AGENTS.md (questionnaire mode)
- `madd-ship` Phase 0 validates AGENTS.md + stack tools
- `madd-ship` auto-appends WORKLOG.md per feature
- `madd-ship` auto-populates agent handoff from AGENTS.md
- Version tracking in skill frontmatter (YAML)
- Package manager auto-detection (package.json → lockfiles → npm)

**Improvements:**
- Explicit Phase 1 conventions checklist (user ticks before Phase 2)
- Rollback step validates git commit hash exists
- Better error messages + recovery suggestions
- Project-scoped installation option (`/madd-install --project`)

**Fixes:**
- Agent handoff block now includes AGENTS.md context
- WORKLOG.md template created automatically
- Stack tool validation (e.g., node, python, go)

### 1.0.0 (initial)

**Features:**
- 8-phase workflow: Spec → Schema → Tests Red → Impl → Green → Refactor → CI → UAT → Prod
- AGENTS.md template (manual fill-in)
- `/madd-init` (template only)
- `/madd-ship` (guided feature delivery)
- Commit discipline (schema/test/feat/refactor/fix)
- Agent delegation rules

---

## Upgrade path

**Any version → latest:**

```bash
/madd-update --check    # See what would change
/madd-update            # Apply with backups + diff preview
```

Backups land in `~/.claude/commands/.backup/` per skill, timestamped. Restore any time:

```bash
cp ~/.claude/commands/.backup/madd-ship.md.bak.<timestamp> ~/.claude/commands/madd-ship.md
```

**Breaking changes:** Documented in version history above. AGENTS.md / WORKLOG.md / LEARNINGS.md formats are append-only — no migration needed.

---

## Roadmap (real, not aspirational)

**Shipped (1.8.0 – 2.0.0):**
- ✓ 1.8.0 — Source publishing + install.sh (1.6.0 actually; renumbered)
- ✓ 1.9.0 — Branch hygiene + platform-aware PR/MR
- ✓ 1.10.0 — `/madd-recall` shipped in 2.0.0
- ✓ 2.0.0 — Control center: hooks, skills, state, recall (this release)

**2.0.1 — Dogfood pass:**
- End-to-end `/madd-init` + `/madd-ship` + `/madd-learn` + `/madd-recall` round-trip on a fresh repo
- Re-run on misua-id (existing dogfood project) → patch surfaced friction
- Verify all 3 hooks fire in real session (not just unit smoke)
- Verify all 3 auto-trigger skills surface at correct moments

**2.1.0 — Replace phase gates with hooks (where safe):**
- Convert `AskUserQuestion` gates that have hook-checkable conditions into PostToolUse hooks
- Keep `AskUserQuestion` for genuinely-human gates (spec approval, work-type ambiguity)
- Add Windows PowerShell hook variants alongside the POSIX scripts

**2.2.0 — Phase 2 GSD removal (milestone-level):**
- Audit remaining 25 GSD skills (milestone management group)
- Remove unused; keep gsd-debug? gsd-code-review? evaluate vs madd-debug / madd-review

**3.0.0 — Cross-session aggregation:**
- `/madd-status --workspace` aggregates across all worktrees + members
- Shared team checkpoints (opt-in, requires shared MCP)
- Auto-merge `MADD-CHECKPOINTS.md` from peers

---

## Installation

### First-time bootstrap (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/sinholic/madd/main/install.sh | bash
```

What it does:
1. Creates `~/.claude/commands/` if missing
2. Downloads `madd-init.md`, `madd-ship.md`, `madd-learn.md`, `madd-update.md`
3. Writes `~/.claude/MADD.config` with default `MADD_SOURCE=https://github.com/sinholic/madd.git`
4. Prints next steps

After bootstrap, restart Claude Code so the new skills are surfaced.

### Update existing install

```bash
/madd-update            # Fetch latest from configured source, diff, confirm, apply
/madd-update --check    # Show drift only; no changes
/madd-update --force    # Apply all without prompts (CI / script use)
```

### Project-pin (override global per-project)

```bash
# Inside a project repo
mkdir -p .claude/commands
cp ~/.claude/commands/madd-*.md .claude/commands/

# Or via /madd-update step 7, which offers to sync project copies
```

### Manual install (no curl)

```bash
git clone https://github.com/sinholic/madd.git ~/madd-src
cp ~/madd-src/commands/madd-*.md ~/.claude/commands/
```

---

## Documentation

- **AGENTS.md** — Auto-created per project; documents stack, commands, conventions
- **WORKLOG.md** — Decision log; auto-appended per feature
- **Per-skill docs:** Built into skill frontmatter (description, changelog, usage)

---

## Feedback / Issues

Report gaps or improvements:
1. Document in WORKLOG.md under `MADD Improvement`
2. Tag as `@madd` in comments
3. Next version cycle will address

Example:
```markdown
## MADD Improvement — 2026-06-15
- Feature: auto-detect linting framework (eslint/biome)
- Why: Phase 6 assumes lint exists; should warn if not
```

---

## License / Origin

Developed for **misua.id** (Misua Portfolio Project) to enforce SDD+TDD discipline across AI-driven feature delivery.

Designed to be:
- **Stack-agnostic** — works with any language/framework
- **Agnostic** — references project conventions from AGENTS.md, not hardcoded
- **Version-controlled** — track updates per skill
- **Extensible** — new phases/checks can be added in future versions
