#!/usr/bin/env bash
# madd-hook-version: 2.0.0
# madd-phase-guard.sh — PreToolUse hook: enforce MADD phase discipline
#
# Blocks (exit 2 with structured JSON):
#   - `git commit -m "feat:*"` while .madd-ship-state.json shows tests_red_confirmed=false
#   - `git push` while last_test_exit != 0
#
# No-op when no .madd-ship-state.json present (project not in a ship cycle).
# Uses Node.js for JSON parsing (no jq dependency).

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

# 4. Parse state
PHASE=$(node -e "try{process.stdout.write(String(require('$STATE_FILE').phase||''))}catch{}" 2>/dev/null)
RED_OK=$(node -e "try{process.stdout.write(String(require('$STATE_FILE').tests_red_confirmed===true))}catch{process.stdout.write('false')}" 2>/dev/null)
LAST_EXIT=$(node -e "try{const e=require('$STATE_FILE').last_test_exit;process.stdout.write(e===null||e===undefined?'':String(e))}catch{}" 2>/dev/null)
FEATURE=$(node -e "try{process.stdout.write(String(require('$STATE_FILE').feature||''))}catch{}" 2>/dev/null)

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

# 6. Rule B — block git push when last test run failed
if echo "$CMD" | grep -qE '(^|&&[[:space:]]*|;[[:space:]]*)git push'; then
  if [ -n "$LAST_EXIT" ] && [ "$LAST_EXIT" != "0" ]; then
    cat <<EOF
{"decision":"block","code":"MADD_PHASE_TESTS_FAILING","reason":"MADD phase guard: push blocked. Last <TEST_CMD> exit=${LAST_EXIT} (recorded in .madd-ship-state.json). Phase 6 CI gate requires green tests. Re-run tests, fix failures, then push."}
EOF
    exit 2
  fi
fi

exit 0
