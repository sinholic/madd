# Phase 6 — CI / Build gate

## 6a. Full check suite

```bash
<TEST_CMD> && <BUILD_CMD>
```

Both must pass. Do not bypass hooks. Do not skip type errors.

**[state]** Capture exit code of `<TEST_CMD>` independently of the `&&` chain (re-run `<TEST_CMD>; echo "exit=$?"` if needed) → update `last_test_exit = <code>`. If `<BUILD_CMD>` failed: `last_build_exit = <code>`. Hook reads `last_test_exit` before allowing `git push`.

## 6b. Push feature branch

```bash
git push -u origin "$FEATURE_BRANCH"
```

If blocked by `madd-phase-guard.sh`: read the structured hook reason. If stale `last_test_exit` — re-run `<TEST_CMD>` and update state. Never bypass with `--no-verify`.

**[state]** After successful push: `phase = "6"`, `phase_started = now`.

## 6c. Detect platform

```bash
git remote get-url origin
```

Classify by remote URL:
- contains `github.com` → `GITHUB`
- contains `gitlab.` (incl. self-hosted) → `GITLAB`
- contains `bitbucket.org` → `BITBUCKET`
- other → `AskUserQuestion`

Store as `PLATFORM`.

## 6d. Open draft PR / MR — targets `$BASE`

**GITHUB:**
```bash
gh pr create --draft --base "$BASE" --head "$FEATURE_BRANCH" \
  --title "feat: <feature one-liner>" \
  --body "$(cat <<'EOF'
## Summary
<spec one-liner>

## Acceptance criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

## Test plan
- [ ] All N named tests green
- [ ] Staging UAT pass (Phase 7)

🤖 Generated with [Claude Code](https://claude.com/claude-code) via /madd-ship
EOF
)"
```

**GITLAB:**
```bash
glab mr create --draft \
  --target-branch "$BASE" --source-branch "$FEATURE_BRANCH" \
  --title "feat: <feature one-liner>" \
  --description "$(cat <<'EOF'
## Summary
<spec one-liner>

## Acceptance criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

## Test plan
- [ ] All N named tests green
- [ ] Staging UAT pass (Phase 7)
EOF
)"
```

If `glab` not installed → fall back to printing MR URL pattern:
```
https://<gitlab-host>/<group>/<project>/-/merge_requests/new?merge_request[source_branch]=$FEATURE_BRANCH&merge_request[target_branch]=$BASE
```

**BITBUCKET:** print URL pattern + manual instruction.

Capture PR/MR URL → store in state as `pr_url`. Print to user.

Return → load `phase-7-uat.md` (skip if `SHIP_MODE == "Hotfix"`).
