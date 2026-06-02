# MADD — Misua AI Development Driven

Framework for SDD+TDD end-to-end feature delivery.

---

## Current version: 1.8.0

Released: 2026-06-01

---

## Skills

| Skill | Version | Status | Purpose |
|-------|---------|--------|---------|
| `madd-init` | 2.2.0 | Active runbook | Detection + scaffold; workspace shape classification (single/mono/multi-repo), monorepo per-pkg + hybrid modes, WORKSPACE.md index |
| `madd-ship` | 2.1.0 | Active runbook | 8-phase delivery; --member flag, root+member AGENTS.md inheritance merge, workspace parent guard |
| `madd-learn` | 2.0.0 | Active runbook | Post-ship capture; correct MCP names, availability cascade, file fallback |
| `madd-debug` | 1.0.0 | Active runbook | Systematic debug; scientific method, persistent `.madd-debug.md` state |
| `madd-review` | 1.0.0 | Active runbook | Source review; severity-classified REVIEW.md, optional auto-fix |
| `madd-secure` | 1.0.0 | Active runbook | Security audit; secrets, dep CVEs, auth/authz, SECURITY.md |
| `madd-vibe` | 1.0.0 | Active runbook | Prototype scaffold; skip discipline, graduate to /madd-ship later |
| `madd-update` | 1.0.0 | Active runbook | Fetcher; git/curl/local source, diff preview, backup before overwrite |
| ~~`madd-install`~~ | — | Removed | Circular; replaced by `/madd-update` |

---

## Version history

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

**1.8.0 — Source publishing:**
- Push `madd-public` to github.com/sinholic/madd
- Verify `install.sh` works end-to-end on a fresh machine
- Set `MADD_SOURCE` default in `~/.claude/MADD.config`
- `/madd-update --check` workflow live

**1.9.0 — Full ship dogfood:**
- Run `/madd-ship <real-feature>` on misua-id end-to-end
- Run `/madd-learn` and verify MCP write to `agentmemory`
- Patch surfaced friction → v2.x for affected skills

**1.10.0 — `/madd-recall` skill:**
- Query stored learnings during `/madd-ship` Phase 1
- Surface relevant prior gotchas before spec is finalized
- MCP `memory_smart_search` + LEARNINGS.md grep fallback

**2.0.0 — Phase 2 GSD removal (milestone-level):**
- Audit remaining 25 GSD skills (milestone management group)
- Remove unused; keep gsd-debug? gsd-code-review? evaluate vs madd-debug / madd-review

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
