# Workflow Backend Preference Contract

This document defines a lightweight config contract that workflow skills can use to choose preferred backends per task type before delegating to `codeagent`.

## Purpose

- Workflow layer owns: task decomposition and task typing.
- Codeagent layer owns: wrapper invocation and execution policy.

Workflow resolves a preferred backend from this config and passes the hint to codeagent (`backend` or `agent`).

## Suggested Config Shape

```json
{
  "default_backend": "codex",
  "task_type_backend": {
    "implementation": "codex",
    "refactor": "codex",
    "research": "claude",
    "documentation": "claude",
    "ui": "gemini",
    "fallback": "opencode"
  },
  "task_type_agent": {
    "critical_fix": "develop"
  }
}
```

## Resolution Order

1. Explicit task override (`backend`/`agent`) from workflow runtime input.
2. `task_type_agent[task_type]` (if present).
3. `task_type_backend[task_type]` (if present).
4. `default_backend`.
5. Codeagent internal default (`codex`) if none provided.

## Model and Parameter Ownership

Workflow backend preference does not define backend runtime internals. Model and backend parameters remain in user-level codeagent config:

- `~/.codeagent/models.json` for agent presets and backend credentials/endpoints.
- `~/.codeagent/config.yaml` for global defaults (backend/model/reasoning/full_output).
