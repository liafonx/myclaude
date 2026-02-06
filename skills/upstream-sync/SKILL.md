---
name: upstream-sync
version: 1.0.0
description: Maintainer-only manual upstream update workflow for this fork. Detects latest upstream release, computes drift summary, asks for explicit confirmation, and applies changes on approval.
---

# Upstream Sync (Maintainer Skill)

This skill is for maintainers of this repository. It is not part of end-user runtime install behavior.

## Purpose

Run a manual upstream update flow from `cexll/myclaude` release tags:
1. detect latest upstream release
2. compute drift summary for tracked paths
3. ask user to apply or skip
4. apply on approval (branch + commit)

## Required Sequence (Do Not Skip)

1. **Preflight**
- Ensure repo worktree is clean.
- If dirty, stop and tell user to clean/stash manually.

2. **Detect latest release**
- Run:
```bash
scripts/upstream-sync/check_latest_release.sh
```
- Extract `latest_tag` from JSON.

3. **Compute drift summary**
- Run:
```bash
scripts/upstream-sync/compute_diff.sh --tag <latest_tag>
```
- Read:
  - `sync/status/upstream-sync-status.json`
  - `sync/status/upstream-sync-report.md`
- Summarize drift for user in concise form.

4. **Ask user for confirmation**
- Ask explicitly: apply or skip.
- Example:
  - "Apply upstream update for `<tag>` now?"

5. **If user approves**
- Run:
```bash
scripts/upstream-sync/apply_update.sh --tag <latest_tag>
```
- Return:
  - branch name
  - commit SHA
  - next step: open PR manually.

6. **If user declines**
- Mark status as skipped:
```bash
tmp="$(mktemp)" && \
jq '.result="skipped" | .applied=false | .applied_branch=null | .applied_commit=null' \
  sync/status/upstream-sync-status.json > "${tmp}" && \
mv "${tmp}" sync/status/upstream-sync-status.json
```
- Report "Skipped by user; no changes applied."

## Path Rules

- Apply only:
  - `codeagent-wrapper/**`
- Signal-only monitoring:
  - `skills/codeagent/**` (fork-owned, review manually)
  - `skills/codex/**`
  - `skills/gemini/**`

Never overwrite fork-owned files listed in `sync/upstream-sync.config.json -> protected_paths`.

## Outputs

- Machine status: `sync/status/upstream-sync-status.json`
- Human report: `sync/status/upstream-sync-report.md`

## Reference

See detailed runbook:
- `skills/upstream-sync/references/runbook.md`
