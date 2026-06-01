---
description: "Update MADD skills (madd-init, madd-ship, madd-learn) to latest versions from configured source. Shows diff before applying. Real git/curl fetch."
argument-hint: "[--source <url-or-path>] [--check] [--force]"
version: "1.0.0"
changelog: |
  1.0.0 — Initial runbook: real fetch (git or curl), diff preview, backup before overwrite
---

# Runbook: Update MADD skills

Replace `~/.claude/commands/madd-*.md` with latest versions from source. Diff-first, backup-first, never silent overwrite.

Argument: **$ARGUMENTS**

---

## Step 1 — Resolve source

Sources in priority order:

1. `--source <value>` from $ARGUMENTS (git URL or local path)
2. `MADD_SOURCE` env var via `Bash`: `echo $MADD_SOURCE`
3. `~/.claude/MADD.config` file (read first line as source)
4. `AskUserQuestion` user for source

Accepted source forms:
- Git URL: `https://github.com/<user>/madd.git` (with optional `#<ref>`)
- Local path: `/abs/path/to/madd-skills/` (must contain `madd-*.md`)
- GitHub raw base: `https://raw.githubusercontent.com/<user>/madd/main/commands/`

Store as `SOURCE`.

If source not configured, after user provides one: offer to persist via `Write` to `~/.claude/MADD.config`.

---

## Step 2 — Fetch latest

### 2a. Create temp workspace

`Bash`:
```bash
TMP=$(mktemp -d -t madd-update-XXXXXX) && echo "$TMP"
```

Store as `TMP`.

### 2b. Pull source

If `SOURCE` is git URL:
```bash
git clone --depth=1 "$SOURCE" "$TMP/source" 2>&1 | tail -5
```

If `SOURCE` is local path:
```bash
cp -R "$SOURCE/." "$TMP/source/"
```

If `SOURCE` is raw HTTPS base:
```bash
mkdir -p "$TMP/source"
for skill in madd-init.md madd-ship.md madd-learn.md madd-update.md; do
  curl -fsSL "$SOURCE$skill" -o "$TMP/source/$skill" || echo "MISS: $skill"
done
```

### 2c. Verify fetch

`Bash`:
```bash
ls -la "$TMP/source/" | grep -E 'madd-.*\.md'
```

If no `madd-*.md` files → abort, report source bad.

---

## Step 3 — Compare versions

### 3a. Extract versions

`Bash` (loop for each skill):
```bash
for f in madd-init madd-ship madd-learn madd-update; do
  local_v=$(grep '^version:' ~/.claude/commands/$f.md 2>/dev/null | head -1 | sed 's/version: //; s/"//g')
  remote_v=$(grep '^version:' "$TMP/source/$f.md" 2>/dev/null | head -1 | sed 's/version: //; s/"//g')
  echo "$f: local=$local_v remote=$remote_v"
done
```

### 3b. Build update plan

For each skill, classify:
- `NEW` — remote exists, local missing
- `UPGRADE` — remote version > local version (semver compare)
- `SAME` — equal
- `DOWNGRADE` — remote < local (warn, ask before applying)
- `REMOTE_MISSING` — local exists, remote not in source (leave alone)

If `--check` in $ARGUMENTS: print plan + exit. No writes.

---

## Step 4 — Show diff (per skill being changed)

For each `NEW` / `UPGRADE` / `DOWNGRADE`:

`Bash`:
```bash
diff -u ~/.claude/commands/$f.md "$TMP/source/$f.md" | head -80
```

Show truncated diff to user. After all diffs:

`AskUserQuestion`:
- question: "Apply update plan?"
- header: "Apply"
- options:
  - "Apply all"
  - "Apply selectively" — ask per-skill below
  - "Cancel — no changes"

If `--force` in args: skip this question, apply all.

If "selectively": `AskUserQuestion` once per changed skill (batch up to 4).

---

## Step 5 — Backup + write

For each skill to update:

### 5a. Backup local

`Bash`:
```bash
TS=$(date -u +%Y%m%d-%H%M%S)
mkdir -p ~/.claude/commands/.backup
test -f ~/.claude/commands/$f.md && cp ~/.claude/commands/$f.md ~/.claude/commands/.backup/$f.md.bak.$TS
```

### 5b. Overwrite

Use `Read` on the source file, then `Write` to `~/.claude/commands/$f.md`.

(Do not use `cp` for the actual write — keep changes visible through the tool layer.)

---

## Step 6 — Clean up + report

### 6a. Remove temp

`Bash`:
```bash
rm -rf "$TMP"
```

### 6b. Summary

Print:
```
✓ MADD updated

Updated:
  - madd-init:  1.0.0 → 2.0.0
  - madd-ship:  1.2.0 → 2.0.0
  - madd-learn: 1.0.0 → 2.0.0

Unchanged:
  - madd-update: 1.0.0 (same)

Backups: ~/.claude/commands/.backup/*.bak.20260601-103045

Restore command:
  cp ~/.claude/commands/.backup/madd-init.md.bak.20260601-103045 ~/.claude/commands/madd-init.md
```

### 6c. Show changelog snippets

For each upgraded skill, extract its `changelog:` block from frontmatter and print. Helps user understand what changed.

---

## Step 7 — Optional: sync to project

If invoked inside a project that already has `.claude/commands/madd-*.md` (project-pinned copy):

`AskUserQuestion`:
- question: "Project has pinned MADD copies. Update those too?"
- header: "Project sync"
- options:
  - "Yes — sync project copies"
  - "No — leave project versions pinned"

If yes: repeat Step 5 for `<repo-root>/.claude/commands/madd-*.md`.

---

## Failure modes

| Symptom | Cause | Recovery |
|---------|-------|----------|
| `git clone` 404 | Bad source URL | Re-prompt; check `MADD_SOURCE` env var |
| `curl` 404 per skill | Wrong raw base | Verify path includes `commands/` subdir |
| `grep version` empty | Malformed source skill | Skip that skill; warn user |
| Semver compare ambiguous | Non-semver versions | Default to "upgrade" if strings differ; ask user |
| `Write` perm denied | `~/.claude/commands/` read-only | Report; suggest fix `chmod -R u+w ~/.claude/commands/` |
| Backup dir full | Disk space | `rm` old backups: `find ~/.claude/commands/.backup -mtime +30 -delete` |

---

## Caveats

- This skill **never** silently overwrites. Backup → diff → confirm → write.
- `--check` is non-destructive — safe to run anytime to see drift.
- `--force` skips confirmation — use in scripts only.
- Backups never auto-deleted. User responsibility to prune `.backup/`.
- If source is unreachable, this skill stops cleanly. It does **not** fall back to a stale embedded copy.
