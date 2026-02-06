#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"

CONFIG_PATH="${ROOT_DIR}/sync/upstream-sync.config.json"
TAG=""
STATUS_OUT=""
REPORT_OUT=""

usage() {
  cat <<'EOF'
Usage: compute_diff.sh --tag <release_tag> [--config <path>] [--status-out <path>] [--report-out <path>]

Compares current fork HEAD against upstream release tag for configured sync/signal paths.
Writes status JSON and markdown report.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --config)
      CONFIG_PATH="${2:-}"
      shift 2
      ;;
    --status-out)
      STATUS_OUT="${2:-}"
      shift 2
      ;;
    --report-out)
      REPORT_OUT="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[[ -n "${TAG}" ]] || { echo "ERROR: --tag is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "ERROR: git not found" >&2; exit 1; }

[[ -f "${CONFIG_PATH}" ]] || { echo "ERROR: config not found: ${CONFIG_PATH}" >&2; exit 1; }

UPSTREAM_REPO="$(jq -r '.upstream_repo' "${CONFIG_PATH}")"
STATUS_FILE_REL="$(jq -r '.status_file' "${CONFIG_PATH}")"
REPORT_FILE_REL="$(jq -r '.report_file' "${CONFIG_PATH}")"

if [[ -z "${STATUS_OUT}" ]]; then
  STATUS_OUT="${ROOT_DIR}/${STATUS_FILE_REL}"
fi
if [[ -z "${REPORT_OUT}" ]]; then
  REPORT_OUT="${ROOT_DIR}/${REPORT_FILE_REL}"
fi

mkdir -p "$(dirname "${STATUS_OUT}")" "$(dirname "${REPORT_OUT}")"

LAST_APPLIED_TAG=""
LAST_APPLIED_SHA=""
if [[ -f "${STATUS_OUT}" ]]; then
  LAST_APPLIED_TAG="$(jq -r '.last_applied_tag // empty' "${STATUS_OUT}" || true)"
  LAST_APPLIED_SHA="$(jq -r '.last_applied_sha // empty' "${STATUS_OUT}" || true)"
fi

write_status() {
  local result="$1"
  local sync_json="$2"
  local signal_json="$3"
  local latest_tag="$4"
  local upstream_sha="$5"

  jq -n \
    --arg checked_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg upstream_repo "${UPSTREAM_REPO}" \
    --arg latest_tag "${latest_tag}" \
    --arg upstream_sha "${upstream_sha}" \
    --arg last_applied_tag "${LAST_APPLIED_TAG}" \
    --arg last_applied_sha "${LAST_APPLIED_SHA}" \
    --argjson sync_paths_changed "${sync_json}" \
    --argjson signal_paths_changed "${signal_json}" \
    --arg result "${result}" \
    '
      def n($v): if $v == "" then null else $v end;
      {
        checked_at: $checked_at,
        upstream_repo: $upstream_repo,
        latest_tag: n($latest_tag),
        upstream_sha: n($upstream_sha),
        last_applied_tag: n($last_applied_tag),
        last_applied_sha: n($last_applied_sha),
        sync_paths_changed: $sync_paths_changed,
        signal_paths_changed: $signal_paths_changed,
        applied: false,
        applied_branch: null,
        applied_commit: null,
        result: $result
      }
    ' > "${STATUS_OUT}"
}

fail() {
  local msg="$1"
  write_status "error" "[]" "[]" "${TAG}" ""
  echo "ERROR: ${msg}" >&2
  exit 1
}

if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  fail "working tree must be clean before diff check"
fi

if ! git remote get-url upstream >/dev/null 2>&1; then
  fail "upstream remote missing. Run sync/INIT_UPSTREAM_SYNC.md setup first."
fi

git fetch upstream --tags --quiet || fail "failed to fetch upstream tags"
if ! git rev-parse -q --verify "refs/tags/${TAG}^{commit}" >/dev/null; then
  fail "tag not found locally after fetch: ${TAG}"
fi

UPSTREAM_SHA="$(git rev-parse "refs/tags/${TAG}^{commit}")"

SYNC_PATHS=()
while IFS= read -r _p; do
  SYNC_PATHS+=("$_p")
done < <(jq -r '.sync_paths[]' "${CONFIG_PATH}")
SIGNAL_PATHS=()
while IFS= read -r _p; do
  SIGNAL_PATHS+=("$_p")
done < <(jq -r '.signal_paths[]' "${CONFIG_PATH}")
[[ "${#SYNC_PATHS[@]}" -gt 0 ]] || fail "config sync_paths is empty"

tmp_sync="$(mktemp -t upstream_sync_sync.XXXXXX)"
tmp_signal="$(mktemp -t upstream_sync_signal.XXXXXX)"
trap 'rm -f "${tmp_sync}" "${tmp_signal}"' EXIT

for p in "${SYNC_PATHS[@]}"; do
  git diff --name-only HEAD "refs/tags/${TAG}" -- "${p}" >> "${tmp_sync}"
done
for p in "${SIGNAL_PATHS[@]}"; do
  git diff --name-only HEAD "refs/tags/${TAG}" -- "${p}" >> "${tmp_signal}"
done

sort -u "${tmp_sync}" -o "${tmp_sync}"
sort -u "${tmp_signal}" -o "${tmp_signal}"

sync_json="$(sed '/^$/d' "${tmp_sync}" | jq -R . | jq -s .)"
signal_json="$(sed '/^$/d' "${tmp_signal}" | jq -R . | jq -s .)"

sync_count="$(jq 'length' <<<"${sync_json}")"
signal_count="$(jq 'length' <<<"${signal_json}")"
result="clean"
if [[ "${sync_count}" -gt 0 || "${signal_count}" -gt 0 ]]; then
  result="drift"
fi

write_status "${result}" "${sync_json}" "${signal_json}" "${TAG}" "${UPSTREAM_SHA}"

{
  echo "# Upstream Sync Report"
  echo
  echo "- Checked at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- Upstream: \`${UPSTREAM_REPO}\`"
  echo "- Latest tag: \`${TAG}\`"
  echo "- Upstream SHA: \`${UPSTREAM_SHA}\`"
  echo "- Last applied tag: \`${LAST_APPLIED_TAG:-none}\`"
  echo "- Last applied SHA: \`${LAST_APPLIED_SHA:-none}\`"
  echo "- Result: **${result}**"
  echo
  echo "## Sync Paths Changed"
  if [[ "${sync_count}" -eq 0 ]]; then
    echo "_None_"
  else
    while IFS= read -r f; do
      [[ -n "${f}" ]] && echo "- \`${f}\`"
    done < "${tmp_sync}"
  fi
  echo
  echo "## Signal Paths Changed"
  if [[ "${signal_count}" -eq 0 ]]; then
    echo "_None_"
  else
    while IFS= read -r f; do
      [[ -n "${f}" ]] && echo "- \`${f}\`"
    done < "${tmp_signal}"
  fi
  echo
  if [[ "${result}" == "drift" ]]; then
    echo "## Next Step"
    echo
    echo "Review this summary, then apply manually on approval:"
    echo
    echo "\`scripts/upstream-sync/apply_update.sh --tag ${TAG}\`"
  fi
} > "${REPORT_OUT}"

echo "Computed upstream drift for tag ${TAG}: sync=${sync_count}, signal=${signal_count}, result=${result}"
echo "Status: ${STATUS_OUT}"
echo "Report: ${REPORT_OUT}"
