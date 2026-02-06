---
name: codeagent
version: 1.0.1
description: Route subagent creation through codeagent-wrapper with intelligent backend selection. Analyzes task characteristics to choose the optimal backend (Codex/Claude/Gemini/OpenCode) and enforces correct invocation format. Use whenever a subagent needs to be created.
---

# Codeagent — Subagent Creation Routing

## Scope Boundary

This skill governs **backend routing and `codeagent-wrapper` invocation format** when creating subagents. It does NOT control:
- **When** to create subagents (workflow skill decides)
- **How many** subagents to create (workflow skill decides)
- **Task decomposition** or subtask definitions (workflow skill decides)
- **Expected outputs** or success criteria (workflow skill decides)

Always assume a workflow skill has already determined that a subagent is needed and what task it should perform. This skill's job is to route that task to the right backend and invoke `codeagent-wrapper` correctly.

## Backend Strength Matrix

| Backend | Flag | Strengths | Best For |
|---------|------|-----------|----------|
| **Codex** (default) | `--backend codex` | Deep code understanding, precise dependency tracking, algorithm optimization | Complex refactoring, large-scale code analysis, performance tuning |
| **Claude** | `--backend claude` | Quick reasoning, clear structured output, strong writing | Documentation, README generation, prompt engineering, quick feature impl |
| **Gemini** | `--backend gemini` | Visual/UI awareness, design system understanding, accessibility | UI scaffolding, layout prototyping, design-system implementation |
| **OpenCode** | `--backend opencode` | Open-source model flexibility, local execution | Alternative model access, cost optimization, air-gapped environments |

## Task → Backend Routing Procedure

When a subagent is requested, classify the task and select a backend in this priority order:

1. **Explicit override**: If the workflow skill provides a `backend:` hint or `--agent` preset → use it directly
2. **Code-heavy**: Task involves logic implementation, refactoring, debugging, algorithm work, test writing → `codex`
3. **Documentation**: Task involves docs, specs, READMEs, API descriptions, prompt authoring → `claude`
4. **UI/Visual**: Task involves UI components, layouts, styling, design systems, accessibility → `gemini`
5. **Ambiguous/Hybrid**: When task doesn't clearly fit one category → default to `codex`

This is a **priority-weighted guide**, not a strict type mapping. Real tasks are often hybrid — use your best judgment and allow workflow skills to override with explicit `backend:` hints.

## Invocation Contract

### Mandatory entrypoint (no direct wrapper calls from workflow skills)

Workflow skills MUST invoke subagents via:

```bash
~/.claude/skills/codeagent/scripts/route_subagent.sh -- <codeagent-wrapper args...>
```

Direct `codeagent-wrapper` invocations from workflow logic are blocked by hook policy.

### Single Task — HEREDOC (mandatory for complex tasks)

```bash
~/.claude/skills/codeagent/scripts/route_subagent.sh -- --backend <backend> - [working_dir] <<'EOF'
<task content here>
EOF
```

**Why HEREDOC?** Tasks often contain code blocks, nested quotes, shell metacharacters (`$`, `` ` ``, `\`), and multiline text. HEREDOC passes these safely without shell interpretation.

### With Agent Preset (bypasses classification, still routed through codeagent)

```bash
~/.claude/skills/codeagent/scripts/route_subagent.sh -- --agent <preset_name> - [working_dir] <<'EOF'
<task content here>
EOF
```

Agent presets are defined in `~/.codeagent/models.json` and encode backend + model + prompt.

### Resume Session

```bash
~/.claude/skills/codeagent/scripts/route_subagent.sh -- --backend <backend> resume <session_id> - <<'EOF'
<follow-up task>
EOF
```

### Invocation Rules

- **Workflow skills do not call `codeagent-wrapper` directly** — use `route_subagent.sh`.
- **`--backend`, `--agent`, or `--parallel` is REQUIRED** on wrapper args.
- **Foreground only** — never append `&`, never set `background: true`.
- **Bash tool timeout**: always set `timeout: 7200000` (2 hours).
- **HEREDOC for anything non-trivial** — prevents shell quoting issues.

### Workflow config for backend preference

Workflow skills can maintain task-type backend hints in their own config and pass resolved hints to this skill. Reference contract:

- `references/workflow-backend-preferences.md`

This skill consumes the resolved hint (`backend` or `agent`) and still owns wrapper invocation policy.

## Parallel Execution

For multiple independent or dependent tasks, use `--parallel` mode with per-task backend routing:

### Format

```bash
~/.claude/skills/codeagent/scripts/route_subagent.sh -- --parallel <<'EOF'
---TASK---
id: <unique_task_id>
backend: <backend>
workdir: /absolute/path
dependencies: <id1>, <id2>
---CONTENT---
<task content>
EOF
```

### Per-Task Backend Routing (core feature)

Each `---TASK---` block can specify its own `backend:` to route different subtasks to different backends:

```bash
~/.claude/skills/codeagent/scripts/route_subagent.sh -- --parallel <<'EOF'
---TASK---
id: analyze_1732876800
backend: codex
workdir: /home/user/project
---CONTENT---
analyze @spec.md and summarize API and UI requirements
---TASK---
id: docs_1732876801
backend: claude
dependencies: analyze_1732876800
---CONTENT---
generate API documentation based on analysis from analyze_1732876800
---TASK---
id: ui_1732876802
backend: gemini
dependencies: analyze_1732876800
---CONTENT---
create responsive dashboard layout based on UI requirements from analyze_1732876800
EOF
```

### Parallel Mode Rules

- `--parallel` reads task definitions **only from stdin** — no extra CLI arguments after `--parallel`
- Task ID convention: `<action>_<timestamp>` (e.g., `auth_1732876800`)
- Use **absolute paths** for `workdir`
- Dependencies enforce execution order via topological sorting
- Independent tasks run concurrently

**Correct:**
```bash
~/.claude/skills/codeagent/scripts/route_subagent.sh -- --parallel <<'EOF'
---TASK---
id: task1
backend: codex
workdir: /path/to/dir
---CONTENT---
task content
EOF
```

**Incorrect (will error):**
```bash
# Bad: no extra args after --parallel
~/.claude/skills/codeagent/scripts/route_subagent.sh -- --parallel - /path/to/dir <<'EOF'
...
EOF

# Bad: --parallel does not take a task argument
~/.claude/skills/codeagent/scripts/route_subagent.sh -- --parallel "task description"
```

### Delimiter Format Reference

- `---TASK---` — starts a new task block
- `id:` (required) — unique task identifier
- `backend:` (optional) — per-task backend override
- `workdir:` (optional) — working directory (default: `.`)
- `dependencies:` (optional) — comma-separated task IDs
- `session_id:` (optional) — resume a previous session
- `---CONTENT---` — separates metadata from task content

### Output Modes

- **Summary (default)**: Structured report with changes, key output (~150 chars), verification summary. Context-efficient for orchestration.
- **Full (`--full-output`)**: Complete task messages included. Use when debugging or when workflow needs full response text.

### Concurrency Control

Set `CODEAGENT_MAX_PARALLEL_WORKERS` to limit concurrent tasks (recommended: 8 for production).

## Fallback Policy

When a backend fails:
1. **First failure** → retry once with the same backend
2. **Second consecutive failure** → try next backend in fallback order: `codex → claude → gemini → opencode`
3. **Never fall back to direct execution** — always stay within `codeagent-wrapper`
4. Log `BACKEND_FALLBACK` with reason when switching backends

## Return Format

**Success:**
```
Agent response text here...

---
SESSION_ID: 019a7247-ac9d-71f3-89e2-a823dbd8fd14
```

**Error (stderr):**
```
ERROR: Error message
```

**Parallel summary:**
```
=== Parallel Execution Summary ===
Total: 3 | Success: 2 | Failed: 1

--- Task: task1 ---
Status: SUCCESS
Session: 019xxx
<key output>

--- Task: task2 ---
Status: FAILED (exit code 1)
Error: <error message>
```

Return only the final agent message and session ID — do not paste raw logs into the conversation.

## Output Length Caveats

- **Single-task mode**: No output truncation. Full backend response returned verbatim.
- **Parallel mode (default summary)**: Output compressed to structured fields — `KeyOutput` (~150 chars), `FilesChanged`, `Coverage`. Full agent messages are NOT included.
- **Parallel mode (`--full-output`)**: Complete agent messages included.
- **Recommendation**: Use `--full-output` when workflow needs to parse or verify the subagent's complete response. Use default summary when only pass/fail + changed files matter.
- **JSON line limit**: Individual backend events >10 MB are skipped (extremely rare).
- **Stderr**: Only last 4 KB captured for error reporting.

## Critical Rules

1. **NEVER kill codeagent-wrapper processes.** Long-running tasks are normal (2–10 min). Instead:
   - Check logs: `tail -f /tmp/codeagent-*.log`
   - Check process: `ps aux | grep codeagent-wrapper | grep -v grep`

2. **NEVER fall back to direct execution.** If a backend fails, retry or switch backends — never use Edit/Write tools directly as a substitute.

3. **Workflow skills must use `route_subagent.sh` (not direct `codeagent-wrapper`).** Wrapper args must still include one of `--backend`, `--agent`, or `--parallel`.

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `CODEX_TIMEOUT` | Override timeout in ms | `7200000` (2 hours) |
| `CODEAGENT_SKIP_PERMISSIONS` | Claude backend: skip permission checks (`true`/`1`) | disabled |
| `CODEAGENT_MAX_PARALLEL_WORKERS` | Limit concurrent parallel tasks | unlimited |

## User Configuration

Two config files control defaults:

**`~/.codeagent/config.yaml`** — global defaults:
```yaml
backend: codex          # default backend when no --backend flag
model: ""               # default model (empty = backend's default)
reasoning_effort: ""    # low/medium/high
skip_permissions: false # Claude backend permission checks
full_output: false      # parallel mode: summary (false) vs full (true)
```

**`~/.codeagent/models.json`** — agent presets and backend API config:
```json
{
  "default_backend": "codex",
  "default_model": "gpt-4.1",
  "backends": {
    "codex": { "api_key": "..." },
    "claude": { "api_key": "..." }
  },
  "agents": {
    "develop": {
      "backend": "codex",
      "model": "gpt-4.1",
      "prompt_file": "~/.codeagent/prompts/develop.md",
      "reasoning": "high"
    }
  }
}
```

**Config precedence** (highest → lowest):
1. CLI flag (`--backend`, `--model`)
2. Agent preset (`--agent` → `models.json` agents section)
3. Viper config (`config.yaml` or `CODEAGENT_*` env vars)
4. Built-in default (`codex`, empty model)

## Security Best Practices

- **Claude Backend**: Permission checks enabled by default. Set `CODEAGENT_SKIP_PERMISSIONS=true` only for trusted automation.
- **Concurrency Limits**: Set `CODEAGENT_MAX_PARALLEL_WORKERS` in production to prevent resource exhaustion.
- **API Keys**: Store in `~/.codeagent/models.json` (file permissions should be `600`).
