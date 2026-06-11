#!/usr/bin/env bash
#
# MADD uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/sinholic/madd/main/uninstall.sh | bash
#        or: bash uninstall.sh [--purge]
#
# Removes everything install.sh placed under ~/.claude/:
#   - commands/madd-*.md + madd-ship-phases/ + madd-init-shapes/
#   - hooks/madd-*.sh
#   - skills/madd-*/
#   - MADD.config (only with --purge)
#
# Backups in commands/.backup, hooks/.backup, skills/.backup are kept
# unless --purge is passed.

set -euo pipefail

COMMANDS_DIR="${HOME}/.claude/commands"
HOOKS_DIR="${HOME}/.claude/hooks"
SKILLS_DIR="${HOME}/.claude/skills"
CONFIG_FILE="${HOME}/.claude/MADD.config"

PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; NC=''
fi
log()  { printf "${GREEN}[madd]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[madd]${NC} %s\n" "$*"; }

COMMANDS=(
  madd-init madd-ship madd-learn madd-recall madd-status madd-checkpoint
  madd-rollback madd-update madd-debug madd-review madd-secure madd-vibe
  madd-design madd-devops madd-data madd-robot
)
HOOKS=( madd-phase-guard.sh madd-commit-prefix.sh madd-no-debug-code.sh )
SKILLS=( madd-ship-resume madd-pre-pr-check madd-post-learn )

REMOVED=0

log "Uninstalling MADD"

for cmd in "${COMMANDS[@]}"; do
  f="${COMMANDS_DIR}/${cmd}.md"
  if [ -f "$f" ]; then rm -f "$f"; log "  ✗ commands/${cmd}.md"; REMOVED=$((REMOVED + 1)); fi
done

for d in madd-ship-phases madd-init-shapes; do
  if [ -d "${COMMANDS_DIR}/${d}" ]; then
    rm -rf "${COMMANDS_DIR:?}/${d}"
    log "  ✗ commands/${d}/"
    REMOVED=$((REMOVED + 1))
  fi
done

for hook in "${HOOKS[@]}"; do
  f="${HOOKS_DIR}/${hook}"
  if [ -f "$f" ]; then rm -f "$f"; log "  ✗ hooks/${hook}"; REMOVED=$((REMOVED + 1)); fi
done

for skill in "${SKILLS[@]}"; do
  d="${SKILLS_DIR}/${skill}"
  if [ -d "$d" ]; then rm -rf "$d"; log "  ✗ skills/${skill}/"; REMOVED=$((REMOVED + 1)); fi
done

if [ "$PURGE" = "1" ]; then
  [ -f "$CONFIG_FILE" ] && { rm -f "$CONFIG_FILE"; log "  ✗ MADD.config"; }
  for b in "${COMMANDS_DIR}/.backup" "${HOOKS_DIR}/.backup" "${SKILLS_DIR}/.backup"; do
    if [ -d "$b" ]; then
      find "$b" -name 'madd-*' -delete 2>/dev/null || true
      log "  ✗ MADD backups in ${b}"
    fi
  done
else
  warn "kept MADD.config and backups (pass --purge to remove)"
fi

echo
log "✓ MADD uninstalled — ${REMOVED} artifacts removed"
warn "Per-project files (AGENTS.md, WORKLOG.md, .claude/settings.json hook entries) are not touched — remove those per repo if desired."
