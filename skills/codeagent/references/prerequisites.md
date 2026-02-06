# Codeagent Prerequisites

## Required: codeagent-wrapper binary

The `codeagent-wrapper` binary must be installed at `~/.claude/bin/codeagent-wrapper`.

### Installation

From the myclaude repository root:
```bash
bash install.sh
```

Or install directly via the Makefile:
```bash
cd codeagent-wrapper && make install
```

The binary is built from Go source in `codeagent-wrapper/` and supports 4 backends.

## Backend-Specific Requirements

### Codex (default)
- **Binary**: `codex` CLI must be on `$PATH`
- **Auth**: `OPENAI_API_KEY` environment variable or configured in `~/.codeagent/models.json`
- **Install**: `npm install -g @openai/codex`

### Claude
- **Binary**: `claude` CLI must be on `$PATH`
- **Auth**: Authenticated via `claude auth login` or API key in `~/.codeagent/models.json`
- **Install**: `npm install -g @anthropic-ai/claude-code`

### Gemini
- **Binary**: `gemini` CLI must be on `$PATH`
- **Auth**: `GEMINI_API_KEY` or `GOOGLE_API_KEY` environment variable
- **Install**: `npm install -g @anthropic-ai/claude-code` (Gemini mode) or native Gemini CLI

### OpenCode
- **Binary**: `opencode` must be on `$PATH`
- **Auth**: Configured per the opencode documentation
- **Install**: See https://github.com/opencode-ai/opencode

## Verification

Run the init script to check all backends:
```bash
bash "${SKILL_DIR}/scripts/init-codeagent.sh"
```

Or check manually:
```bash
which codeagent-wrapper && codeagent-wrapper --version
which codex && codex --version
which claude && claude --version
which gemini && gemini --version
which opencode && opencode --version
```
