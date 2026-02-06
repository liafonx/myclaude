# Workflow Skill Collaboration Guide

This document is for **workflow skill developers** and **orchestrator agents** (like `do`, `omo`, `sparv`) that need to create subagents through `codeagent-wrapper`. It explains what the codeagent routing skill handles for you, what it expects from you, and how to avoid common pitfalls.

## The Deal: Who Does What

```
┌─────────────────────────────────┐     ┌──────────────────────────────────┐
│        YOUR SKILL               │     │      CODEAGENT SKILL             │
│  (workflow / orchestrator)      │     │  (routing / invocation)          │
│                                 │     │                                  │
│  ✓ When to create subagents     │────▶│  ✓ Which backend to use          │
│  ✓ What task to give them       │     │  ✓ Correct CLI invocation        │
│  ✓ How many, in what order      │     │  ✓ HEREDOC formatting            │
│  ✓ Success/failure criteria     │     │  ✓ Fallback on backend failure   │
│  ✓ What to do with the output   │     │  ✓ Hook enforcement              │
│                                 │     │                                  │
│  ✗ Don't pick backends          │     │  ✗ Doesn't decide task content   │
│  ✗ Don't construct raw CLI      │     │  ✗ Doesn't decide when/how many  │
│  ✗ Don't write code directly    │     │  ✗ Doesn't judge output quality  │
└─────────────────────────────────┘     └──────────────────────────────────┘
```

## Two Ways to Invoke

### Option A: `--agent` preset (recommended for workflow skills)

Your skill defines named agent presets (e.g., `develop`, `code-explorer`, `oracle`). The preset already encodes which backend and model to use. **This bypasses routing logic entirely.**

```bash
codeagent-wrapper --agent develop - /project <<'EOF'
<task content>
EOF
```

This is what `do` and `omo` use. You stay in full control of backend selection via the preset definitions in `~/.codeagent/models.json`.

### Option B: `--backend` (let routing choose, or override explicitly)

If your skill wants codeagent to pick the backend based on task type:

```bash
codeagent-wrapper --backend codex - /project <<'EOF'
<task content>
EOF
```

You can also pass a `backend:` hint and let the routing skill's classification decide, or hardcode a backend when you know what you want.

### Option C: `--parallel` with per-task routing

For multiple tasks, each task block can specify its own `backend:` or `agent:`:

```bash
codeagent-wrapper --parallel <<'EOF'
---TASK---
id: explore_01
agent: code-explorer
workdir: /project
---CONTENT---
<exploration task>
---TASK---
id: implement_01
backend: codex
workdir: /project
dependencies: explore_01
---CONTENT---
<implementation task>
EOF
```

## What You Send (Input Contract)

Every subagent invocation needs at minimum:

| What | How | Required |
|------|-----|----------|
| Task content | HEREDOC body (the prompt/instructions) | ✅ Always |
| Working directory | Positional arg after `-` | ✅ Always |
| Backend or agent | `--backend <name>` or `--agent <name>` | ✅ Always (hook enforced) |
| Timeout | Bash tool `timeout: 7200000` | ✅ Always set 2h |
| Full output | `--full-output` flag | ❌ Only when you need complete response text in parallel mode |

### HEREDOC is mandatory for non-trivial tasks

Your task content will contain code blocks, quotes, `$variables`, backticks. Always use `<<'EOF'` (single-quoted delimiter prevents shell expansion):

```bash
# ✅ Correct
codeagent-wrapper --agent develop - /project <<'EOF'
Fix the type error in `src/parser.ts`:
- The `$data` variable is typed as `any`
- Change to `Record<string, unknown>`
EOF

# ❌ Wrong — shell will expand $data and break backticks
codeagent-wrapper --agent develop "Fix the type error in `src/parser.ts`, $data variable" /project
```

## What You Get Back (Output Contract)

### Single task

```
<full agent response text>

---
SESSION_ID: 019a7247-ac9d-71f3-89e2-a823dbd8fd14
```

The complete response is returned verbatim. No truncation. Parse the `SESSION_ID` line if you need resume capability.

### Parallel — default summary

```
=== Parallel Execution Summary ===
Total: 3 | Success: 2 | Failed: 1

--- Task: explore_01 ---
Status: SUCCESS
Session: 019xxx
<~150 char key output>

--- Task: implement_01 ---
Status: FAILED (exit code 1)
Error: <error message>
```

**Important**: Default summary compresses each task's output to ~150 chars (`KeyOutput`). If your workflow needs to parse or forward the full agent response to a later task, use `--full-output`.

### Parallel — full output

Same structure but includes complete agent messages per task. Use when:
- You need to pass one task's full output as context to the next
- You need to verify the agent actually did what was asked
- You're debugging a failing pipeline

## Hook Enforcement: What Gets Blocked

A PreToolUse hook runs on every Bash command containing `codeagent-wrapper`. It checks for `--backend`, `--agent`, or `--parallel` and **denies** the call if none are present.

**What this means for your skill:**
- `codeagent-wrapper --agent develop ...` → ✅ allowed
- `codeagent-wrapper --backend codex ...` → ✅ allowed
- `codeagent-wrapper --parallel ...` → ✅ allowed
- `codeagent-wrapper "do the thing" /project` → ❌ **DENIED**

Your skill never needs to worry about this if you always pass `--agent` or `--backend`.

## Fallback Behavior: What Happens on Failure

When a backend fails, the routing skill handles retry automatically:

```
1st failure → retry same backend
2nd failure → try next: codex → claude → gemini → opencode
All fail   → return error (NEVER falls back to direct code editing)
```

**Your responsibility**: Handle the returned error gracefully. Either:
- Retry with a narrower/simpler task
- Report the failure to the user
- **Never** fall back to writing code directly with Edit/Write tools

This is especially important for workflow skills like `do` that enforce "never switch to direct implementation."

## Passing Context Between Tasks

The most common collaboration pattern: one task's output feeds into the next.

### Pattern: Sequential with context forwarding

```bash
# Step 1: Explore
codeagent-wrapper --agent code-explorer - /project <<'EOF'
Find all usages of the AuthService class and map the dependency chain.
EOF

# Parse output, then...

# Step 2: Implement (passing explore output as context)
codeagent-wrapper --agent develop - /project <<'EOF'
## Context from exploration
<paste explore output here>

## Task
Refactor AuthService to use dependency injection based on the above analysis.
EOF
```

### Pattern: Parallel with dependencies

```bash
codeagent-wrapper --parallel <<'EOF'
---TASK---
id: explore_auth
agent: code-explorer
workdir: /project
---CONTENT---
Map AuthService dependencies

---TASK---
id: explore_db
agent: code-explorer
workdir: /project
---CONTENT---
Map DatabaseService dependencies

---TASK---
id: implement
agent: develop
workdir: /project
dependencies: explore_auth, explore_db
---CONTENT---
Refactor both services based on exploration results
EOF
```

Tasks with `dependencies:` wait for their dependencies to complete and receive their output automatically.

## Common Mistakes

### ❌ Constructing raw CLI without `--agent` or `--backend`
```bash
# Will be blocked by hook
codeagent-wrapper "implement feature X" /project
```

### ❌ Using `--parallel` with positional arguments
```bash
# --parallel reads ONLY from stdin
codeagent-wrapper --parallel - /project <<'EOF'  # ← wrong
```

### ❌ Running in background
```bash
# Never background codeagent-wrapper
codeagent-wrapper --agent develop - /project <<'EOF' &  # ← wrong
```

### ❌ Killing long-running tasks
Subagent tasks routinely take 2–10 minutes. If it seems stuck:
```bash
# Check it's running
ps aux | grep codeagent-wrapper | grep -v grep
# Check logs
tail -f /tmp/codeagent-*.log
```

### ❌ Expecting full output in parallel summary mode
Default parallel mode compresses output to ~150 chars. If you need the full response:
```bash
codeagent-wrapper --parallel --full-output <<'EOF'
...
EOF
```

## Resume: Continuing a Previous Session

If a task needs follow-up, use the session ID from the previous run:

```bash
codeagent-wrapper --backend codex resume 019a7247-ac9d-71f3-89e2-a823dbd8fd14 - <<'EOF'
The tests are still failing. Fix the edge case in parseConfig().
EOF
```

Or in parallel task blocks:
```yaml
---TASK---
id: followup_01
backend: codex
session_id: 019a7247-ac9d-71f3-89e2-a823dbd8fd14
---CONTENT---
Follow-up instructions...
```

## Checklist for New Workflow Skills

When building a new workflow skill that uses `codeagent-wrapper`:

- [ ] Every invocation has `--agent`, `--backend`, or `--parallel`
- [ ] All tasks use HEREDOC (`<<'EOF'`) for task content
- [ ] Bash tool timeout set to `7200000` (2 hours)
- [ ] Never run `codeagent-wrapper` in background
- [ ] Never fall back to direct Edit/Write if a backend fails
- [ ] Forward relevant context between sequential tasks
- [ ] Use `--full-output` if you need to parse parallel task responses
- [ ] Use absolute paths for `workdir` in parallel mode
- [ ] Task IDs follow `<action>_<timestamp>` convention in parallel mode
