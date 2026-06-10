---
version: "3.2.0"
parent: "madd-ship.md"
---

# Phase 2 — Schema

**Skip entire phase if** `SHIP_MODE == "Quickfix"`.

## 2a. Identify schema surface

For each external input boundary in spec, identify the schema target:
- Function signatures (interfaces, types)
- API request/response shapes
- DB models / migrations
- Form / URL param validators

## 2b. Write schemas

Use `Write` / `Edit`. Types only — no runtime logic.

Validator choice by AGENTS.md `LANGUAGE`:
- TypeScript → Zod (or existing lib in deps)
- Python → Pydantic
- Go → struct tags + go-validator
- Rust → serde + validator

## 2c. Commit

```bash
git add <schema-files>
git commit -m "schema: add types for <feature>"
```

**[state]** After commit: `phase = "2"`, `phase_started = now`. Re-run Step 0i.5 file-tree signal now that diff exists; set `tree_signal_resolved = true`.

Return to orchestrator → load `phase-3-tests-red.md`.
