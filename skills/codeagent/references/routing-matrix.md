# Backend Routing Quick-Reference Card

## Decision Tree

```
Task received from workflow skill
  │
  ├─ Has explicit backend: hint? ──→ Use specified backend
  │
  ├─ Has --agent preset? ──→ Use preset (bypasses routing)
  │
  ├─ Code-heavy task? ──→ codex
  │   (implementation, refactoring, debugging,
  │    algorithms, tests, performance)
  │
  ├─ Documentation task? ──→ claude
  │   (READMEs, specs, API docs, prompts,
  │    writing, structured output)
  │
  ├─ UI/Visual task? ──→ gemini
  │   (components, layouts, styling,
  │    design systems, accessibility)
  │
  └─ Ambiguous? ──→ codex (default)
```

## One-Line Summary

| If task is about... | Use |
|---------------------|-----|
| Code logic, refactoring, algorithms | `--backend codex` |
| Docs, writing, structured text | `--backend claude` |
| UI, layouts, design, accessibility | `--backend gemini` |
| Open-source models, local execution | `--backend opencode` |
| Agent preset from workflow | `--agent <name>` |
| Not sure | `--backend codex` |

## Fallback Chain

```
codex → claude → gemini → opencode
```

Never fall back to direct execution (Edit/Write tools).

## Config Precedence

```
CLI flag > agent preset > viper config > built-in default
```
