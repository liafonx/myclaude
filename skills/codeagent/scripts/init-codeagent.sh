#!/usr/bin/env bash
# init-codeagent.sh — First-use setup for codeagent skill
# Scaffolds config directory and checks backend availability
# Usage: bash "${SKILL_DIR}/scripts/init-codeagent.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.codeagent"

echo "=== Codeagent Init ==="
echo ""

# 1. Create config directory
if [[ ! -d "$CONFIG_DIR" ]]; then
    mkdir -p "$CONFIG_DIR"
    echo "Created config directory: $CONFIG_DIR"
else
    echo "Config directory exists: $CONFIG_DIR"
fi

# 2. Scaffold config.yaml if missing
if [[ ! -f "$CONFIG_DIR/config.yaml" ]]; then
    if [[ -f "$SCRIPT_DIR/../templates/config.yaml" ]]; then
        cp "$SCRIPT_DIR/../templates/config.yaml" "$CONFIG_DIR/config.yaml"
        echo "Scaffolded config.yaml from template"
    else
        cat > "$CONFIG_DIR/config.yaml" << 'YAML'
# codeagent-wrapper global configuration
# See: skills/codeagent/SKILL.md → User Configuration

backend: codex          # default backend: codex | claude | gemini | opencode
model: ""               # default model (empty = backend's default)
reasoning_effort: ""    # low | medium | high (empty = backend's default)
skip_permissions: false # Claude backend: skip permission prompts
full_output: false      # parallel mode: summary (false) or full output (true)
YAML
        echo "Created default config.yaml"
    fi
else
    echo "config.yaml already exists (skipped)"
fi

# 3. Scaffold models.json if missing
if [[ ! -f "$CONFIG_DIR/models.json" ]]; then
    if [[ -f "$SCRIPT_DIR/../templates/models.json" ]]; then
        cp "$SCRIPT_DIR/../templates/models.json" "$CONFIG_DIR/models.json"
        echo "Scaffolded models.json from template"
    else
        cat > "$CONFIG_DIR/models.json" << 'JSON'
{
  "default_backend": "codex",
  "default_model": "",
  "backends": {},
  "agents": {}
}
JSON
        echo "Created default models.json"
    fi
    chmod 600 "$CONFIG_DIR/models.json"
    echo "Set models.json permissions to 600"
else
    echo "models.json already exists (skipped)"
fi

echo ""

# 4. Check backend availability
bash "$SCRIPT_DIR/check_backends.sh"

echo ""
echo "=== Init complete ==="
echo "Edit $CONFIG_DIR/config.yaml to set your default backend."
echo "Edit $CONFIG_DIR/models.json to configure agent presets and API keys."
