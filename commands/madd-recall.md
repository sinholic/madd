---
description: "Recall prior MADD learnings before drafting a spec. Cache → agentmemory MCP smart search → LEARNINGS.md grep fallback. Surfaces prior gotchas, decisions, and confidence for the topic."
argument-hint: "<feature-keywords> [--limit N] [--min-confidence 0.0-1.0] [--source mcp|file|both] [--no-cache] [--cache-ttl <seconds>]"
version: "1.1.0"
changelog: |
  1.1.0 — Cache layer (.madd-recall-cache.json with 1h TTL). Repeat queries within TTL skip MCP/file pass. /madd-ship Phase 1 spec iteration loops now near-free for recall.
  1.0.0 — Initial runbook. Closes MADD.md roadmap 1.10.0 (`/madd-recall` skill).
---

# Runbook: Recall MADD learnings

You are executing `/madd-recall`. Argument: **$ARGUMENTS**

Goal: surface prior `/madd-learn` entries relevant to the current task so the user can apply known gotchas before re-discovering them.

Sister skill: `/madd-learn` (write side). This is the read side.

---

## Step 1 — Parse arguments

Parse `$ARGUMENTS`:
- First positional → `KEYWORDS` (required; multi-word allowed, joined by space)
- `--limit <N>` → `LIMIT` (default 5; clamp 1-20)
- `--min-confidence <0.0-1.0>` → `MIN_CONF` (default 0.4 = confidence 2/5)
- `--source <mcp|file|both>` → `SOURCE` (default `both`)
- `--no-cache` → skip cache layer (Step 2.5); force fresh query
- `--cache-ttl <seconds>` → `TTL` (default 3600 = 1h; set to 0 to disable cache reads but still write)

If `KEYWORDS` empty:

`AskUserQuestion`:
- question: "What topic to recall? (feature name, framework, error pattern, etc.)"
- header: "Recall"
- options: "Other — type query"

Store as `KEYWORDS`.

---

## Step 2 — Locate repo root

`Bash`:
```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
basename "$PWD"
```

Capture: `REPO_ROOT`, `PROJECT_NAME`.

Repo root is best-effort context; recall is global across projects.

---

## Step 2.5 — Cache layer

Cache file: `<REPO_ROOT>/.madd-recall-cache.json` (gitignored by `/madd-init` ≥ v2.5.0; add manually if older).

### 2.5a. Compute cache key

```bash
KEY=$(printf '%s|%s|%s|%s' "$KEYWORDS" "$LIMIT" "$MIN_CONF" "$SOURCE" | shasum -a 1 | cut -d' ' -f1)
```

### 2.5b. Try cache read (skip if `--no-cache`)

```bash
test -f .madd-recall-cache.json && node -e "
const fs = require('fs');
const cache = JSON.parse(fs.readFileSync('.madd-recall-cache.json', 'utf8'));
const entry = cache['$KEY'];
const now = Date.now();
if (!entry) { process.exit(1); }
if ((now - entry.cached_at) > ($TTL * 1000)) { process.exit(1); }
console.log(JSON.stringify(entry.payload));
" 2>/dev/null
```

If cache hit and exit 0 → use cached payload, skip to Step 5 (format digest). Note source as `cache` in output. Add cache-age hint: `(cached <H>m ago)`.

If cache miss or stale → proceed to Step 3.

### 2.5c. Cache write hook

After Step 3/4 produces results (before Step 5 formats), persist:

```bash
node -e "
const fs = require('fs');
const path = '.madd-recall-cache.json';
let cache = {};
try { cache = JSON.parse(fs.readFileSync(path, 'utf8')); } catch {}
cache['$KEY'] = {
  cached_at: Date.now(),
  keywords: '$KEYWORDS',
  payload: $PAYLOAD_JSON
};
// Sweep entries older than 7 days
const week = 7 * 24 * 3600 * 1000;
for (const k of Object.keys(cache)) {
  if ((Date.now() - cache[k].cached_at) > week) delete cache[k];
}
fs.writeFileSync(path, JSON.stringify(cache, null, 2));
"
```

Cache is local-only. Don't ship.

---

## Step 3 — MCP path (if `SOURCE` ∈ {mcp, both})

### 3a. Detect MCP availability

The agentmemory MCP server is the primary read source.

Tools by priority:
| Priority | Tool | Use |
|----------|------|-----|
| 1 | `mcp__agentmemory__memory_smart_search` | Semantic search |
| 2 | `mcp__agentmemory__memory_recall` | Plain recall (fallback if smart_search errors) |

Detect by attempting smart_search. If `InputValidationError: tool not found` → MCP unavailable, fall to Step 4.

### 3b. Query

Call `mcp__agentmemory__memory_smart_search` with:
- `query`: `"MADD " + KEYWORDS` (the `MADD ` prefix matches the convention `/madd-learn` uses when writing)
- `limit`: `LIMIT`

If the tool supports a confidence/threshold parameter, pass `MIN_CONF`. Otherwise filter client-side after results return.

### 3c. Parse results

Each result has at minimum:
- `content` (text body — Worked / Failed bullets)
- `concepts` or `tags`
- `confidence` (0.0-1.0)
- `created_at` / `metadata.date`

Filter:
- Drop results not containing `MADD` in content/concepts (avoid bleed from non-MADD memories).
- Drop results with `confidence < MIN_CONF`.

Keep top `LIMIT` by confidence × recency.

---

## Step 4 — File-fallback path (if MCP failed OR `SOURCE` ∈ {file, both})

### 4a. Check LEARNINGS.md

`Bash`:
```bash
test -f LEARNINGS.md && echo EXISTS || echo MISSING
```

If MISSING and `SOURCE = file` → report "No LEARNINGS.md and MCP unavailable. Nothing to recall." Exit cleanly.

If MISSING and `SOURCE = both` and MCP also empty → same exit.

### 4b. Grep matching entries

Each entry in LEARNINGS.md follows the format from `/madd-learn` Step 6b:
```markdown
## <feature-name> — <ISO-date>

**Branch:** <branch>
**Confidence:** <1-5>/5
**Tags:** <tags>

**What worked:** ...
**What failed:** ...
---
```

`Bash` — extract candidate `## ` headings + tags lines that mention any keyword (case-insensitive):
```bash
awk -v IGNORECASE=1 -v kws="$KEYWORDS" '
  BEGIN { split(kws, K, " "); for (i in K) Kpat = Kpat K[i] "|"; sub(/\|$/, "", Kpat) }
  /^## / { current = $0; matched = 0; block = current "\n" }
  /^---$/ { if (matched) print block "\n"; matched = 0; next }
  /^\*\*Tags:\*\*/ { if ($0 ~ Kpat) matched = 1 }
  { if (current) block = block $0 "\n" }
  match(tolower($0), tolower(Kpat)) { matched = 1 }
' LEARNINGS.md | head -200
```

Then for each block, parse confidence (`**Confidence:** X/5`) and filter `X/5 >= ceil(MIN_CONF * 5)`.

Keep top `LIMIT` by date (most recent first; LEARNINGS.md is append-only so reverse traversal == newest first).

### 4c. Note

If `SOURCE = both` and MCP returned results, dedupe file entries by feature name (MCP wins when both present).

---

## Step 5 — Format digest

For each retained entry, print one block:

```
─────────────────────────────────────────
<feature-name>  •  <date>  •  confidence <X>/5
Tags: <tag1, tag2>
Source: <MCP | file>

Worked:
  - <bullet>
  - <bullet>

Failed:
  - <bullet>
  - <bullet>
─────────────────────────────────────────
```

Top of output (one line):
```
Found <N> matching learning(s) for "<KEYWORDS>" (source: <SOURCE | cache>, min-confidence: <MIN_CONF>)
```

If served from cache, append `(cached <minutes>m ago, ttl <TTL>s)`.

Bottom of output (one line):
```
Recall complete. /madd-ship Phase 1 may auto-pull these if user opts in.
```

---

## Step 6 — Integration handoff (if called by `/madd-ship`)

When invoked as part of `/madd-ship` Phase 1a (not by user directly), do not just print — also return the digest as structured context so the caller can use it for the next `AskUserQuestion` ("Apply any of these constraints to the spec?").

Detection: if `$ARGUMENTS` includes `--from-ship` flag, structured-return mode. Otherwise print mode.

In structured-return mode, after the digest, append a machine-parseable JSON envelope:

```json
{
  "recall": {
    "keywords": "<KEYWORDS>",
    "count": <N>,
    "entries": [
      { "feature": "...", "date": "...", "confidence": 0.8, "worked": [...], "failed": [...] }
    ]
  }
}
```

`/madd-ship` parses this to present the user with checkboxes per entry.

---

## Failure modes

| Symptom | Cause | Recovery |
|---------|-------|----------|
| `tool not found` for both MCP tools | agentmemory MCP not installed in this Claude Code env | Fall through to file mode |
| LEARNINGS.md absent and MCP empty | New project, never ran `/madd-learn` | Report "Nothing to recall — run `/madd-ship` then `/madd-learn` to start the loop" |
| awk recipe drops a match | Entry format drift from `/madd-learn` v2.0.0 | Show raw `grep -i "$kw" LEARNINGS.md` as backup; ask user to skim manually |
| MCP returns 100s of hits | Query too broad (`KEYWORDS = "the"`) | Re-ask user for narrower query via `AskUserQuestion`; do not paginate forever |
| Mixed-case keyword | grep without `-i` misses | awk uses `IGNORECASE=1`; bash grep callouts should use `-i` |

---

## Caveats

- This skill is **read-only**. Never write to MCP or LEARNINGS.md.
- `MADD ` prefix in MCP query is load-bearing — without it, recall pulls unrelated memories (calendar reminders, generic notes, etc.).
- File-mode confidence filter rounds up. `MIN_CONF=0.4` → require ≥ 2/5; `MIN_CONF=0.7` → require ≥ 4/5.
- For `/madd-ship` callers: ALWAYS pass `--from-ship` so structured envelope is returned for downstream `AskUserQuestion`.
- This skill does **not** auto-apply learnings to a spec — surfaces them only. The user (or `/madd-ship` Phase 1) decides what to inherit.
- Cache (`.madd-recall-cache.json`) is keyed on `KEYWORDS|LIMIT|MIN_CONF|SOURCE`. Changing any parameter forces re-fetch. TTL defaults 1h — long enough for spec-iteration loops, short enough that fresh `/madd-learn` writes surface in the next session.
- Cache file is local-only. Gitignored by `/madd-init` ≥ v2.5.0. Older repos: `echo '.madd-recall-cache.json' >> .gitignore`.
- Cache sweeps entries older than 7 days on each write — no manual rotation needed.
