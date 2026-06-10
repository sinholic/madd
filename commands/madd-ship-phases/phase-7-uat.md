# Phase 7 — Staging UAT

**Skip entire phase if** `SHIP_MODE == "Hotfix"`.

## 7a. Regression check

```bash
<TEST_CMD>
```

Must pass clean.

## 7b. Start preview / staging

```bash
<DEV_CMD>   # or staging-specific command from AGENTS.md
```

If long-lived: `run_in_background: true`.

## 7c. Manual verification

`AskUserQuestion`:
- question: "Verify each acceptance criterion manually. All passing?"
- header: "UAT gate"
- options: "All pass — proceed to Phase 8" / "Some failed — abort or fix"

If failed: report which criteria, stop, suggest fixes.

**[state]** After "All pass": `phase = "7"`, `phase_started = now`, `uat_passed = true`.

## 7d. Domain-specific validation (WORK_TYPE routing)

**If `WORK_TYPE` ∈ {FE, FULLSTACK}:**

`AskUserQuestion`:
- question: "Run design validation against mockups/Figma?"
- header: "Design check"
- options: "Yes — run /madd-design" / "No — skip"

If yes: read + follow `/madd-design` runbook. Pass `--diff` to scope to current branch changes.

**If `WORK_TYPE == DEVOPS`:**

`AskUserQuestion`:
- question: "Run DevOps config review?"
- header: "Infra check"
- options: "Yes — run /madd-devops" / "No — skip"

If yes: read + follow `/madd-devops` runbook. Pass `--diff`.

**If `WORK_TYPE` ∈ {BE, default}:** standard UAT from 7c is sufficient. Skip 7d.

Return → load `phase-8-prod.md`.
