#!/usr/bin/env bash
# madd-hook-version: 2.2.0
# madd-no-debug-code.sh — PreToolUse hook: reject debug code in source files
#
# Blocks (exit 2) when Edit/Write would add console.log / debugger; / print( / dbg!(
# to a non-test source file. Test paths are exempt:
#   *test*  *.test.*  *.spec.*  __tests__/  tests/  /test/
#
# CLI-output paths are exempt (stdout IS the product there):
#   Go:   cmd/**, main.go        Ruby: bin/**, Rakefile, *.rake
#
# Per-repo escape hatches at repo root:
#   .madd-no-debug-code.disabled — disable hook entirely
#   .madd-no-debug-code.allow    — one glob per line (matched against
#                                  repo-relative path and basename); # comments
#
# Uses Node.js for JSON parsing (no jq dependency).

set -u

INPUT=$(cat)

# Extract path + content. Tool may be Write (content=full file) or Edit (content=new_string)
TOOL=$(echo "$INPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{process.stdout.write(JSON.parse(d).tool_name||'')}catch{}})" 2>/dev/null)
FILE=$(echo "$INPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{process.stdout.write(JSON.parse(d).tool_input?.file_path||'')}catch{}})" 2>/dev/null)
CONTENT=$(echo "$INPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{const i=JSON.parse(d).tool_input||{};process.stdout.write(i.content||i.new_string||'')}catch{}})" 2>/dev/null)

[ -z "$FILE" ] && exit 0
[ -z "$CONTENT" ] && exit 0

# Opt-out check
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/.madd-no-debug-code.disabled" ]; then
  exit 0
fi

# Repo-relative path (for allowlist + CLI-path exemptions)
REL="$FILE"
if [ -n "$REPO_ROOT" ]; then
  REL="${FILE#"$REPO_ROOT"/}"
fi

# Allowlist check — .madd-no-debug-code.allow: one glob per line, # comments.
# Patterns match against the repo-relative path and the basename.
ALLOW_FILE="$REPO_ROOT/.madd-no-debug-code.allow"
if [ -n "$REPO_ROOT" ] && [ -f "$ALLOW_FILE" ]; then
  while IFS= read -r pat; do
    case "$pat" in ''|\#*) continue ;; esac
    # shellcheck disable=SC2254  # globs must stay unquoted to match
    case "$REL" in $pat) exit 0 ;; esac
    # shellcheck disable=SC2254
    case "$(basename "$FILE")" in $pat) exit 0 ;; esac
  done < "$ALLOW_FILE"
fi

# Test-path exemption — match basename or explicit test dirs only.
# (Avoid bare *test* substring — it triggers on harmless paths like /tmp/hook-test/src/foo.ts.)
BASENAME=$(basename "$FILE")
case "$BASENAME" in
  *.test.*|*.spec.*|test_*.py|*_test.py|*_test.go|*_test.rs|test_*.rb|*_spec.rb) exit 0 ;;
esac
case "$FILE" in
  */__tests__/*|*/__test__/*|*/tests/*|*/test/*|*/spec/*|*/specs/*|*/e2e/*|*/integration/*) exit 0 ;;
esac

# CLI-output path exemptions — stdout is the product, not debug leftovers.
case "$FILE" in
  *.go)
    case "$REL" in
      cmd/*|*/cmd/*|main.go|*/main.go) exit 0 ;;
    esac
    ;;
  *.rb)
    case "$REL" in
      bin/*|*/bin/*|exe/*|*/exe/*) exit 0 ;;
    esac
    ;;
esac

# Pick patterns by file extension
PATTERN=""
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)  PATTERN='console\.log|console\.debug|debugger;' ;;
  *.py)                                PATTERN='^[[:space:]]*print\(|pdb\.set_trace\(|breakpoint\(\)' ;;
  *.rs)                                PATTERN='dbg!\(|println!\(' ;;
  *.go)                                PATTERN='fmt\.Println\(|fmt\.Printf\(|log\.Println\(' ;;
  *.rb)                                PATTERN='[[:space:]]puts[[:space:]]|binding\.pry|byebug' ;;
  *)                                   exit 0 ;;
esac

# Scan content. Report first hit with line number relative to the snippet.
HIT=$(echo "$CONTENT" | grep -nE "$PATTERN" | head -1 || true)

if [ -n "$HIT" ]; then
  LINENO_SNIPPET=$(echo "$HIT" | cut -d: -f1)
  MATCH=$(echo "$HIT" | cut -d: -f2- | head -1 | tr -d '"' | tr -d "'" | head -c 80)
  cat <<EOF
{"decision":"block","code":"MADD_DEBUG_CODE_FORBIDDEN","reason":"MADD no-debug-code hook: ${TOOL} to ${FILE} would add debug-only code (line ${LINENO_SNIPPET}: \"${MATCH}\"). Source files must not carry console.log/debugger/print/dbg!/etc. Allowed in test paths (*.test.*, __tests__/, tests/, etc.). If intentional, opt out per-repo with: touch \$(git rev-parse --show-toplevel)/.madd-no-debug-code.disabled"}
EOF
  exit 2
fi

exit 0
