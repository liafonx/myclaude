# Workflow Skill Collaboration Guide

This guide defines how workflow skills collaborate with `codeagent` without bypassing routing policy.

## Hard Rule: No Direct Wrapper Calls From Workflow

Workflow skills MUST NOT invoke `codeagent-wrapper` directly.

Use the sanctioned entrypoint:

```bash
~/.claude/skills/codeagent/scripts/route_subagent.sh -- <codeagent-wrapper args...>
```

The PreToolUse hook blocks direct `codeagent-wrapper` commands.

## Responsibility Split

| Workflow skill owns | Codeagent owns |
|---|---|
| When to create subagents | Backend classification and invocation policy |
| Task decomposition and ordering | Safe wrapper invocation format |
| Success criteria and result validation | HEREDOC/parallel command correctness |
| Task-type backend preference config | Wrapper execution path |

## Input Contract (Workflow -> Codeagent)

Workflow passes a resolved routing request with:

- `task`: required subagent task text
- `working_dir`: required absolute path
- `task_type`: optional classification key (for workflow-side preference map)
- `backend`: optional explicit backend hint (overrides classification)
- `agent`: optional preset name (bypasses classification)
- `model`: optional model override
- `reasoning_effort`: optional reasoning level
- `parallel`: optional task block payload for `--parallel`
- `full_output`: optional parallel output mode

## Workflow Backend Preferences

Workflow skills can define backend preference maps by task type (owned by workflow layer). Codeagent consumes the resolved hint and applies invocation policy.

Reference:

- `skills/codeagent/references/workflow-backend-preferences.md`

## Model and Backend Parameters

Codeagent-wrapper resolves model/backend parameters from:

1. CLI flags (`--model`, etc.)
2. Agent preset (`--agent`) in `~/.codeagent/models.json`
3. Global defaults in `~/.codeagent/config.yaml`

Use these for preferred model and backend-level credentials/endpoints:

- `~/.codeagent/models.json`: `agents.*.model`, `agents.*.reasoning`, `backends.*.base_url`, `backends.*.api_key`
- `~/.codeagent/config.yaml`: `backend`, `model`, `reasoning_effort`, `skip_permissions`, `full_output`

## Routed Invocation Examples

### Single task

```bash
~/.claude/skills/codeagent/scripts/route_subagent.sh -- --backend codex - /abs/project <<'EOF'
Analyze the auth module and propose a refactor sequence.
EOF
```

### Agent preset

```bash
~/.claude/skills/codeagent/scripts/route_subagent.sh -- --agent develop - /abs/project <<'EOF'
Implement pagination for the endpoint and add tests.
EOF
```

### Parallel

```bash
~/.claude/skills/codeagent/scripts/route_subagent.sh -- --parallel <<'EOF'
---TASK---
id: analyze_1732876800
backend: codex
workdir: /abs/project
---CONTENT---
Analyze API boundaries.

---TASK---
id: docs_1732876801
backend: claude
dependencies: analyze_1732876800
workdir: /abs/project
---CONTENT---
Document API changes from analyze_1732876800.
EOF
```

## Compliance Checklist

- Workflow never calls `codeagent-wrapper` directly.
- Workflow always routes through `route_subagent.sh`.
- Workflow provides absolute `working_dir`.
- Workflow defines/uses a task-type -> backend preference map where needed.
- Model and backend params are configured via `~/.codeagent/config.yaml` and `~/.codeagent/models.json`.
