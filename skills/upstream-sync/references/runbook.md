# Upstream Sync Runbook

## Scope

Manual-only upstream sync for this fork. Trigger when maintainers receive an upstream release notification.

## One-Time Setup

See:
- `sync/INIT_UPSTREAM_SYNC.md`

## Operational Flow

1. Detect latest release:
```bash
scripts/upstream-sync/check_latest_release.sh
```

2. Compute drift:
```bash
TAG="$(scripts/upstream-sync/check_latest_release.sh | jq -r '.latest_tag')"
scripts/upstream-sync/compute_diff.sh --tag "${TAG}"
```

3. Review report:
- `sync/status/upstream-sync-report.md`
- `sync/status/upstream-sync-status.json`

4. Apply on approval:
```bash
scripts/upstream-sync/apply_update.sh --tag "${TAG}"
```

5. Open PR manually from generated sync branch.

## Failure Triage

1. `upstream remote missing`
- Run setup from `sync/INIT_UPSTREAM_SYNC.md`.

2. `working tree must be clean`
- Commit/stash/discard local changes manually and re-run.

3. `tag not found locally`
- Re-run with valid tag; confirm upstream latest release exists.

4. `protected fork path staged unexpectedly`
- Stop and inspect staged diff before retrying.

## Status Field Meanings

- `clean`: no tracked drift
- `drift`: drift detected from latest tag
- `applied`: sync applied and committed
- `skipped`: user declined apply
- `error`: workflow failed
