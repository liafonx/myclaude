# Agent Collaboration Contract: Codeagent Routing

This document defines the interface between **workflow skills** (e.g., `do`, `omo`, `sparv`) and the **codeagent routing skill**.

## Roles

| Role | Responsibility | Example Skills |
|------|---------------|----------------|
| **Workflow skill** | Decides **when** to create subagents, **what** tasks, **how many**, success criteria | `do`, `omo`, `sparv` |
| **Routing skill** | Decides **which backend** to use and **how** to invoke `codeagent-wrapper` correctly | `codeagent` |

## Handoff Protocol

### Workflow → Routing (Input)

When a workflow skill requests a subagent, it provides:

| Field | Required | Description |
|-------|----------|-------------|
| `task` | ✅ | The task content / prompt for the subagent |
| `working_dir` | ✅ | Absolute path to the working directory |
| `backend` | ❌ | Explicit backend hint (overrides routing logic) |
| `agent` | ❌ | Agent preset name (bypasses routing entirely) |
| `full_output` | ❌ | Request full output instead of summary (parallel mode) |

### Routing → Workflow (Output)

The routing skill returns:

| Field | Always | Description |
|-------|--------|-------------|
| `response` | ✅ | Agent's response text (or summary in parallel mode) |
| `session_id` | ✅ | Session ID for resume capability |
| `exit_code` | ✅ | 0 = success, non-zero = failure |
| `error` | On failure | Error message from stderr |
| `backend_used` | ✅ | Which backend actually handled the task |
| `fallback_occurred` | If applicable | Whether a fallback was triggered and why |

### Parallel Mode Output

In parallel mode, each task returns a structured summary:

| Field | Description |
|-------|-------------|
| `status` | SUCCESS or FAILED |
| `session_id` | Per-task session ID |
| `key_output` | ~150 char summary (default mode) |
| `files_changed` | List of modified files |
| `full_message` | Complete response (only with `--full-output`) |

## Output Length Contract

| Mode | Output Behavior | When to Use |
|------|----------------|-------------|
| Single task | Full verbatim response, no truncation | Default for all single-task invocations |
| Parallel (summary) | Compressed: KeyOutput ~150 chars, FilesChanged, Coverage | When only pass/fail + changes matter |
| Parallel (`--full-output`) | Complete agent messages per task | When workflow needs to parse/verify full response |

**Workflow skills should specify `--full-output` when they need the complete subagent response.**

## Hook Behavior

The codeagent skill installs a **PreToolUse hook on Bash** that:
- **Validates** every `codeagent-wrapper` call has `--backend` or `--agent`
- **Denies** calls without these flags with an explanatory message
- **Ignores** non-codeagent-wrapper Bash commands entirely

Workflow skills using `--agent <preset>` are unaffected — the hook recognizes `--agent` as valid.

## Fallback Policy

```
retry same backend → try next in chain → NEVER direct execution
                                          codex → claude → gemini → opencode
```

This aligns with workflow skills like `do` that enforce "never switch to direct implementation."

## Examples

### Workflow skill with explicit backend hint
```
Workflow: "Create a subagent for this refactoring task, use codex backend"
Routing:  codeagent-wrapper --backend codex - /project <<'EOF'
          <task content>
          EOF
```

### Workflow skill deferring to routing logic
```
Workflow: "Create a subagent for this documentation task"
Routing:  (classifies as "documentation" → selects claude)
          codeagent-wrapper --backend claude - /project <<'EOF'
          <task content>
          EOF
```

### Workflow skill with agent preset
```
Workflow: "Use the 'develop' agent for this task"
Routing:  codeagent-wrapper --agent develop - /project <<'EOF'
          <task content>
          EOF
```

## Adding New Backends

When a new backend is added to `codeagent-wrapper`:
1. Add it to the Backend Strength Matrix in `skills/codeagent/SKILL.md`
2. Add it to the routing procedure
3. Add it to the fallback chain
4. Update `check_backends.sh` to verify availability
5. Update this contract if it changes the output format
