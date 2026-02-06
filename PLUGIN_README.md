# Plugin System

Claude Code plugins for this repo are defined in `.claude-plugin/marketplace.json`.

This repository is currently maintained with a **codeagent-first** focus:
- Primary skill/runtime: `skills/codeagent` + `codeagent-wrapper`
- Other plugin/skill assets remain for historical collaboration-routing reference

## Install

```bash
/plugin marketplace add liafonx/myclaude
/plugin list
```

## Available Plugins

- `codeagent` (primary focus) - backend routing and invocation layer via `codeagent-wrapper`
- Legacy plugin entries in `marketplace.json` are preserved as reference assets
