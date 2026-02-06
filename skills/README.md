# Skills

This directory contains agent skills (each skill lives in its own folder with a `SKILL.md`).

## Primary Skill

`codeagent` is the primary maintained skill in this repository.

- Path: `skills/codeagent/SKILL.md`
- Purpose: route subagent creation through `codeagent-wrapper`
- Backends: Codex / Claude / Gemini / OpenCode

## Maintainer Skill

`upstream-sync` is a maintainer-only skill for manual upstream release sync checks and apply flow.

- Path: `skills/upstream-sync/SKILL.md`
- Setup: `sync/INIT_UPSTREAM_SYNC.md`
- Reports: `sync/status/upstream-sync-status.json`, `sync/status/upstream-sync-report.md`

## Install with `npx` (recommended)

List installable items:

```bash
npx github:liafonx/myclaude --list
```

Install (interactive; pick `skill:<name>`):

```bash
npx github:liafonx/myclaude
```

Force overwrite / custom install directory:

```bash
npx github:liafonx/myclaude --install-dir ~/.claude --force
```

## Reference-Only Skills

Other skill folders are retained as collaboration routing references (examples/history), not as the main installation target for this repository.
