# MADD — Misua AI Development Driven

End-to-end feature delivery for Claude Code. SDD + TDD in 8 phases. Stack-agnostic. Real tool calls, not docs.

Ships as a complete `.claude/` control center: commands, hooks (phase discipline + commit prefix + no-debug-code), and auto-trigger skills.

```
Spec → Schema → Tests Red → Impl → Green → Refactor → CI → UAT → Production
```

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sinholic/madd/main/install.sh | bash
```

Pin to a release tag instead of `main`:

```bash
MADD_REF=v3.2.1 curl -fsSL https://raw.githubusercontent.com/sinholic/madd/main/install.sh | bash
```

Restart Claude Code. Then in any project:

```bash
/madd-init                       # Scaffold AGENTS.md + WORKLOG.md
/madd-ship <feature description> # Drive 8-phase delivery
/madd-learn <feature-name>       # Capture learnings post-ship
```

Update later:

```bash
/madd-update           # Diff preview + confirm
/madd-update --check   # Drift check only
```

---

## Why MADD

- **Real runbooks, not docs** — every step names the Claude Code tool to invoke (Bash, AskUserQuestion, Write, Edit, Agent).
- **AGENTS.md per project** — single source of truth for stack, commands, conventions. Skills read it, never hardcode.
- **Real gating** — Phase 1 spec gate uses `AskUserQuestion`, not markdown checkboxes that fake enforcement.
- **WORKLOG.md auto-append** — Phase 4 writes decision log via real `Edit` call.
- **Agent handoff** — auto-populated with real values from AGENTS.md, no `<placeholder>` syntax.
- **Learning capture** — Post-ship `/madd-learn` writes to agent-memory MCP (with file fallback).
- **Quickfix / Hotfix lanes** — 8 phases for features, skip-paths for trivial changes.
- **Rollback validated** — Phase 8 verifies commit hash exists before `git revert`.

---

## Skills

### Slash commands

| Command | Purpose |
|---------|---------|
| `/madd-init` | Detect stack, scaffold `AGENTS.md` + `WORKLOG.md` + `.claude/settings.json` (with MADD hooks registered), gitignore state files |
| `/madd-ship <feature>` | 8-phase delivery; persistent `.madd-ship-state.json` for resume + hook enforcement; auto-recalls prior learnings; file-tree work-type routing |
| `/madd-learn <feature>` | Capture learnings → agent memory MCP + LEARNINGS.md fallback |
| `/madd-recall <keywords>` | **NEW** — read prior learnings before drafting a spec |
| `/madd-status` | **NEW** — one-screen digest of ship/debug/learn state |
| `/madd-checkpoint` | **NEW** — snapshot state file + working tree before pivots |
| `/madd-rollback` | **NEW** — restore from checkpoint (distinct from prod revert) |
| `/madd-debug`, `/madd-review`, `/madd-secure`, `/madd-vibe`, `/madd-design`, `/madd-devops`, `/madd-data`, `/madd-robot` | Specialized flows |
| `/madd-update` | Fetch latest from configured source, diff, backup, apply |

### Hooks (`~/.claude/hooks/`)

- `madd-phase-guard.sh` — blocks `feat:` commits before Phase 3 RED gate; blocks push before Phase 6 green
- `madd-commit-prefix.sh` — enforces `schema:/stub:/test(red):/feat:/refactor:/fix:/Rollback:`
- `madd-no-debug-code.sh` — rejects `console.log`/`print(`/`dbg!(`/`debugger;` in non-test source. CLI entrypoints exempt (Go `cmd/**`+`main.go`, Ruby `bin/**`+`exe/**`); per-repo glob allowlist via `.madd-no-debug-code.allow`

### Auto-trigger skills (`~/.claude/skills/`)

- `madd-ship-resume` — surfaces existing ship on project open
- `madd-pre-pr-check` — runs review + security before PR opens
- `madd-post-learn` — prompts learn capture after merge

---

## Project files MADD touches

| File | Created by | Purpose |
|------|-----------|---------|
| `AGENTS.md` | `/madd-init` | Stack, key commands, directory layout, conventions, delegation rules |
| `WORKLOG.md` | `/madd-init` (template), `/madd-ship` (appends) | Decision log per feature |
| `LEARNINGS.md` | `/madd-learn` (fallback only) | Captured learnings when MCP unavailable |

---

## Requirements

- [Claude Code](https://claude.ai/code)
- `git`, `curl`, `bash`
- `node` — **required for hooks** (phase-guard, commit-prefix, no-debug-code parse tool input with Node.js; without it they silently no-op)
- `jq` (recommended for stack detection)
- Optional: `agentmemory` MCP server for learning storage

---

## Customizing

### Override source for `/madd-update`

```bash
# Per-shell
export MADD_SOURCE=https://github.com/your-fork/madd.git

# Or persistent
echo 'MADD_SOURCE=https://github.com/your-fork/madd.git' > ~/.claude/MADD.config
```

### Project-pin (override global per project)

```bash
# In project root
mkdir -p .claude/commands
cp ~/.claude/commands/madd-*.md .claude/commands/
```

Project copies override global. `/madd-update --project` also offered during normal updates.

---

## Example AGENTS.md files

See [`examples/`](./examples/):

- [`astro-cloudflare.md`](./examples/astro-cloudflare.md) — Astro 5 SSR on Cloudflare Workers
- [`next-vercel.md`](./examples/next-vercel.md) — Next.js on Vercel
- [`django-fly.md`](./examples/django-fly.md) — Django on Fly.io
- [`go-docker.md`](./examples/go-docker.md) — Go service in Docker

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/sinholic/madd/main/uninstall.sh | bash
```

Removes all 16 commands, hooks, skills, and sub-runbooks. Keeps `MADD.config` and backups (`~/.claude/{commands,hooks,skills}/.backup/`) — pass `--purge` to remove those too. Per-project files (`AGENTS.md`, `WORKLOG.md`, hook entries in `.claude/settings.json`) are left alone.

---

## License

MIT. See [`LICENSE`](./LICENSE).

---

## Status

Active. See [`MADD.md`](./MADD.md) for version history, roadmap, and design notes.
