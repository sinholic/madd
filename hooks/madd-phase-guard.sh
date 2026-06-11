#!/usr/bin/env bash
# madd-hook-version: 2.1.0
# madd-phase-guard.sh — PreToolUse hook: enforce MADD phase discipline
#
# Blocks (exit 2 with structured JSON):
#   - `git commit -m "feat:*"` while .madd-ship-state.json shows tests_red_confirmed=false
#   - `git push` while last_test_exit != 0 AND phase >= 5 (red-test WIP pushes
#     during Phases 3-4 are allowed; the green gate applies from Phase 5 on)
#
# No-op when no .madd-ship-state.json present (project not in a ship cycle).
# Uses Node.js for JSON parsing (no jq dependency). State path passed via env
# var (not string interpolation) so paths with quotes/spaces can't break out.

set -u

# 1. Read tool input from stdin
INPUT=$(cat)

# 2. Extract command (only act on Bash tool)
CMD=$(echo "$INPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{process.stdout.write(JSON.parse(d).tool_input?.command||'')}catch{}})" 2>/dev/null)

[ -z "$CMD" ] && exit 0

# 3. Locate repo root + state file
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$REPO_ROOT" ] && exit 0

STATE_FILE="$REPO_ROOT/.madd-ship-state.json"
[ ! -f "$STATE_FILE" ] && exit 0

# 4. Parse state — path via env var, never interpolated into JS source
read_state() {
  MADD_STATE_FILE="$STATE_FILE" node -e "
    try {
      const s = JSON.parse(require('fs').readFileSync(process.env.MADD_STATE_FILE, 'utf8'));
      const v = s[process.argv[1]];
      process.stdout.write(v === null || v === undefined ? '' : String(v));
    } catch {}
  " "$1" 2>/dev/null
}
PHASE=$(read_state phase)
RED_OK=$(read_state tests_red_confirmed)
LAST_EXIT=$(read_state last_test_exit)
FEATURE=$(read_state feature)

# 5. Rule A — block feat: commit when tests not RED-confirmed
# Match: git commit -m "feat:..." OR feat(scope):... OR feat!: ...
if echo "$CMD" | grep -qE '(^|&&[[:space:]]*|;[[:space:]]*)git commit[[:space:]].*-m[[:space:]]+["\x27]feat(\([^)]+\))?!?:'; then
  if [ "$RED_OK" != "true" ]; then
    cat <<EOF
{"decision":"block","code":"MADD_PHASE_TESTS_NOT_RED","reason":"MADD phase guard: feature commit blocked. Current phase=${PHASE}, feature=${FEATURE}. Phase 3 RED gate not confirmed (tests_red_confirmed=false in .madd-ship-state.json). Run tests, confirm all new tests fail for the right reason, then mark RED via /madd-ship Phase 3c gate before committing."}
EOF
    exit 2
  fi
fi

# 6. Rule B — block git push when last test run failed.
# Only from Phase 5 on: Phases 3-4 legitimately carry red tests (test(red): WIP).
PHASE_NUM=$(printf '%s' "$PHASE" | grep -oE '^[0-9]+' || true)
if echo "$CMD" | grep -qE '(^|&&[[:space:]]*|;[[:space:]]*)git push'; then
  if [ -n "$LAST_EXIT" ] && [ "$LAST_EXIT" != "0" ] && [ -n "$PHASE_NUM" ] && [ "$PHASE_NUM" -ge 5 ]; then
    cat <<EOF
{"decision":"block","code":"MADD_PHASE_TESTS_FAILING","reason":"MADD phase guard: push blocked. Last <TEST_CMD> exit=${LAST_EXIT} (recorded in .madd-ship-state.json). Phase 6 CI gate requires green tests. Re-run tests, fix failures, then push."}
EOF
    exit 2
  fi
fi

exit 0
