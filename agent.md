# Agent Development Guide

This document is the onboarding reference for any agent taking over development tasks in this repository.

## What This Repo Is

A **codeagent-first subagent routing toolkit** for Claude Code. It provides:
- **`skills/codeagent`** — the single routing skill that tells agents how to invoke `codeagent-wrapper` with the right backend
- **`codeagent-wrapper`** — a Go binary that dispatches tasks to backend CLIs (Codex, Claude, Gemini, OpenCode)
- **`bin/cli.js` + `install.py`** — dual installers (JS for `npx`, Python fallback) that copy skills, merge hooks into `~/.claude/settings.json`, and install the binary

Other skills in-tree (`do`, `omo`, `sparv`, `browser`, etc.) are **collaboration references** — they should route subagent execution through `skills/codeagent/scripts/route_subagent.sh` and are not the primary install surface of this fork.

**Upstream**: `cexll/myclaude` — this fork (`liafonx/myclaude`) focuses on the codeagent routing skill; `codeagent-wrapper` binary is sourced from upstream releases.

## Repository Layout

```
.
├── agent.md                    ← YOU ARE HERE
├── config.json                 ← Module registry (what gets installed)
├── package.json                ← npx entry point → bin/cli.js
├── bin/cli.js                  ← JS installer (npx github:liafonx/myclaude)
├── install.py                  ← Python installer (fallback)
├── install.sh                  ← Binary installer (downloads codeagent-wrapper)
├── skills/
│   ├── codeagent/              ← PRIMARY — the routing skill
│   │   ├── SKILL.md            ← Skill definition (frontmatter + routing rules)
│   │   ├── hooks/hooks.json    ← PreToolUse hook (merged into settings.json)
│   │   ├── scripts/            ← check_backends.sh
│   │   └── references/         ← prerequisites.md, routing-matrix.md
│   ├── do/                     ← Workflow skill (uses --agent presets)
│   ├── omo/                    ← Workflow skill (uses --agent presets)
│   ├── sparv/                  ← Workflow skill (SPARV methodology)
│   ├── skill-rules.json        ← Trigger keywords (repo-only, not installed)
│   └── ...                     ← Other reference skills
├── codeagent-wrapper/          ← Go source for the binary
│   ├── cmd/codeagent-wrapper/  ← Entry point (main.go)
│   └── internal/               ← app/, backend/, config/, executor/, parser/
├── scripts/
│   └── upstream-sync/          ← Sync pipeline (check, diff, apply)
├── sync/
│   ├── INIT_UPSTREAM_SYNC.md   ← One-time setup doc
│   ├── upstream-sync.config.json ← Path scopes + protected paths
│   └── status/                 ← Machine + human reports
├── agents/                     ← Slash-command agent definitions (bmad, etc.)
└── memorys/                    ← CLAUDE.md memory files
```

## Install Flow (What Happens on `npx github:liafonx/myclaude`)

1. `bin/cli.js` reads `config.json` → finds enabled modules
2. For `codeagent` module:
   - `copy_dir: skills/codeagent` → `~/.claude/skills/codeagent/`
   - Auto-discovers `hooks/hooks.json` inside the copied dir
   - Merges hook entries into `~/.claude/settings.json` under `hooks.PreToolUse[]`
   - `run_command: bash install.sh` → downloads `codeagent-wrapper` to `~/.claude/bin/`
3. Records installed modules in `~/.claude/installed_modules.json`

**Key mechanism**: Hooks are NOT manually registered. Both installers automatically scan any `copy_dir` target for `hooks/hooks.json` and merge it into settings.

## Key Files to Know Before Editing

| File | What it controls | Edit impact |
|------|-----------------|-------------|
| `skills/codeagent/SKILL.md` | Backend routing rules, invocation syntax, fallback policy | Changes what agents see when using the skill |
| `skills/codeagent/hooks/hooks.json` | PreToolUse enforcement (must use `--backend`/`--agent`/`--parallel`) | Changes runtime enforcement in `~/.claude/settings.json` |
| `config.json` | Which modules are installable and enabled by default | Changes what `npx` installs |
| `bin/cli.js` | Installer logic (copy, hooks merge, update, `--repo` flag) | Changes install behavior |
| `install.py` | Python installer (mirrors cli.js logic) | Must stay in sync with cli.js |
| `install.sh` | Binary download script | Changes how `codeagent-wrapper` is fetched |
| `codeagent-wrapper/` | Go source for the binary | Changes runtime execution of all backends |

## Development Conventions

### Skill Format
Skills use YAML frontmatter + markdown body:
```yaml
---
name: skill-name
version: 1.0.0
description: What it does
---
# Skill content (markdown)
```

`allowed-tools` in frontmatter grants the skill permission to run specific scripts.

### Hook Format
Hooks must be **object-keyed** (not array-shaped) to be recognized by both installers:
```json
{
  "description": "human-readable note",
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "prompt", "prompt": "..." }] }
    ]
  }
}
```
Reference working examples: `skills/do/hooks/hooks.json`, `skills/sparv/hooks/hooks.json`.

### Config Module Format
Each module in `config.json` has `enabled`, `description`, and `operations[]`:
- `copy_dir` — copies a skill directory (triggers auto hook merge)
- `copy_file` — copies a single file
- `run_command` — runs a shell command
- `merge_dir` — merges into existing dirs (for agents/commands)

### Installer Parity
`bin/cli.js` and `install.py` must implement the same logic. When changing install behavior, update both. Key parallel functions:

| cli.js | install.py | Purpose |
|--------|-----------|---------|
| `mergeHooksToSettings()` | `merge_hooks_to_settings()` | Merge hooks into settings.json |
| `mergeModuleHooks()` | `find_module_hooks()` | Discover hooks.json in copy_dir targets |
| `unmergeHooksFromSettings()` | `unmerge_hooks_from_settings()` | Clean up on uninstall |

### Wrapper Development
The Go binary lives in `codeagent-wrapper/`. Build and test:
```bash
cd codeagent-wrapper && make build    # builds binary
cd codeagent-wrapper && make test     # runs tests
cd codeagent-wrapper && make install  # installs to ~/.claude/bin/
```

**Do not modify `codeagent-wrapper/` unless working on binary features.** This fork sources the binary from upstream `cexll/myclaude` releases — wrapper changes should be upstreamed.

## Collaboration Contract: Workflow ↔ Routing

### Roles

| Role | Responsibility | Examples |
|------|---------------|----------|
| **Workflow skill** | Decides **when** to create subagents, **what** tasks, **how many**, success criteria | `do`, `omo`, `sparv` |
| **Routing skill** | Decides **which backend** and enforces routed invocation via `route_subagent.sh` | `codeagent` |

### Workflow → Routing (Input)

| Field | Required | Description |
|-------|----------|-------------|
| `task` | ✅ | Task content / prompt for the subagent |
| `working_dir` | ✅ | Absolute path to working directory |
| `task_type` | ❌ | Workflow classification key for backend preference lookup |
| `backend` | ❌ | Explicit backend hint (overrides routing) |
| `agent` | ❌ | Agent preset name (bypasses routing) |
| `model` | ❌ | Optional model override |
| `reasoning_effort` | ❌ | Optional reasoning override |
| `full_output` | ❌ | Request full output in parallel mode |

### Routing → Workflow (Output)

| Field | Always | Description |
|-------|--------|-------------|
| `response` | ✅ | Agent's text (or summary in parallel) |
| `session_id` | ✅ | Session ID for resume |
| `exit_code` | ✅ | 0 = success |
| `backend_used` | ✅ | Which backend ran the task |
| `error` | On failure | stderr message |

### Parallel Mode Output

| Mode | Behavior |
|------|----------|
| Default summary | KeyOutput ~150 chars, FilesChanged, Coverage per task |
| `--full-output` | Complete agent messages per task |

### Fallback Chain

```
retry same → codex → claude → gemini → opencode → NEVER direct execution
```

### Hook Enforcement

Direct `codeagent-wrapper` invocation is blocked. Workflow skills must call:

`~/.claude/skills/codeagent/scripts/route_subagent.sh -- <wrapper args>`

## Common Development Tasks

### Adding/modifying the codeagent skill
1. Edit `skills/codeagent/SKILL.md`
2. Test by reinstalling: `npx github:liafonx/myclaude --force`
3. Verify hook still merges: check `~/.claude/settings.json`

### Adding a new backend to routing
1. Add to Backend Strength Matrix in `skills/codeagent/SKILL.md`
2. Add to routing procedure priority list
3. Add to fallback chain
4. Add check in `skills/codeagent/scripts/check_backends.sh`
5. Update this document's collaboration contract

### Changing hook behavior
1. Edit `skills/codeagent/hooks/hooks.json`
2. Ensure format is object-keyed (see Hook Format above)
3. Reinstall to re-merge: `npx github:liafonx/myclaude --force`
4. Verify in `~/.claude/settings.json` → `hooks.PreToolUse`

### Changing what gets installed
1. Edit `config.json` → add/modify module operations
2. Mirror any install logic changes in both `bin/cli.js` AND `install.py`
3. Test with `npx github:liafonx/myclaude --force`

## Manual Upstream Sync (Maintainer)

This fork tracks `cexll/myclaude` releases manually via the `upstream-sync` maintainer skill. **No automation, no scheduled jobs, no auto-PRs.**

#### How it works

A maintainer (or agent asked to "update upstream") runs a 3-step pipeline:

1. **Detect** — `scripts/upstream-sync/check_latest_release.sh` queries the GitHub API for the latest release tag from `cexll/myclaude`.
2. **Diff** — `scripts/upstream-sync/compute_diff.sh --tag <tag>` computes drift between fork HEAD and the upstream tag for configured paths. Writes machine-readable status and a human-readable report.
3. **Apply** — `scripts/upstream-sync/apply_update.sh --tag <tag>` checks out upstream files into a `sync/upstream-v<tag>` branch and commits. The maintainer then opens a PR manually.

The skill at `skills/upstream-sync/SKILL.md` orchestrates this sequence with a required confirmation step between diff and apply.

#### Path scopes

Configured in `sync/upstream-sync.config.json`:

| Scope | Paths | Behavior |
|-------|-------|----------|
| **Apply** | `codeagent-wrapper/` | Upstream files overwrite fork on apply |
| **Signal-only** | `skills/codeagent/`, `skills/codex/`, `skills/gemini/` | Drift reported but never auto-applied (fork-owned) |
| **Protected** | `bin/cli.js`, `config.json`, `README.md`, `agent.md`, installers | Blocked from staging even if upstream changes them |

`skills/codeagent/` is signal-only because it has been fully rewritten in this fork. If upstream changes those files, review the drift report and cherry-pick manually.

#### Key files

| File | Purpose |
|------|---------|
| `sync/INIT_UPSTREAM_SYNC.md` | One-time setup (add `upstream` remote, fetch tags) |
| `skills/upstream-sync/SKILL.md` | Maintainer skill definition (agent reads this) |
| `skills/upstream-sync/references/runbook.md` | Detailed operational runbook |
| `scripts/upstream-sync/check_latest_release.sh` | Queries GitHub API for latest release |
| `scripts/upstream-sync/compute_diff.sh` | Computes drift, writes status + report |
| `scripts/upstream-sync/apply_update.sh` | Applies sync paths on a branch, commits |
| `sync/upstream-sync.config.json` | Path scopes, branch prefix, protected paths |
| `sync/status/upstream-sync-status.json` | Machine-readable last-check state |
| `sync/status/upstream-sync-report.md` | Human-readable drift/apply report |

#### GitHub API auth

`check_latest_release.sh` picks up `GITHUB_TOKEN` or `GH_TOKEN` from the environment for authenticated requests (5000 req/hr). Without a token, unauthenticated rate limit is 60 req/hr.

## Testing Locally Before Push
```bash
# Verify JSON validity
python3 -m json.tool config.json > /dev/null
python3 -m json.tool skills/codeagent/hooks/hooks.json > /dev/null

# Check no stale references
grep -rn "skills/codex\|skills/gemini" --include="*.json" --include="*.md" . | grep -v node_modules | grep -v .git

# Verify skill frontmatter
head -6 skills/codeagent/SKILL.md

# Dry-run install
npx github:liafonx/myclaude --list
```

## Files That Are NOT Installed

These exist in-repo but are never copied to `~/.claude/`:
- `agent.md` — this file (development reference only)
- `skills/skill-rules.json` — trigger keywords (not consumed at runtime)
- `skills/upstream-sync/` — maintainer-only skill (not end-user facing)
- `scripts/upstream-sync/` — sync pipeline scripts (maintainer only)
- `sync/` — upstream sync config, status, and reports
- `Makefile` — legacy deployment targets
- `agents/` — slash commands for bmad/requirements/essentials (not enabled by default)
- `memorys/` — CLAUDE.md memory templates
- `config.schema.json` — JSON schema for config validation
