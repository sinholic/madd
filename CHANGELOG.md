# Changelog

Per-command version history also lives in each command's frontmatter (`commands/madd-*.md`).

## 3.2.1 — 2026-06-11

### Fixed
- **commit-prefix hook**: heredoc commits (`git commit -m "$(cat <<'EOF' ...)"`) are now validated instead of skipped — this is Claude Code's default commit style, so the old skip made the hook a near no-op. Also handles `-m"msg"` (no space) and `--message=` forms. (hook v2.1.0)
- **phase-guard hook**: state file path passed via env var instead of string interpolation into Node source — paths with quotes/spaces no longer break parsing silently. (hook v2.1.0)
- **phase-guard hook**: `git push` block now applies only from Phase 5 onward — pushing `test(red):` WIP during Phases 3-4 is legitimate. (hook v2.1.0)
- **/madd-ship resume off-by-one**: `state.phase` documents the last *completed* phase; `RESUME_FROM = phase + 1`. Previously resume re-ran the already-completed phase. Resume also respects `SHIP_MODE` skip rules, and `RESUME_FROM > 8` routes to cleanup. (madd-ship v3.2.1)
- **install.sh**: skill backups now land in `~/.claude/skills/.backup/` (was wrongly `hooks/.backup/`).

### Added
- `uninstall.sh` — removes all 16 commands, 3 hooks, 3 skills, and sub-runbook dirs; `--purge` also removes config + backups. README uninstall section previously listed only 4 files.
- `MADD_REF` install pinning: `MADD_REF=v3.2.1 curl ... | bash` installs from a tag instead of `main`.
- Install metadata recorded in `~/.claude/MADD.config` (`MADD_INSTALLED_REF/VERSION/AT`) for `/madd-update --check` drift detection.
- `tests/hook-smoke-test.sh` — 19 assertions covering block/pass behavior of all three hooks; wired into CI.
- CI: sub-runbook + SKILL.md frontmatter checks, `bash -n` on all shell scripts, ShellCheck, hook smoke tests.
- README: documents `node` as a hard requirement for hooks (they silently no-op without it); install.sh warns at install time.

## 3.2.0

- Phase bodies split into `commands/madd-ship-phases/phase-{1-8}-*.md`; orchestrator lazy-loads each phase. Cuts initial runbook load ~70%.

## 3.1.0

- Persistent state (`.madd-ship-state.json`) + resume protocol; file-tree work-type detection; Phase 1a auto-invokes `/madd-recall`; phase-boundary state writes power `madd-phase-guard.sh`.

## 3.0.0

- Work-type routing: auto-detect FE/BE/DevOps/Robot/Data; redirect Robot+Data to specialist skills; Phase 7d domain-specific UAT validation.

## 2.2.0

- Branch hygiene: pull latest base + create feature branch; platform-aware PR/MR (GitHub `gh`, GitLab `glab`); `--base` + `--no-new-branch` flags.

## 2.1.0

- Monorepo + workspace support.

## 2.0.0

- Operational runbook rewrite — every step names a real Claude Code tool call.

## 1.x

- 1.2.0 — `/madd-learn` integration. 1.1.0 — aspirational auto-validation. 1.0.0 — initial 8-phase workflow.
