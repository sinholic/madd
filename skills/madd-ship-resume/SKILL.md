---
name: madd-ship-resume
description: "Use this skill when the user opens a project that has a .madd-ship-state.json file present at the repo root and they reference current work, where they left off, ongoing features, or ask what to do next. Surfaces the in-flight MADD ship and offers to resume from the recorded phase. Trigger on phrases like 'where was I', 'what's in progress', 'resume', 'continue feature', 'pick up where I left off', or any opening question about project state."
---

# Skill: Resume MADD ship

You were triggered because the user opened a project with `.madd-ship-state.json` at the repo root and asked about current work. Your job is to read the state, present it cleanly, and offer the user a resume path — not to silently restart phases.

## What to do

1. **Run `/madd-status`** (invoke the slash command via the Skill tool or by reading the runbook at `~/.claude/commands/madd-status.md`).

   This is read-only. Get the digest of:
   - Active feature + phase from `.madd-ship-state.json`
   - Active debug session from `.madd-debug.md`
   - Last WORKLOG entry
   - Branch + dirty count + recent commits

2. **Present a 3-option resume gate** via `AskUserQuestion`:

   - **"Resume from phase <N>"** — invoke `/madd-ship <feature>` (description from state). The ship runbook's Step 0j will detect the existing state and prompt resume confirmation. (Recommended)
   - **"Show me the spec / what's been done"** — `Read` the state file's `spec` field and recent commits before deciding.
   - **"Abandon this ship cycle"** — print a warning, then offer to run `/madd-checkpoint --note abandoned` so the state is recoverable before deletion.

3. **Do not auto-start a new ship.** Even if the user's opening message names a feature, ask first — they may have a different intent (status check, postmortem, doc update) on a project that happens to have stale state.

4. **Do not call `/madd-ship` directly without the resume option.** That would skip Step 0j and overwrite state.

## When to *not* fire

- The user explicitly references a different feature (not the one in state) — let them know the in-flight ship exists, then proceed with their task and recommend `/madd-checkpoint` before swapping.
- The state file is older than 30 days and the user is clearly on a new task — surface the stale state once, then move on.
- `.madd-ship-state.json` doesn't exist — this skill should never have fired; abort silently.

## Related

- `/madd-status` — the read this skill wraps
- `/madd-ship` Step 0j — the actual resume handshake
- `/madd-checkpoint` — what to run before pivoting away
