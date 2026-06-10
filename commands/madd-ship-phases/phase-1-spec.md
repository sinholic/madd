# Phase 1 — Spec

You entered Phase 1 from `/madd-ship` orchestrator. State + AGENTS.md fields are in scope.

**Skip entire phase if** `SHIP_MODE != "Standard"`.

---

## 1a.pre — Recall prior learnings

Strip stop words from feature description ("add", "the", "a", "fix", "to") → `KEYWORDS`.

Invoke `/madd-recall <KEYWORDS> --from-ship --limit 5`.

Parse the structured JSON envelope. If `recall.count > 0`:

`AskUserQuestion`:
- question: "Surface <recall.count> prior learning(s) for related work. Inherit into spec?"
- header: "Recall"
- options:
  - "Show me matches first" — print digest, re-ask
  - "Apply all as 'must consider'" — copy into spec Prerequisites
  - "Pick which to apply" — second AskUserQuestion (multi-select)
  - "Skip — none relevant"

If `recall.count == 0` or recall unavailable → one line ("No prior learnings matched."), continue.

## 1a. Draft spec

Write spec block in conversation:

```
**Feature:** <one sentence>
**Prerequisites:** <list, including any recall inheritances>
**Acceptance criteria:**
  1. <observable outcome>
  2. ...
**Named test list:**
  - test("<exact name>")
  - ...
**Out of scope:** <non-goals>
**Security & compliance:** <auth, validation, secrets, data exposure>
```

Show user. Iterate until accepted.

## 1b. Confirm conventions

`AskUserQuestion` (one call, 4 questions):

1. "Feature flags?" header "Flags" — options: AGENTS.md `{FF_POLICY}` + alternates
2. "Comment policy?" header "Comments" — options: AGENTS.md `{COMMENT_STYLE}` + alternates
3. "Error handling boundary?" header "Errors" — options: AGENTS.md `{ERROR_POLICY}` + alternates
4. "Rollback plan?" header "Rollback" — options: "Git revert + redeploy" / "DB rollback needed" / "Feature flag kill switch" / "Other"

Store as `SPEC_CONVENTIONS`.

## 1c. Final approval gate

`AskUserQuestion`:
- question: "Spec approved? Phase 2 begins after approval."
- header: "Spec gate"
- options: "Approved — proceed to Phase 2" / "Revise spec" / "Abort ship"

On "Revise" → loop to 1a. On "Abort" → stop cleanly.

**[state]** On approval, update `.madd-ship-state.json`:
```
phase = "1"
spec = { feature, prerequisites, acceptance_criteria, named_test_list, out_of_scope, security }
conventions = SPEC_CONVENTIONS
phase_started = now
```

Return control to orchestrator → load `phase-2-schema.md`.
