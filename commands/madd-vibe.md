---
description: "Vibe coding mode for new projects. Skip SDD/TDD discipline. Scaffold + iterate fast. Graduate to /madd-ship when ready to lock in."
argument-hint: "<project idea> [--stack <framework>]"
version: "1.0.0"
changelog: |
  1.0.0 — Initial runbook: scaffold, iterate, graduate path
---

# Runbook: Vibe coding

You are executing `/madd-vibe`. Idea: **$ARGUMENTS**

Goal: ship a working prototype fast. No tests required. No spec ceremony. Iterate on feel. Graduate to `/madd-ship` discipline when the shape locks in.

**This skill is opinionated about being unopinionated.** Use for: prototypes, throwaway experiments, exploratory builds, hackathon-style starts.

**Do NOT use for:** production features, anything touching real users, anything with security implications, anything destined for `main`.

---

## Step 0 — Confirm vibe mode is right

`AskUserQuestion`:
- "Vibe mode is for throwaway / prototype work. Confirm scope?"
- header: "Vibe scope"
- options:
  - "Prototype only — never going to prod"
  - "Hackathon-style start — may harden later via /madd-ship"
  - "Cancel — I want /madd-ship instead (discipline from day 1)"
  - "Cancel — I want /madd-init (existing project)"

If cancelled → exit, suggest the right skill.

---

## Step 1 — Stack pick (fast)

If `--stack` in args, use it. Otherwise `AskUserQuestion`:

- "Pick a stack — fast defaults, no analysis paralysis"
- options:
  - "Vite + React + TS" — SPA frontend
  - "Next.js" — fullstack React, deploy Vercel
  - "Astro" — content site + islands
  - "FastAPI + Python" — quick API
  - "Express + TS" — quick Node API
  - "Other — describe"

Store as `STACK`.

---

## Step 2 — Project name + location

`AskUserQuestion`:
- "Project name? (will be dir name)"
- options: free text via "Other"

`Bash`:
```bash
test -d "<name>" && echo "EXISTS" || echo "OK"
```

If exists → ask: overwrite, append suffix, abort.

---

## Step 3 — Scaffold

Run the canonical scaffolder for the stack — do NOT hand-write `package.json` etc.

`Bash` (example per stack):
```bash
case "<STACK>" in
  "vite-react") pnpm create vite "<name>" --template react-ts ;;
  "next")       pnpm create next-app "<name>" --typescript --no-eslint --tailwind --app --src-dir --import-alias '@/*' --use-pnpm ;;
  "astro")      pnpm create astro "<name>" --template minimal --typescript strict --no-git --skip-houston ;;
  "fastapi")    mkdir "<name>" && cd "<name>" && python -m venv .venv && source .venv/bin/activate && pip install fastapi uvicorn && mkdir app && echo "from fastapi import FastAPI\napp = FastAPI()\n@app.get('/')\ndef root(): return {'ok': True}" > app/main.py ;;
  "express")    mkdir "<name>" && cd "<name>" && pnpm init -y && pnpm add express && pnpm add -D typescript @types/express @types/node tsx && npx tsc --init ;;
esac
```

Run it. Cd into the new dir.

`Bash`:
```bash
cd "<name>" && pwd && ls -la
```

---

## Step 4 — Light setup

### 4a. Git init (optional)

`AskUserQuestion`:
- "Initialize git?"
- options: "Yes — first commit" / "No"

If yes:
```bash
git init -q && git add -A && git commit -q -m "init: scaffold via /madd-vibe (<stack>)"
```

### 4b. Write minimal VIBE.md (not AGENTS.md)

`Write` to `./VIBE.md`:

```markdown
# VIBE — <project name>

Prototype scaffolded <ISO-date> via /madd-vibe. Stack: <STACK>.

## Quick commands

\`\`\`bash
<dev command>
<build command>
\`\`\`

## Iteration log

- <ISO-date>: scaffolded

## When to graduate

Run `/madd-vibe --graduate` (or `/madd-init existing`) when:
- Prototype is going to real users
- Multiple people will work on it
- Bugs are starting to bite
- You want tests / CI / proper PRs

Graduation writes AGENTS.md from current state, enables `/madd-ship` discipline.
```

**No** AGENTS.md, **no** WORKLOG.md, **no** test runner setup. That's all post-graduation.

---

## Step 5 — Run it

`Bash` (background):
```bash
cd "<name>" && <dev-command>
```

(Use `run_in_background: true`.)

Print to user:
> Vibe scaffold ready. Dev server running.
> Edit, refresh, iterate. No tests, no PRs, no spec.
> Append notes to VIBE.md as you go.
>
> When ready to harden: `/madd-vibe --graduate`

---

## Step 6 — Iteration loop (subsequent invocations)

If `/madd-vibe <thing>` is called inside an existing vibe project (`VIBE.md` exists):

`AskUserQuestion`:
- "What's the vibe?"
- options:
  - "Add a feature" — describe → just implement, no spec ceremony
  - "Try something different" — describe → implement quickly, throw away if bad
  - "Refactor for feel" — clean up taste-based, no discipline
  - "Graduate to /madd-ship" — see Step 7
  - "Capture iteration note" — append timestamped entry to VIBE.md

For "Add a feature" / "Try something different":
- No spec block
- No named test list
- No commit conventions enforced
- Just write code, run, see, iterate
- Append one line to VIBE.md iteration log when done

---

## Step 7 — Graduate (`--graduate`)

When called with `--graduate` or selected from Step 6:

`AskUserQuestion`:
- "Graduate to full MADD discipline?"
- options:
  - "Yes — write AGENTS.md, enable /madd-ship" — proceed
  - "Yes — and write WORKLOG.md / LEARNINGS.md scaffolds too"
  - "Cancel"

### 7a. Run /madd-init existing

Invoke the `madd-init` runbook in `existing` mode. It will detect stack from scaffold, ask conventions, write AGENTS.md.

### 7b. Migrate VIBE.md → WORKLOG.md

Convert each iteration log entry into a WORKLOG entry:

```markdown
## <feature/iter from vibe> — <date>
- Vibe phase: <line from vibe log>
```

Archive original VIBE.md:
```bash
mv VIBE.md .madd-vibe-archive.md
```

### 7c. Announce graduation

> Project graduated. Now using full MADD.
> - AGENTS.md written (stack + conventions documented)
> - WORKLOG.md seeded with vibe history
> - Future features: use `/madd-ship <description>`
> - Capture learnings: `/madd-learn`
> - Debug: `/madd-debug`
> - Review: `/madd-review`
> - Security: `/madd-secure`

---

## Failure modes

| Symptom | Recovery |
|---------|----------|
| Scaffolder fails | Show error; ask if user wants to retry / pick different stack / manual scaffold |
| Dir exists | Ask: overwrite / suffix / abort |
| Stack not in defaults | Pick "Other" → user provides scaffold command |
| User asks for tests in vibe mode | Politely redirect — suggest `/madd-ship` if discipline wanted |
| Dev server fails to start | Show error; user fixes; vibe mode doesn't auto-recover |

---

## Caveats

- **No discipline by design.** This skill exists so MADD doesn't become friction for prototypes.
- **VIBE.md is the only artifact.** No AGENTS.md, no tests, no PR ceremony.
- **Graduation is one-way.** Once you `--graduate`, the project is on MADD rails.
- **Not for shared work.** Vibe mode assumes one developer iterating fast.
- **Never deploy vibe code to real users** without graduating first.
