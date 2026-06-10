---
description: "Validate implemented FE against design mockups. Checks components, spacing, color tokens, typography, icons, theming. Produces DESIGN-REVIEW.md."
argument-hint: "[--figma <url>] [--ticket <id>] [--files <paths>]"
version: "1.0.0"
changelog: |
  1.0.0 — Initial runbook: 7-dimension design validation, Figma + Jira reference, DESIGN-REVIEW.md output
---

# Runbook: FE design validation

You are executing `/madd-design`. Args: **$ARGUMENTS**

Goal: compare implemented UI against design reference across 7 dimensions. Produce scored DESIGN-REVIEW.md.

---

## Step 0 — Pre-flight

`Bash`:
```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd
```

`Read`: `AGENTS.md` — extract `LANGUAGE`, `FRAMEWORK`, `DESIGN_SYSTEM` (if present).

Detect design system from codebase:
```bash
grep -r "design-system\|ui-kit\|component-library\|tokens" package.json 2>/dev/null | head -5
find . -maxdepth 4 -name "tokens.ts" -o -name "theme.ts" -o -name "tokens.css" 2>/dev/null | head -5
```

Store detected design system as `DESIGN_SYSTEM`. If unclear → will ask in Step 1.

---

## Step 1 — Locate design reference

Parse `$ARGUMENTS` for:
- `--figma <url>` → Figma reference URL
- `--ticket <id>` → Jira ticket ID (e.g. `BT-380`)
- `--files <paths>` → Implementation files to check (skip Step 2 auto-detection)

If no reference provided → `AskUserQuestion`:
- question: "Where is the design reference?"
- header: "Design ref"
- options:
  - "Figma URL — paste below"
  - "Jira ticket — has mockup attached"
  - "Local screenshots — I'll describe"
  - "No reference — check conventions only"

**If Figma URL available:**

Use Figma MCP (`mcp__2c0e3c1e-81b6-46b7-b129-c9f600ee5d33__get_design_context`) to fetch design context. Extract:
- Component names used in design
- Color values / token names
- Spacing values
- Typography styles
- Icon references

Store as `DESIGN_REF`.

**If Jira ticket:**

Use Jira MCP (`mcp__jira__getJiraIssue`) to fetch ticket. Look for:
- Attachments (screenshots, mockups)
- Description containing mockup images or Figma links
- Acceptance criteria mentioning visual requirements

Extract visual requirements into `DESIGN_REF`.

**If no reference:**
Set `DESIGN_REF = null`. Step 3 will check conventions only (no pixel-level comparison).

---

## Step 2 — Collect implementation files

If `--files` provided → use those paths directly.

Otherwise, detect FE files changed:
```bash
git diff HEAD --name-only | grep -E "\.(tsx|jsx|ts|js|vue|svelte|css|scss|less)$"
```

If no recent changes → ask:
`AskUserQuestion`:
- "No recent FE changes detected. What to check?"
- Options:
  - "Current branch diff" — `git diff main --name-only`
  - "Specific directory" — ask path
  - "Specific files" — ask paths
  - "All FE files" — find . recursively (warn: may be large)

`Read` each file in scope. Hold contents.

---

## Step 3 — Analyze 7 dimensions

For each dimension, score: **PASS** / **PARTIAL** / **FAIL** / **N/A** (no reference).

### 3a. Layout & spacing

Compare layout structure (flex/grid usage, element hierarchy) vs design reference.

Check:
- Spacing values use design tokens / CSS variables vs hardcoded `px` values
- Gap, padding, margin consistent with design system scale (4px, 8px, 16px, 24px, 32px etc)
- Flex/grid direction matches intended layout
- Element order matches design

Flag:
- Hardcoded `margin: 13px` type values
- Spacing that diverges >4px from design reference

### 3b. Color tokens

Check:
- Colors reference CSS variables or design token constants (e.g. `var(--color-primary)`, `colors.primary`)
- No hardcoded hex/rgb values for semantic colors (backgrounds, text, borders)
- Semantic color usage correct (error → red token, success → green token, etc.)

```bash
grep -rn "#[0-9a-fA-F]\{3,6\}\|rgb(\|rgba(" $(echo $SCOPE_FILES) 2>/dev/null | grep -v "\.test\.\|snapshot\|storybook" | head -20
```

Flag each hardcoded color as PARTIAL or FAIL depending on how semantic it is.

### 3c. Typography

Check:
- Font family uses design token or CSS variable
- Font sizes use design scale (not arbitrary `font-size: 13px`)
- Font weights use named constants or token
- Line-height and letter-spacing within design system

```bash
grep -rn "font-size:\|font-weight:\|font-family:\|line-height:" $(echo $SCOPE_FILES) 2>/dev/null | grep -v "var(\|token\|inherit" | head -20
```

### 3d. Component usage

Compare components used in implementation vs design reference.

Check:
- Correct design system component used (e.g. `<Button>` not `<button>`)
- No custom reimplementation of existing design system components
- Component props match design variant (e.g. `variant="primary"` not `variant="default"`)
- No deprecated component versions

```bash
grep -rn "import.*from" $(echo $SCOPE_FILES) 2>/dev/null | grep -iE "component|ui|button|input|modal|form|card|table" | head -20
```

If `DESIGN_REF` contains specific component names, compare against imports.

### 3e. Icons

Check:
- Correct icon library used (not mixed icon sets)
- Icon names match design reference exactly
- Icon sizes use design token sizes
- No emoji substitutions for icons

```bash
grep -rn "Icon\|icon\|svg\|<Svg" $(echo $SCOPE_FILES) 2>/dev/null | head -20
```

### 3f. Theming / per-project

Detect project from AGENTS.md or repo name. Apply project-specific rules:

| Project | Theme check |
|---------|-------------|
| `orion-lite-fe` | Uses `orion-lite` theme tokens, not `orion` full tokens |
| `bouchon-lite-fe` | Uses lite palette, compact spacing |
| `zelda-fe` | RBAC-aware UI components present where needed |
| `kejaksaan-fe` | Localization strings in correct locale file |

Check:
- Theme provider correctly wraps page/component
- No theme leakage from sibling projects (copy-pasted tokens from wrong project)
- Dark mode support if project requires it

### 3g. Responsive / breakpoints

Check:
- Breakpoints use design system breakpoint tokens (not arbitrary widths)
- Mobile layout doesn't overflow viewport
- Touch targets ≥ 44px on interactive elements

```bash
grep -rn "@media\|breakpoint\|useMediaQuery\|sm:\|md:\|lg:\|xl:" $(echo $SCOPE_FILES) 2>/dev/null | head -20
```

---

## Step 4 — Score and classify findings

For each dimension 3a–3g, assign score. For each deviation found, classify:

- **CRITICAL** — Wrong component used, breaks user flow
- **HIGH** — Significant visual divergence from design reference (>10% layout, wrong color semantics)
- **MEDIUM** — Minor spacing deviation, partial token usage
- **LOW** — Nitpick spacing (1-2px), redundant style

---

## Step 5 — Write DESIGN-REVIEW.md

`Write` to `<repo-root>/DESIGN-REVIEW.md`:

```markdown
# Design Review — <ISO date>

**Feature / scope:** <summary>
**Design reference:** <Figma URL or Jira ticket or "none — conventions only">
**Files checked:** <count>

## Score Summary

| Dimension | Score | Findings |
|-----------|-------|----------|
| Layout & spacing | PASS/PARTIAL/FAIL/N/A | N issues |
| Color tokens | ... | ... |
| Typography | ... | ... |
| Component usage | ... | ... |
| Icons | ... | ... |
| Theming | ... | ... |
| Responsive | ... | ... |

**Overall:** PASS / NEEDS WORK / FAIL

---

## CRITICAL

### 1. <title>
**File:** `<path>:<line>`
**Issue:** <description>
**Design says:** <expected>
**Implementation has:** <actual>
**Fix:**
```<lang>
<suggestion>
```

---

## HIGH

...

---

## MEDIUM

...

---

## LOW

...

---

## Notes

<Any context about intentional deviations or pending design decisions>
```

If all dimensions PASS → write brief "Design matches reference across all 7 dimensions."

---

## Step 6 — Report + optional fix

Print summary. Highlight CRITICAL + HIGH findings.

`AskUserQuestion`:
- "Apply suggested fixes?"
- Options:
  - "Apply Critical + High"
  - "Apply all"
  - "Review only — no changes"

For each fix: `Read` target file → `Edit` with suggestion → re-check.

After fixes: commit as `style: <feature> — align with design review`

---

## Failure modes

| Symptom | Recovery |
|---------|----------|
| Figma MCP unavailable | Fall back to manual description / Jira ticket |
| Jira ticket has no attachments | Ask user to paste design specs in chat |
| No design reference at all | Run conventions-only check (Steps 3b–3e) |
| Too many files (>30) | Narrow to `--files` pointing at changed files only |
| Design system not detected | Ask user which token/theme file to use as reference |

---

## Caveats

- Pixel-perfect comparison requires Figma MCP. Without it, check conventions only.
- PARTIAL score is expected — implementations sometimes deviate for good reason. Document intentional deviations.
- Never fail a design review purely on spacing nitpicks if product intent is preserved.
- Per-project theming rules take priority over generic design system defaults.
