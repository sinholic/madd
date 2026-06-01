#!/usr/bin/env bash
#
# MADD bootstrap installer
# Usage: curl -fsSL https://raw.githubusercontent.com/sinholic/madd/main/install.sh | bash
#

set -euo pipefail

REPO_BASE="${MADD_REPO_BASE:-https://raw.githubusercontent.com/sinholic/madd/main}"
COMMANDS_DIR="${HOME}/.claude/commands"
CONFIG_FILE="${HOME}/.claude/MADD.config"
SKILLS=(madd-init madd-ship madd-learn madd-update)

# Color output (skip if not TTY)
if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; NC=''
fi

log()  { printf "${GREEN}[madd]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[madd]${NC} %s\n" "$*"; }
err()  { printf "${RED}[madd]${NC} %s\n" "$*" >&2; }

# Pre-flight
command -v curl >/dev/null 2>&1 || { err "curl required"; exit 1; }

log "Installing MADD to ${COMMANDS_DIR}"
mkdir -p "${COMMANDS_DIR}"
mkdir -p "${COMMANDS_DIR}/.backup"

# Backup existing
TS=$(date -u +%Y%m%d-%H%M%S)
for skill in "${SKILLS[@]}"; do
  target="${COMMANDS_DIR}/${skill}.md"
  if [ -f "${target}" ]; then
    cp "${target}" "${COMMANDS_DIR}/.backup/${skill}.md.bak.${TS}"
    log "backed up existing ${skill}.md"
  fi
done

# Fetch skills
for skill in "${SKILLS[@]}"; do
  url="${REPO_BASE}/commands/${skill}.md"
  target="${COMMANDS_DIR}/${skill}.md"
  if curl -fsSL "${url}" -o "${target}.tmp"; then
    mv "${target}.tmp" "${target}"
    version=$(grep '^version:' "${target}" 2>/dev/null | head -1 | sed 's/version: //; s/"//g' || echo "?")
    log "installed ${skill} v${version}"
  else
    err "failed to fetch ${skill} from ${url}"
    rm -f "${target}.tmp"
    exit 1
  fi
done

# Write config
if [ ! -f "${CONFIG_FILE}" ]; then
  cat > "${CONFIG_FILE}" <<EOF
# MADD configuration
# Source URL for /madd-update — git URL, local path, or raw HTTPS base
MADD_SOURCE=https://github.com/sinholic/madd.git
EOF
  log "wrote ${CONFIG_FILE}"
else
  warn "${CONFIG_FILE} exists — left untouched"
fi

# Summary
echo
log "✓ MADD installed"
echo
echo "Next steps:"
echo "  1. Restart Claude Code so skills are surfaced"
echo "  2. In any project, run:"
echo "       /madd-init       # Scaffold AGENTS.md + WORKLOG.md"
echo "       /madd-ship <feature description>"
echo "       /madd-learn <feature-name>     # After shipping"
echo
echo "Update later:"
echo "  /madd-update"
echo
echo "Docs: https://github.com/sinholic/madd"
