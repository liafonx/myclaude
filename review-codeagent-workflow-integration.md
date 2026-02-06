# Review Report: Workflow ↔ Codeagent Integration Guardrails

## Scope Reviewed

This review checks whether the current implementation satisfies your target design:

1. Workflow skills should **not** invoke `codeagent-wrapper` directly and bypass `codeagent`.
2. Workflow side should support a config-driven **preferred backend per task**.
3. `codeagent` side should support **preferred model and backend-related parameters**.

## Reviewed Files

- `skills/codeagent/hooks/hooks.json`
- `skills/codeagent/SKILL.md`
- `skills/codeagent/references/workflow-collaboration.md`
- `agent.md`
- `config.json`
- `skills/skill-rules.json`
- `codeagent-wrapper/internal/app/cli.go`
- `codeagent-wrapper/internal/config/agent.go`
- `codeagent-wrapper/internal/config/viper.go`
- `codeagent-wrapper/internal/backend/codex.go`
- `codeagent-wrapper/internal/backend/claude.go`
- `codeagent-wrapper/internal/backend/gemini.go`
- `codeagent-wrapper/internal/backend/opencode.go`

## Executive Summary

- Your current implementation **does not enforce** "workflow must go through codeagent" at runtime.
- You have **partial support** for backend/model preferences:
  - Task-level backend preference is possible (via `backend:`/`agent:` in invocation content), but not via a dedicated workflow config contract owned by this repo.
  - Backend/model preferences are strong via `~/.codeagent/models.json` and `~/.codeagent/config.yaml`, but backend-specific advanced params are limited.
- Documentation currently encourages direct workflow invocation of `codeagent-wrapper`, which conflicts with your new requirement.

## Findings

### [P1] Bypass prevention is not implemented

Current PreToolUse hook only checks that wrapper calls include one of `--backend`, `--agent`, or `--parallel`. It does **not** enforce "must be routed through codeagent skill."

- Evidence:
  - `skills/codeagent/hooks/hooks.json` allows any `codeagent-wrapper` call with those flags.
  - `skills/codeagent/references/workflow-collaboration.md` explicitly instructs workflow skills to invoke `codeagent-wrapper` directly.
  - `agent.md` collaboration contract describes direct workflow-to-wrapper invocation patterns.

Impact:
- Workflow skills can bypass routing logic and policy ownership in `codeagent`.

Status against requirement:
- **Not met.**

### [P1] Docs and policy contradict your intended architecture

Current docs position workflow skills as direct wrapper users.

- Evidence:
  - `skills/codeagent/references/workflow-collaboration.md` ("Two Ways to Invoke", examples calling wrapper directly).
  - `skills/codeagent/SKILL.md` includes direct invocation syntax intended for workflows.

Impact:
- Even if enforcement is added later, contributors will keep implementing bypass patterns due to existing docs.

Status against requirement:
- **Not met.**

### [P2] Workflow task→backend preference exists only as implicit pattern, not formal config contract

You can pass preferred backend per task today (`backend:` in parallel blocks or `--backend` for single task), but this is invocation-time only and not standardized as a workflow-owned config schema in this repo.

- Evidence:
  - `codeagent-wrapper/internal/app/cli.go` supports `--backend`.
  - `codeagent-wrapper/internal/executor/parallel_config.go` supports per-task `backend:` and `agent:`.
  - No dedicated workflow preference file/schema under this repo for task-classification -> backend mapping.

Impact:
- Different workflow skills may implement incompatible preference mechanisms.

Status against requirement:
- **Partially met** (mechanically possible, not formally defined/enforced).

### [P2] Codeagent model preference is supported, but backend-specific parameter coverage is limited

Model and some parameters are supported:

- `~/.codeagent/config.yaml`: global defaults (`backend`, `model`, `reasoning-effort`, etc.).
- `~/.codeagent/models.json`:
  - per-agent `backend`, `model`, `reasoning`, `prompt_file`, `allowed_tools`, `disallowed_tools`
  - per-backend `base_url`, `api_key`

However, there is no broad backend-parameter map (for example backend-specific temperature/top_p/max_tokens blocks).

- Evidence:
  - `codeagent-wrapper/internal/config/agent.go`
  - `codeagent-wrapper/internal/config/viper.go`
  - backend arg builders in `internal/backend/*.go` only consume limited fields.

Status against requirement:
- **Partially met** (model + key params yes; generalized backend param surface no).

### [P3] Skill rule enforcement mode is suggestive, not strict

- Evidence:
  - `skills/skill-rules.json` sets `"enforcement": "suggest"` for `codeagent`.

Impact:
- Router skill usage is advisory, not mandatory; bypass behavior is expected.

Status against requirement:
- **Not met** if strict routing is required.

## Feature Check Matrix

| Requested capability | Current state | Verdict |
|---|---|---|
| Block workflow direct wrapper calls | Hook only validates wrapper flag presence, not caller/policy | Not enabled |
| Workflow config for preferred backend per task | Possible ad hoc via `backend:`/`--backend`; no dedicated standardized config contract | Partially enabled |
| Codeagent preferred model per backend/task | Supported via `models.json` agent presets + defaults | Enabled (for model selection paths) |
| Backend-related parameter support | Limited to reasoning, base_url, api_key, tool allow/deny and backend-specific built-ins | Partially enabled |

## Recommended Direction (for your stated architecture)

1. Make `codeagent` the only documented invocation surface for workflow skills.
2. Replace direct wrapper examples in `workflow-collaboration.md` with "workflow emits routing request -> codeagent executes wrapper."
3. Tighten runtime policy:
   - Hook rule should deny direct `codeagent-wrapper` usage from workflow contexts and permit only approved routing entry pattern.
4. Introduce a workflow-side config contract in-repo (schema + example) for task-class -> preferred backend hint.
5. Keep model/parameter ownership in `~/.codeagent/models.json` and explicitly document which fields are honored per backend.

## Bottom Line

Your current implementation supports multi-backend execution well, but it still reflects a "workflow can call wrapper directly" model. For your target design (workflow must not bypass codeagent), enforcement and docs both need to be tightened. The backend/model preference capability is present in part, but workflow-level backend preference needs a formalized config contract.
