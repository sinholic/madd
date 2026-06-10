#!/usr/bin/env bash
#
# MADD bootstrap installer (v2.0)
# Usage: curl -fsSL https://raw.githubusercontent.com/sinholic/madd/main/install.sh | bash
#
# Installs:
#   - commands/   → ~/.claude/commands/      (slash commands)
#   - hooks/      → ~/.claude/hooks/         (phase discipline + commit prefix + no-debug-code)
#   - skills/     → ~/.claude/skills/        (auto-trigger workflows)
#

set -euo pipefail

REPO_BASE="${MADD_REPO_BASE:-https://raw.githubusercontent.com/sinholic/madd/main}"
COMMANDS_DIR="${HOME}/.claude/commands"
HOOKS_DIR="${HOME}/.claude/hooks"
SKILLS_DIR="${HOME}/.claude/skills"
CONFIG_FILE="${HOME}/.claude/MADD.config"

# Slash commands shipped by MADD (16 total as of 2.0)
COMMANDS=(
  madd-init
  madd-ship
  madd-learn
  madd-recall
  madd-status
  madd-checkpoint
  madd-rollback
  madd-update
  madd-debug
  madd-review
  madd-secure
  madd-vibe
  madd-design
  madd-devops
  madd-data
  madd-robot
)

# Phase-discipline hooks
HOOKS=(
  madd-phase-guard.sh
  madd-commit-prefix.sh
  madd-no-debug-code.sh
)

# Auto-trigger skills (Anthropic SKILL.md format)
SKILLS=(
  madd-ship-resume
  madd-pre-pr-check
  madd-post-learn
)

# /madd-ship phase sub-runbooks (loaded on demand by madd-ship.md orchestrator)
SHIP_PHASES=(
  phase-1-spec
  phase-2-schema
  phase-3-tests-red
  phase-4-impl
  phase-5-green
  phase-6-ci
  phase-7-uat
  phase-8-prod
)

# /madd-init shape sub-runbooks (loaded only when shape matches)
INIT_SHAPES=(
  monorepo
  workspace
)

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

log "Installing MADD"
log "  commands → ${COMMANDS_DIR}"
log "  hooks    → ${HOOKS_DIR}"
log "  skills   → ${SKILLS_DIR}"

mkdir -p "${COMMANDS_DIR}" "${COMMANDS_DIR}/.backup"
mkdir -p "${HOOKS_DIR}"    "${HOOKS_DIR}/.backup"
mkdir -p "${SKILLS_DIR}"

TS=$(date -u +%Y%m%d-%H%M%S)
INSTALLED=0
SKIPPED=0

# --- Commands ---
log "Installing commands..."
for cmd in "${COMMANDS[@]}"; do
  target="${COMMANDS_DIR}/${cmd}.md"
  if [ -f "${target}" ]; then
    cp "${target}" "${COMMANDS_DIR}/.backup/${cmd}.md.bak.${TS}"
  fi
  url="${REPO_BASE}/commands/${cmd}.md"
  if curl -fsSL "${url}" -o "${target}.tmp" 2>/dev/null; then
    mv "${target}.tmp" "${target}"
    version=$(grep '^version:' "${target}" 2>/dev/null | head -1 | sed 's/version: //; s/"//g' || echo "?")
    log "  ✓ ${cmd} v${version}"
    INSTALLED=$((INSTALLED + 1))
  else
    warn "  ✗ ${cmd} (not found at ${url}; skipping)"
    rm -f "${target}.tmp"
    SKIPPED=$((SKIPPED + 1))
  fi
done

# --- Hooks ---
log "Installing hooks..."
for hook in "${HOOKS[@]}"; do
  target="${HOOKS_DIR}/${hook}"
  if [ -f "${target}" ]; then
    cp "${target}" "${HOOKS_DIR}/.backup/${hook}.bak.${TS}"
  fi
  url="${REPO_BASE}/hooks/${hook}"
  if curl -fsSL "${url}" -o "${target}.tmp" 2>/dev/null; then
    mv "${target}.tmp" "${target}"
    chmod +x "${target}"
    version=$(grep '^# madd-hook-version:' "${target}" 2>/dev/null | head -1 | sed 's/.*: //' || echo "?")
    log "  ✓ ${hook} v${version}"
    INSTALLED=$((INSTALLED + 1))
  else
    warn "  ✗ ${hook} (not found at ${url}; skipping)"
    rm -f "${target}.tmp"
    SKIPPED=$((SKIPPED + 1))
  fi
done

# --- Skills (auto-trigger) ---
log "Installing skills..."
for skill in "${SKILLS[@]}"; do
  target_dir="${SKILLS_DIR}/${skill}"
  mkdir -p "${target_dir}"
  target="${target_dir}/SKILL.md"
  if [ -f "${target}" ]; then
    cp "${target}" "${HOOKS_DIR}/.backup/${skill}-SKILL.md.bak.${TS}"
  fi
  url="${REPO_BASE}/skills/${skill}/SKILL.md"
  if curl -fsSL "${url}" -o "${target}.tmp" 2>/dev/null; then
    mv "${target}.tmp" "${target}"
    log "  ✓ ${skill}"
    INSTALLED=$((INSTALLED + 1))
  else
    warn "  ✗ ${skill} (not found at ${url}; skipping)"
    rm -f "${target}.tmp"
    SKIPPED=$((SKIPPED + 1))
  fi
done

# --- /madd-ship phase sub-runbooks ---
log "Installing /madd-ship phase sub-runbooks..."
mkdir -p "${COMMANDS_DIR}/madd-ship-phases"
for phase in "${SHIP_PHASES[@]}"; do
  target="${COMMANDS_DIR}/madd-ship-phases/${phase}.md"
  url="${REPO_BASE}/commands/madd-ship-phases/${phase}.md"
  if curl -fsSL "${url}" -o "${target}.tmp" 2>/dev/null; then
    mv "${target}.tmp" "${target}"
    log "  ✓ madd-ship-phases/${phase}"
    INSTALLED=$((INSTALLED + 1))
  else
    warn "  ✗ madd-ship-phases/${phase} (not found; skipping)"
    rm -f "${target}.tmp"
    SKIPPED=$((SKIPPED + 1))
  fi
done

# --- /madd-init shape sub-runbooks ---
log "Installing /madd-init shape sub-runbooks..."
mkdir -p "${COMMANDS_DIR}/madd-init-shapes"
for shape in "${INIT_SHAPES[@]}"; do
  target="${COMMANDS_DIR}/madd-init-shapes/${shape}.md"
  url="${REPO_BASE}/commands/madd-init-shapes/${shape}.md"
  if curl -fsSL "${url}" -o "${target}.tmp" 2>/dev/null; then
    mv "${target}.tmp" "${target}"
    log "  ✓ madd-init-shapes/${shape}"
    INSTALLED=$((INSTALLED + 1))
  else
    warn "  ✗ madd-init-shapes/${shape} (not found; skipping)"
    rm -f "${target}.tmp"
    SKIPPED=$((SKIPPED + 1))
  fi
done

# --- Config ---
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

# --- Summary ---
echo
log "✓ MADD installed — ${INSTALLED} artifacts, ${SKIPPED} skipped"
echo
echo "Next steps:"
echo "  1. Restart Claude Code so commands/hooks/skills are surfaced"
echo "  2. In any project:"
echo "       /madd-init                       # Scaffold AGENTS.md + .claude/settings.json (registers MADD hooks)"
echo "       /madd-ship <feature description> # 8-phase delivery with state persistence + recall"
echo "       /madd-learn <feature-name>       # After shipping — capture to memory"
echo "       /madd-recall <keywords>          # Read back prior learnings"
echo "       /madd-status                     # Where am I in the ship?"
echo "       /madd-checkpoint                 # Snapshot before pivot"
echo "       /madd-rollback                   # Restore snapshot"
echo
echo "Phase discipline (hooks active after /madd-init):"
echo "  - madd-phase-guard       blocks feat: before Phase 3 RED + push before Phase 6 green"
echo "  - madd-commit-prefix     enforces schema:/stub:/test(red):/feat:/refactor:/fix:/Rollback:"
echo "  - madd-no-debug-code     rejects console.log/print/dbg!/debugger in non-test source"
echo
echo "Auto-trigger skills:"
echo "  - madd-ship-resume       offers resume when .madd-ship-state.json present"
echo "  - madd-pre-pr-check      runs /madd-review + /madd-secure before PR"
echo "  - madd-post-learn        prompts /madd-learn after merge"
echo
echo "Update later: /madd-update"
echo "Docs: https://github.com/sinholic/madd"
