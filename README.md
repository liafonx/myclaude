[中文](README_CN.md) [English](README.md)

# Codeagent Routing Toolkit

[![Run in Smithery](https://smithery.ai/badge/skills/cexll)](https://smithery.ai/skills?ns=cexll&utm_source=github&utm_medium=badge)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blue)](https://claude.ai/code)
[![Version](https://img.shields.io/badge/Version-6.x-green)](https://github.com/liafonx/myclaude)

> Single-skill subagent routing with `codeagent` + `codeagent-wrapper` (Codex/Claude/Gemini/OpenCode)

## Quick Start

```bash
npx github:liafonx/myclaude
```

## Core Focus

This repository is centered on:
- `skills/codeagent` - the single routing skill for subagent backend selection and invocation
- `codeagent-wrapper` - multi-backend execution binary and runtime

Other skills are kept in-tree as **collaboration routing references** only. They are not the primary install surface.

## Installation and Configuration

```bash
# Interactive installer (installs default codeagent module)
npx github:liafonx/myclaude

# Detect installed modules and update from GitHub
npx github:liafonx/myclaude --update

# Custom install directory / overwrite
npx github:liafonx/myclaude --install-dir ~/.claude --force

# Install from your own fork/repo release source
npx github:liafonx/myclaude --repo <your-owner>/<your-repo>
```

`--update` detects already installed modules in the target install dir (defaults to `~/.claude`, via `installed_modules.json` when present) and updates codeagent files from the selected repo.

Default install/list uses the package contents from the exact repo/ref you ran with `npx github:<owner>/<repo>`.
`codeagent-wrapper` is always downloaded from `cexll/myclaude` releases unless you override `CODEAGENT_WRAPPER_REPO`.

### Module Configuration

`config.json` is intentionally codeagent-centric:

```json
{
  "modules": {
    "codeagent": { "enabled": true }
  }
}
```

### Runtime Prerequisites

- `codeagent-wrapper` binary (installed by this repo installer)
- Backend CLIs installed separately:
  - `codex`
  - `claude`
  - `gemini`
  - `opencode` (optional)

Use:
```bash
bash ~/.claude/skills/codeagent/scripts/check_backends.sh
```
to verify local availability.

### Configure Default Model and Parameters

`codeagent-wrapper` reads defaults from:

- `~/.codeagent/config.yaml` (global defaults)
- `~/.codeagent/models.json` (agent presets + backend API config)

Example `~/.codeagent/config.yaml`:

```yaml
backend: codex
model: gpt-4.1
reasoning-effort: high
skip-permissions: false
full-output: false
```

Example `~/.codeagent/models.json`:

```json
{
  "default_backend": "codex",
  "default_model": "gpt-4.1",
  "backends": {
    "codex": {
      "base_url": "https://api.openai.com/v1",
      "api_key": "YOUR_OPENAI_KEY"
    },
    "claude": {
      "base_url": "https://api.anthropic.com",
      "api_key": "YOUR_ANTHROPIC_KEY"
    },
    "gemini": {
      "api_key": "YOUR_GEMINI_KEY"
    }
  },
  "agents": {
    "develop": {
      "backend": "codex",
      "model": "gpt-4.1",
      "reasoning": "high",
      "prompt_file": "~/.codeagent/prompts/develop.md"
    },
    "doc-writer": {
      "backend": "claude",
      "model": "claude-sonnet-4",
      "reasoning": "medium"
    }
  }
}
```

Config precedence (high -> low):

1. CLI flags (`--backend`, `--model`, `--reasoning-effort`)
2. `--agent` preset from `models.json`
3. `config.yaml` and `CODEAGENT_*` env vars
4. Built-in defaults

Backend parameter notes:

- Codex: supports `model` and `reasoning-effort`.
- Claude: supports `model`, `skip-permissions`, and backend `base_url`/`api_key`.
- Gemini: supports `model` and backend `base_url`/`api_key` (also reads `~/.gemini/.env`).
- OpenCode: supports `model`.

## Core Architecture

| Role | Agent | Responsibility |
|------|-------|----------------|
| **Orchestrator** | Claude Code | Planning, context gathering, verification |
| **Router Skill** | codeagent | Backend selection + invocation format (`--backend` / `--agent`) |
| **Executor** | codeagent-wrapper | Code editing, test execution (Codex/Claude/Gemini/OpenCode) |

## Backend CLI Requirements

| Backend | Required Features |
|---------|-------------------|
| Codex | `codex e`, `--json`, `-C`, `resume` |
| Claude | `--output-format stream-json`, `-r` |
| Gemini | `-o stream-json`, `-y`, `-r` |
| OpenCode | `opencode run --format json` |

## Directory Structure After Installation

```
~/.claude/
├── bin/codeagent-wrapper
├── CLAUDE.md
├── commands/
├── agents/
├── skills/
└── config.json
```

## Documentation

- [codeagent-wrapper](codeagent-wrapper/README.md)
- [Agent Collaboration Contract](agent.md) — workflow ↔ routing skill interface
- [skills/codeagent/SKILL.md](skills/codeagent/SKILL.md) — routing behavior and invocation rules
- [Plugin System](PLUGIN_README.md)

## Troubleshooting

### Common Issues

**Codex wrapper not found:**
```bash
# Select: codeagent-wrapper
npx github:liafonx/myclaude
```

**Module not loading:**
```bash
cat ~/.claude/installed_modules.json
npx github:liafonx/myclaude --force
```

**Backend CLI errors:**
```bash
which codex && codex --version
which claude && claude --version
which gemini && gemini --version
which opencode && opencode --version
```

## FAQ

| Issue | Solution |
|-------|----------|
| "Unknown event format" | Logging display issue, can be ignored |
| Gemini can't read .gitignore files | Remove from .gitignore or use different backend |
| Codex permission denied | Set `approval_policy = "never"` in ~/.codex/config.yaml |

See [GitHub Issues](https://github.com/liafonx/myclaude/issues) for more.

## License

AGPL-3.0 - see [LICENSE](LICENSE)

### Commercial Licensing

For commercial use without AGPL obligations, contact: evanxian9@gmail.com

## Support

- [GitHub Issues](https://github.com/liafonx/myclaude/issues)
