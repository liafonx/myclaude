#!/usr/bin/env bash
# route_subagent.sh
# Enforced entrypoint for workflow skills to run subagent tasks through codeagent-wrapper.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  route_subagent.sh [flags] -- <codeagent-wrapper args...>

Examples:
  route_subagent.sh -- --backend codex - /abs/project <<'TASK'
  Analyze repository structure and propose refactor plan.
  TASK

  route_subagent.sh -- --parallel <<'TASKS'
  ---TASK---
  id: analyze_1
  backend: codex
  workdir: /abs/project
  ---CONTENT---
  Analyze auth module.
  TASKS

Flags:
  -h, --help    Show this help.

Notes:
  - This script intentionally does not implement task classification.
  - Workflow skills should decide task + backend hint (or omit for defaults),
    then call this script as the single wrapper entrypoint.
  - Model and backend parameters are resolved by codeagent-wrapper from:
    ~/.codeagent/models.json and ~/.codeagent/config.yaml.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" != "--" ]]; then
  echo "ERROR: expected '--' before codeagent-wrapper args." >&2
  usage >&2
  exit 2
fi
shift

if [[ $# -eq 0 ]]; then
  echo "ERROR: missing codeagent-wrapper args." >&2
  usage >&2
  exit 2
fi

if ! command -v codeagent-wrapper >/dev/null 2>&1; then
  echo "ERROR: codeagent-wrapper not found on PATH." >&2
  exit 127
fi

exec codeagent-wrapper "$@"
