# Step 1.6 — Monorepo flow (sub-runbook)

You entered this sub-file from `madd-init.md` Step 1.5c because SHAPE = MONOREPO. Workspace marker + members enumeration follows.

## 1.6a. Enumerate members

Parse the workspace marker to list members.

**pnpm-workspace.yaml:**
```bash
cat pnpm-workspace.yaml | grep -E "^\s*-" | sed 's/[- "'\'']//g'
```

**package.json `workspaces`:**
```bash
jq -r '.workspaces[]? // .workspaces.packages[]?' package.json 2>/dev/null
```

**turbo.json / nx.json:** rely on `package.json workspaces` — fall through.

**lerna.json:**
```bash
jq -r '.packages[]?' lerna.json 2>/dev/null
```

**go.work:**
```bash
grep -E '^\s*use\s+' go.work | sed 's/use\s*//; s/[()]//g' | tr -s ' ' '\n' | grep -v '^$'
```

**Cargo.toml [workspace]:**
```bash
sed -n '/^\[workspace\]/,/^\[/p' Cargo.toml | grep -E '^\s*members\s*=' | tr -d '[]"' | sed 's/.*=//' | tr ',' '\n'
```

Expand globs via `find` (e.g. `packages/*`):
```bash
find packages -maxdepth 1 -mindepth 1 -type d 2>/dev/null
find apps -maxdepth 1 -mindepth 1 -type d 2>/dev/null
```

Build `MEMBERS` array. Print to user.

## 1.6b. Choose AGENTS.md strategy

`AskUserQuestion`:
- question: "Monorepo with N members. AGENTS.md strategy?"
- header: "Mono strategy"
- options:
  - "Root only" — single AGENTS.md at root; per-package details inline
  - "Per-package" — AGENTS.md per member; root has index only
  - "Hybrid" — root for shared (stack, conventions); per-package for overrides

Store as `MONO_STRATEGY`.

## 1.6c. Member selection (per-package / hybrid)

If `--all-members` in args: select all.
Else `AskUserQuestion`:
- question: "Which members to init AGENTS.md?"
- header: "Members"
- options: each detected member (max 4 per question, batch if needed)
- multiSelect: true

Store as `SELECTED_MEMBERS`.

## 1.6d. Loop Steps 2-9 per scope

Return to `madd-init.md` Steps 2-9 with these overrides:

For `MONO_STRATEGY = root only`:
- Run Steps 2-9 once at root
- AGENTS.md gets "Members" section listing each

For `MONO_STRATEGY = per-package`:
- For each selected member: cd in, run Steps 2-9, write `<member>/AGENTS.md`
- Write minimal `<root>/AGENTS.md` index per Step 7b template

For `MONO_STRATEGY = hybrid`:
- Run Steps 2-9 at root (shared stack/conventions) → root `AGENTS.md`
- For each selected member: run reduced Steps (only ask overrides) → `<member>/AGENTS.md` with `## Inherits from ../AGENTS.md` per Step 7c template

Return to orchestrator → continue at Step 2.
