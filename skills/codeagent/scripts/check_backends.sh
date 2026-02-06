#!/usr/bin/env bash
# check_backends.sh — Check availability of codeagent-wrapper and all backends
# Usage: bash check_backends.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Codeagent Backend Availability Check ==="
echo ""

check_binary() {
    local name="$1"
    local cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        local version
        version=$("$cmd" --version 2>/dev/null | head -1 || echo "unknown version")
        echo -e "  ${GREEN}✓${NC} ${name}: $(command -v "$cmd") (${version})"
        return 0
    else
        echo -e "  ${RED}✗${NC} ${name}: not found on PATH"
        return 1
    fi
}

# Core binary
echo "Core:"
if ! check_binary "codeagent-wrapper" "codeagent-wrapper"; then
    echo -e "  ${YELLOW}→ Install: cd codeagent-wrapper && make install${NC}"
fi
echo ""

# Backends
echo "Backends:"
available=0
total=4

if check_binary "codex" "codex"; then available=$((available+1)); else echo -e "  ${YELLOW}→ Install: npm install -g @openai/codex${NC}"; fi
if check_binary "claude" "claude"; then available=$((available+1)); else echo -e "  ${YELLOW}→ Install: npm install -g @anthropic-ai/claude-code${NC}"; fi
if check_binary "gemini" "gemini"; then available=$((available+1)); else echo -e "  ${YELLOW}→ Install: see gemini CLI docs${NC}"; fi
if check_binary "opencode" "opencode"; then available=$((available+1)); else echo -e "  ${YELLOW}→ Install: see https://github.com/opencode-ai/opencode${NC}"; fi

echo ""
echo "=== ${available}/${total} backends available ==="

# Config files
echo ""
echo "Configuration:"
if [[ -f "${HOME}/.codeagent/config.yaml" ]]; then
    echo -e "  ${GREEN}✓${NC} config.yaml found"
else
    echo -e "  ${YELLOW}○${NC} config.yaml not found (will use defaults)"
fi

if [[ -f "${HOME}/.codeagent/models.json" ]]; then
    echo -e "  ${GREEN}✓${NC} models.json found"
else
    echo -e "  ${YELLOW}○${NC} models.json not found (will use defaults)"
fi

if [[ $available -eq 0 ]]; then
    echo ""
    echo -e "${RED}WARNING: No backends available. Install at least one backend before using codeagent-wrapper.${NC}"
    exit 1
fi
