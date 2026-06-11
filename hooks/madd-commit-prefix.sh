#!/usr/bin/env bash
# madd-hook-version: 2.1.0
# madd-commit-prefix.sh — PreToolUse hook: enforce MADD commit prefix discipline
#
# Allowed prefixes (per madd-ship.md Commit prefix discipline table):
#   schema:  stub:  test(red):  feat:  refactor:  fix:  Rollback:
# Plus Conventional-Commits compatible scoped variants: feat(scope): etc.
#
# Only fires when .madd-ship-state.json present (project in active ship cycle)
# OR AGENTS.md mentions MADD (project opted in).
#
# Uses Node.js for JSON parsing (no jq dependency).

set -u

INPUT=$(cat)

CMD=$(echo "$INPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{process.stdout.write(JSON.parse(d).tool_input?.command||'')}catch{}})" 2>/dev/null)

[ -z "$CMD" ] && exit 0

# Only act on `git commit` (covers env-prefix, full path, and chained commands)
if ! echo "$CMD" | grep -qE '(^|&&[[:space:]]*|;[[:space:]]*|^[A-Z_]+=[^[:space:]]+[[:space:]]+)git[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

# Activation guard — only enforce when project opted in
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$REPO_ROOT" ] && exit 0

OPTED_IN=0
[ -f "$REPO_ROOT/.madd-ship-state.json" ] && OPTED_IN=1
if [ "$OPTED_IN" = "0" ] && [ -f "$REPO_ROOT/AGENTS.md" ]; then
  grep -qE '/madd-ship|MADD' "$REPO_ROOT/AGENTS.md" 2>/dev/null && OPTED_IN=1
fi
[ "$OPTED_IN" = "0" ] && exit 0

# Extract commit message.
# Heredoc commits (git commit -m "$(cat <<'EOF' ... EOF)") — extract first
# non-empty body line as subject. This is Claude Code's default commit style,
# so skipping heredocs would make the hook a no-op in practice.
MSG=""
if printf '%s\n' "$CMD" | grep -qE "<<-?[[:space:]]*['\"]?EOF"; then
  MSG=$(printf '%s\n' "$CMD" \
    | sed -n "/<<-\{0,1\}[[:space:]]*['\"]\{0,1\}EOF/,/^[[:space:]]*EOF['\"]\{0,1\}[[:space:]]*$/p" \
    | sed '1d;$d' \
    | grep -m1 -v '^[[:space:]]*$' || true)
# -m / --message, quoted, with or without space/= before the quote:
#   -m "msg"   -m"msg"   -m 'msg'   --message="msg"   --message "msg"
elif [[ "$CMD" =~ (-m|--message)([[:space:]]*|=)\"([^\"]+)\" ]]; then
  MSG="${BASH_REMATCH[3]}"
elif [[ "$CMD" =~ (-m|--message)([[:space:]]*|=)\'([^\']+)\' ]]; then
  MSG="${BASH_REMATCH[3]}"
fi

# No extractable message → skip (interactive editor commit)
[ -z "$MSG" ] && exit 0

SUBJECT=$(echo "$MSG" | head -1 | sed 's/^[[:space:]]*//')

# Allowed prefix regex. Matches:
#   schema:  stub:  test(red):  feat[(scope)]:  refactor[(scope)]:  fix[(scope)]:  Rollback:
# Also tolerates Conventional-Commits extras (docs/chore/perf/test/ci/style/build) for non-MADD-phase commits during the same cycle (e.g. a doc fix mid-feature).
# Stored in a variable to avoid bash [[ =~ ]] quoting hell with literal parens.
ALLOWED_RE='^(schema|stub|test\(red\)|test|feat|refactor|fix|Rollback|docs|chore|perf|ci|style|build)(\([^)]+\))?!?:[[:space:]]'
if ! [[ "$SUBJECT" =~ $ALLOWED_RE ]]; then
  cat <<EOF
{"decision":"block","code":"MADD_COMMIT_PREFIX_VIOLATION","reason":"MADD commit prefix hook: subject \"${SUBJECT}\" does not match required MADD prefixes. Allowed: schema: / stub: / test(red): / feat: / refactor: / fix: / Rollback: (with optional (scope) and ! for breaking). See /madd-ship Commit prefix discipline. To bypass for this repo, remove '.madd-ship-state.json' or drop MADD reference from AGENTS.md."}
EOF
  exit 2
fi

exit 0
