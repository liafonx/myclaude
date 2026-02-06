# Upstream Sync Init (One-Time Setup)

This document is setup-only. Daily operation is handled by the `upstream-sync` maintainer skill.

## Purpose

Configure this fork so maintainers can run manual upstream updates from `cexll/myclaude` release tags.

## Prerequisites

- `git`
- `curl`
- `jq`
- Optional: `gh` (if you want to open PRs manually via CLI)

## One-Time Setup

1. Add upstream remote:

```bash
git remote add upstream https://github.com/cexll/myclaude.git
```

If `upstream` already exists, verify URL:

```bash
git remote get-url upstream
```

2. Fetch tags:

```bash
git fetch upstream --tags
```

3. Verify config/status files exist:

- `sync/upstream-sync.config.json`
- `sync/status/upstream-sync-status.json`
- `sync/status/upstream-sync-report.md`

4. Smoke test release lookup:

```bash
scripts/upstream-sync/check_latest_release.sh
```

## First Manual Check

```bash
TAG="$(scripts/upstream-sync/check_latest_release.sh | jq -r '.latest_tag')"
scripts/upstream-sync/compute_diff.sh --tag "${TAG}"
```

The report is written to `sync/status/upstream-sync-report.md`.

## Notes

- Update flow is manual-only.
- No auto-PR and no scheduled sync in this setup.
- Apply stage is intentionally separate and guarded by explicit user confirmation in the skill.
