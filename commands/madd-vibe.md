---
description: "Vibe coding mode w/ SDD discipline. Brainstorm → plan → phase-by-phase build w/ milestones. Hooks superpowers skills. Graduates to /madd-ship when locked."
argument-hint: "<project idea> [--stack <framework>] [--no-sdd] [--graduate]"
version: "2.0.0"
changelog: |
  2.0.0 — SDD methodology baked in. Hooks superpowers (brainstorming, writing-plans, subagent-driven-development, verification-before-completion). Phases + milestones per task. VIBE.md → PHASES.md ledger.
  1.0.0 — Initial runbook: scaffold, iterate, graduate path
---

# Runbook: Vibe Coding with SDD

You are executing `/madd-vibe`. Idea: **$ARGUMENTS**

Goal: ship a working app fast — but with **Spec-Driven Development** scaffolding so the prototype is *coherent* and *resumable*, not a mess.

**Vibe ≠ chaos.** Vibe means fast iteration on feel. SDD means each phase has a spec + milestone you can point to. You get both: brainstorm the shape, plan phases, build phase-by-phase with verification, graduate when ready.

**Use for:** prototypes, MVPs, exploratory builds, hackathon starts, side projects that may grow legs.

**Skip SDD with `--no-sdd`** if you literally want to throwaway-code with zero structure (rare — defaults to SDD on).

---

## Skill Hooks (read these as you go)

| Phase | Superpower skill invoked |
|-------|--------------------------|
| Step 1 (shape the idea) | `superpowers:brainstorming` |
| Step 3 (phase plan) | `superpowers:writing-plans` |
| Step 5 (build per phase) | `superpowers:subagent-driven-development` (or `executing-plans`) |
| Step 6 (verify phase) | `superpowers:verification-before-completion` |
| Step 8 (close milestone) | `superpowers:finishing-a-development-branch` |

If a hook skill isn't installed, fall back to inline equivalent (noted per step).

---

## Step 0 — Confirm mode

`AskUserQuestion`:
- "Vibe + SDD mode picks brainstorm → phase plan → build → verify per phase. Confirm?"
- header: "Vibe mode"
- options:
  - "Vibe + SDD (default) — fast iteration, phased plan, milestone per task" (Recommended)
  - "Vibe pure — no SDD, throwaway only (--no-sdd)"
  - "Cancel — I want /madd-ship (full discipline from day 1)"
  - "Cancel — I want /madd-init (existing project)"

Branch:
- SDD picked → continue Step 1
- `--no-sdd` picked → jump to legacy flow (see Appendix A)
- Cancelled → exit, suggest right skill

---

## Step 1 — Brainstorm the shape

**Invoke `superpowers:brainstorming` skill.** Announce: "Using superpowers:brainstorming to shape this project."

Pass the idea (`$ARGUMENTS`) as input. Brainstorming will:
- Ask clarifying questions (one at a time)
- Propose 2-3 approaches
- Present design + get approval
- Write spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`

**Spec is the SDD foundation.** No code yet.

If skill missing → fall back: ask 3-5 questions yourself (purpose, constraints, success criteria, scope, stack pref), present design inline, get approval, write spec manually to same path.

---

## Step 2 — Stack pick

If `--stack` in args, use it. Otherwise `AskUserQuestion`:

- "Stack? Fast defaults."
- options:
  - "Vite + React + TS"
  - "Next.js"
  - "Astro"
  - "FastAPI + Python"
  - "Express + TS"
  - "Other — describe"

Store as `STACK`. Append to spec under `## Stack`.

---

## Step 3 — Phase plan (writing-plans)

**Invoke `superpowers:writing-plans` skill.** Announce: "Using superpowers:writing-plans to break this into phases + milestones."

Hand it the spec from Step 1. Direct the plan to be **phase-structured**:

```markdown
# <Project> Implementation Plan

**Goal:** ...
**Architecture:** ...
**Tech Stack:** <STACK>

---

## Phase 1: <name> — Milestone: <deliverable>
### Task 1.1: ...
### Task 1.2: ...

## Phase 2: <name> — Milestone: <deliverable>
...
```

**Rules for phases:**
- Each phase = coherent slice of functionality (e.g., "scaffold + routing", "auth", "data layer", "core feature X")
- Each phase ends with a **milestone**: testable, demoable deliverable
- Phases ordered by dependency (no phase blocks on later one)
- Tasks within phase = bite-sized (2-5 min each per writing-plans convention)
- Each task has files to create/modify + steps + commit message

Save plan to `docs/superpowers/plans/YYYY-MM-DD-<project>-phases.md`.

If skill missing → fall back: write plan manually following structure above.

---

## Step 4 — Scaffold (Phase 0)

**Phase 0 = scaffold.** Treat as Phase 0 in the plan.

Run the canonical scaffolder for `STACK`:

```bash
case "<STACK>" in
  "vite-react") pnpm create vite "<name>" --template react-ts ;;
  "next")       pnpm create next-app "<name>" --typescript --no-eslint --tailwind --app --src-dir --import-alias '@/*' --use-pnpm ;;
  "astro")      pnpm create astro "<name>" --template minimal --typescript strict --no-git --skip-houston ;;
  "fastapi")    mkdir "<name>" && cd "<name>" && python -m venv .venv && source .venv/bin/activate && pip install fastapi uvicorn && mkdir app && echo "from fastapi import FastAPI\napp = FastAPI()\n@app.get('/')\ndef root(): return {'ok': True}" > app/main.py ;;
  "express")    mkdir "<name>" && cd "<name>" && pnpm init -y && pnpm add express && pnpm add -D typescript @types/express @types/node tsx && npx tsc --init ;;
esac
```

Cd into project. Verify exists:
```bash
cd "<name>" && pwd && ls -la
```

Git init + first commit:
```bash
git init -q && git add -A && git commit -q -m "phase-0: scaffold via /madd-vibe (<stack>)"
```

Write initial `PHASES.md` (ledger — see Step 8 for format).

---

## Step 5 — Build phase-by-phase

**For each phase in the plan:**

### 5a. Create phase branch

```bash
git checkout -b phase-<N>-<slug>
```

### 5b. Execute the phase

**Invoke `superpowers:subagent-driven-development`.** Announce: "Using superpowers:subagent-driven-development to build Phase <N>."

Hand it ONLY the tasks for the current phase from the plan. Subagent-driven-development will:
- Dispatch fresh implementer subagent per task
- Two-stage review per task (spec compliance + code quality)
- Commits per task

If skill missing → fall back to `superpowers:executing-plans`. If both missing → execute tasks inline yourself, one at a time, commit each.

### 5c. Track in PHASES.md

After each task commit, append to `PHASES.md` under current phase (see Step 8).

---

## Step 6 — Verify phase milestone

**Invoke `superpowers:verification-before-completion`.** Announce: "Using superpowers:verification-before-completion to verify Phase <N> milestone."

Verification commands depend on milestone, but must include at minimum:
1. Build passes: `pnpm build` (or stack equivalent)
2. Dev server starts: `pnpm dev` (background, check it boots)
3. Milestone criterion met (from plan): demo the deliverable (e.g., "user can sign up", "API returns JSON", "page renders")

**Iron law:** no milestone claim without fresh evidence. Run commands, paste output.

If verification fails → fix in current phase branch, re-verify. Do not advance phase until green.

---

## Step 7 — Close phase + milestone

When phase verified:

```bash
git checkout main
git merge phase-<N>-<slug> --no-ff -m "phase-<N>: <milestone> — closed"
git tag "phase-<N>-milestone" -m "<milestone description>"
git branch -d phase-<N>-<slug>
```

Optionally invoke `superpowers:finishing-a-development-branch` for cleanup/PR if remote exists.

Update `PHASES.md` — mark phase ✅ closed with tag + date.

**Loop:** if more phases remain → Step 5 for Phase N+1. Else → Step 9.

---

## Step 8 — `PHASES.md` ledger format

Single source of truth for phase + milestone state. Lives at project root.

```markdown
# PHASES — <project name>

Scaffolded <ISO-date> via /madd-vibe. Stack: <STACK>.
Spec: `docs/superpowers/specs/<file>.md`
Plan: `docs/superpowers/plans/<file>.md`

## Phase 0: Scaffold ✅
- Milestone: project boots
- Tag: `phase-0-milestone`
- Closed: <ISO-date>
- Notes: scaffolded via <command>

## Phase 1: <name> 🚧
- Milestone: <criterion>
- Tasks:
  - [x] 1.1 <task name> — commit `<sha>`
  - [x] 1.2 <task name> — commit `<sha>`
  - [ ] 1.3 <task name>

## Phase 2: <name> ⏳
- Milestone: <criterion>
- Tasks: (locked, see plan)
```

Status legend: ⏳ pending · 🚧 in progress · ✅ closed · ❌ blocked

---

## Step 9 — Graduate (`--graduate` or all phases done)

When all phases closed OR user invokes `/madd-vibe --graduate`:

`AskUserQuestion`:
- "All phases closed (or you asked to graduate). Move to full MADD discipline?"
- options:
  - "Yes — write AGENTS.md, enable /madd-ship" (Recommended)
  - "Yes — and seed WORKLOG.md / LEARNINGS.md from PHASES.md"
  - "Not yet — keep iterating in vibe mode"

If yes:

### 9a. Run madd-init existing

Invoke `madd-init` runbook in `existing` mode. Detect stack from scaffold, derive conventions from spec + plan, write AGENTS.md.

### 9b. Migrate PHASES.md → WORKLOG.md

Each closed phase → WORKLOG entry:

```markdown
## Phase <N>: <name> — <date>
- Milestone: <criterion>
- Tag: `phase-<N>-milestone`
- Tasks: <count>, commits: <count>
- Spec ref: <spec path>
```

Archive original:
```bash
mv PHASES.md .madd-vibe-archive.phases.md
```

### 9c. Announce

> Project graduated. Full MADD active.
> - AGENTS.md written
> - WORKLOG.md seeded from phase history
> - Future features: `/madd-ship <description>`
> - Capture learnings: `/madd-learn`
> - Debug: `/madd-debug`
> - Review: `/madd-review`
> - Security: `/madd-secure`

---

## Step 10 — Iteration loop (re-invocation in existing vibe project)

If `/madd-vibe <thing>` called inside existing project (`PHASES.md` exists):

`AskUserQuestion`:
- "What's the move?"
- options:
  - "Add a new phase — describe milestone" → Step 3 (writing-plans for new phase only) → Step 5 build → Step 6 verify → Step 7 close
  - "Add task to current phase" → append to plan, dispatch subagent for task
  - "Refactor for feel within current phase" → no new milestone, vibe-edit, commit
  - "Capture iteration note" → append timestamped note to current phase in PHASES.md
  - "Graduate" → Step 9
  - "Abort current phase" → reset branch, mark ❌ in PHASES.md, choose next move

---

## Appendix A — Legacy `--no-sdd` flow

If user picks pure vibe (no SDD):
- Skip Steps 1, 3, 5b's subagent-driven-development invocation, 6, 8
- Scaffold (Step 4), write minimal `VIBE.md` (one-liner iteration log), run dev server
- No phases, no milestones, no spec, no plan
- Same `--graduate` path (Step 9) but no phases to migrate — just write fresh AGENTS.md

This is the v1.0.0 flow. Preserved for users who genuinely want zero structure.

---

## Failure modes

| Symptom | Recovery |
|---------|----------|
| Brainstorming skill missing | Fall back to inline 3-5 question flow + write spec manually |
| Writing-plans skill missing | Write phase plan manually following Step 3 template |
| Subagent-driven-development missing | Fall back to `executing-plans`, then inline |
| Verification fails | Stay in phase branch, fix, re-verify. Never merge red. |
| Scaffolder fails | Show error; retry / different stack / manual scaffold |
| Dir exists | Ask: overwrite / suffix / abort |
| Phase blocks on later phase | Plan is wrong — re-invoke writing-plans, reorder |
| User wants to skip verification | Refuse politely — verification is the milestone gate |
| Phase scope creeps mid-build | Stop, ask: close current phase here / extend plan / split into new phase |

---

## Caveats

- **SDD is the default for a reason.** Phases + milestones make the project resumable across sessions + reviewable by others. Pure vibe (no SDD) is escape hatch, not default.
- **`PHASES.md` is the source of truth** for prototype state. Keep it current.
- **Milestone = demo-able deliverable**, not "feels done". Verification is the gate.
- **Graduation is one-way.** Project on MADD rails after — `/madd-ship` for future features.
- **Skill hooks degrade gracefully.** If a superpower skill missing, inline fallback exists per step. Skill present = better. Absent = still works.
- **Never deploy vibe code to real users** without graduating + full review pass.
