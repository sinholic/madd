#!/usr/bin/env bash
#
# Hook smoke tests — feed sample PreToolUse JSON through each hook and assert
# block (exit 2) / pass (exit 0). Run from repo root: bash tests/hook-smoke-test.sh
# Requires: bash, node, git (must run inside a git repo — CI checkout qualifies).

set -u

REPO_ROOT=$(git rev-parse --show-toplevel) || { echo "must run inside a git repo"; exit 1; }
cd "$REPO_ROOT" || exit 1

STATE="$REPO_ROOT/.madd-ship-state.json"
PASS=0
FAIL=0

cleanup() { rm -f "$STATE" "$REPO_ROOT/.madd-no-debug-code.allow"; }
trap cleanup EXIT

bash_input() {
  node -e 'console.log(JSON.stringify({tool_name:"Bash",tool_input:{command:process.argv[1]}}))' "$1"
}

write_input() {
  node -e 'console.log(JSON.stringify({tool_name:"Write",tool_input:{file_path:process.argv[1],content:process.argv[2]}}))' "$1" "$2"
}

assert() { # assert <hook> <input> <expected_exit> <label>
  local hook="$1" input="$2" expected="$3" label="$4"
  printf '%s' "$input" | bash "hooks/$hook" >/dev/null 2>&1
  local got=$?
  if [ "$got" = "$expected" ]; then
    echo "  ok   $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL $label (expected exit $expected, got $got)"
    FAIL=$((FAIL + 1))
  fi
}

heredoc_commit() { # heredoc_commit <subject>
  printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\n%s\n\nbody line\nEOF\n)"' "$1"
}

echo "== madd-commit-prefix.sh =="
echo '{"feature":"x"}' > "$STATE"
assert madd-commit-prefix.sh "$(bash_input 'git commit -m "feat: good"')"            0 'feat quoted'
assert madd-commit-prefix.sh "$(bash_input 'git commit -m "bad message"')"           2 'bad subject blocked'
assert madd-commit-prefix.sh "$(bash_input 'git commit -m"feat: nospace"')"          0 '-m without space'
assert madd-commit-prefix.sh "$(bash_input 'git commit --message="bad msg"')"        2 '--message= blocked'
assert madd-commit-prefix.sh "$(bash_input "$(heredoc_commit 'feat: heredoc good')")" 0 'heredoc good subject'
assert madd-commit-prefix.sh "$(bash_input "$(heredoc_commit 'wrong heredoc subject')")" 2 'heredoc bad subject blocked'
assert madd-commit-prefix.sh "$(bash_input 'git status')"                            0 'non-commit ignored'
rm -f "$STATE"
# Without state file, opt-in falls back to AGENTS.md mentioning MADD.
if [ -f "$REPO_ROOT/AGENTS.md" ] && grep -qE '/madd-ship|MADD' "$REPO_ROOT/AGENTS.md"; then
  assert madd-commit-prefix.sh "$(bash_input 'git commit -m "bad message"')"         2 'AGENTS.md opt-in → still enforced'
else
  assert madd-commit-prefix.sh "$(bash_input 'git commit -m "bad message"')"         0 'no opt-in → pass-through'
fi

echo "== madd-phase-guard.sh =="
echo '{"phase":"2","tests_red_confirmed":false,"last_test_exit":null,"feature":"x"}' > "$STATE"
assert madd-phase-guard.sh "$(bash_input 'git commit -m "feat: too early"')" 2 'feat before RED blocked'
assert madd-phase-guard.sh "$(bash_input 'git commit -m "schema: ok"')"      0 'schema commit allowed'
echo '{"phase":"3","tests_red_confirmed":true,"last_test_exit":1,"feature":"x"}' > "$STATE"
assert madd-phase-guard.sh "$(bash_input 'git commit -m "feat: now ok"')"    0 'feat after RED allowed'
assert madd-phase-guard.sh "$(bash_input 'git push -u origin feat/x')"       0 'red push allowed in phase 3'
echo '{"phase":"5","tests_red_confirmed":true,"last_test_exit":1,"feature":"x"}' > "$STATE"
assert madd-phase-guard.sh "$(bash_input 'git push')"                        2 'failing push blocked from phase 5'
echo '{"phase":"5","tests_red_confirmed":true,"last_test_exit":0,"feature":"x"}' > "$STATE"
assert madd-phase-guard.sh "$(bash_input 'git push')"                        0 'green push allowed'
rm -f "$STATE"
assert madd-phase-guard.sh "$(bash_input 'git push')"                        0 'no state file → no-op'

echo "== madd-no-debug-code.sh =="
assert madd-no-debug-code.sh "$(write_input 'src/foo.ts' 'console.log("debug")')"   2 'console.log in source blocked'
assert madd-no-debug-code.sh "$(write_input 'src/foo.test.ts' 'console.log("ok")')" 0 'console.log in test allowed'
assert madd-no-debug-code.sh "$(write_input 'src/foo.ts' 'const x = 1;')"           0 'clean source allowed'
assert madd-no-debug-code.sh "$(write_input 'app/main.py' 'print("debug")')"        2 'print in python blocked'
assert madd-no-debug-code.sh "$(write_input 'cmd/root.go' 'fmt.Println("usage")')"  0 'go cmd/ CLI output allowed'
assert madd-no-debug-code.sh "$(write_input 'main.go' 'fmt.Println("usage")')"      0 'go main.go CLI output allowed'
assert madd-no-debug-code.sh "$(write_input 'pkg/core/run.go' 'fmt.Println("dbg")')" 2 'go pkg fmt.Println blocked'
assert madd-no-debug-code.sh "$(write_input 'bin/cli.rb' 'puts result ')"           0 'ruby bin/ puts allowed'
echo 'scripts/release.go' > "$REPO_ROOT/.madd-no-debug-code.allow"
assert madd-no-debug-code.sh "$(write_input 'scripts/release.go' 'fmt.Println("x")')" 0 'allowlist glob match allowed'
assert madd-no-debug-code.sh "$(write_input 'pkg/core/run.go' 'fmt.Println("x")')"  2 'non-allowlisted still blocked'
rm -f "$REPO_ROOT/.madd-no-debug-code.allow"

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" = "0" ] || exit 1
exit 0
