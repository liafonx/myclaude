#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"

CONFIG_PATH="${ROOT_DIR}/sync/upstream-sync.config.json"
TAG=""
BRANCH=""
STATUS_OUT=""
REPORT_OUT=""

usage() {
  cat <<'EOF'
Usage: apply_update.sh --tag <release_tag> [--branch <sync_branch>] [--config <path>] [--status-out <path>] [--report-out <path>]

Applies configured sync paths from upstream release tag into a sync branch and commits.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:-}"
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
BASE_BRANCH="$(jq -r '.base_branch' "${CONFIG_PATH}")"
SYNC_BRANCH_PREFIX="$(jq -r '.sync_branch_prefix' "${CONFIG_PATH}")"
STATUS_FILE_REL="$(jq -r '.status_file' "${CONFIG_PATH}")"
REPORT_FILE_REL="$(jq -r '.report_file' "${CONFIG_PATH}")"

if [[ -z "${STATUS_OUT}" ]]; then
  STATUS_OUT="${ROOT_DIR}/${STATUS_FILE_REL}"
fi
if [[ -z "${REPORT_OUT}" ]]; then
  REPORT_OUT="${ROOT_DIR}/${REPORT_FILE_REL}"
fi

mkdir -p "$(dirname "${STATUS_OUT}")" "$(dirname "${REPORT_OUT}")"

if [[ -z "${BRANCH}" ]]; then
  safe_tag="${TAG#v}"
  safe_tag="${safe_tag//\//-}"
  BRANCH="${SYNC_BRANCH_PREFIX}${safe_tag}"
fi

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
  local applied="$6"
  local applied_branch="$7"
  local applied_commit="$8"

  jq -n \
    --arg checked_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg upstream_repo "${UPSTREAM_REPO}" \
    --arg latest_tag "${latest_tag}" \
    --arg upstream_sha "${upstream_sha}" \
    --arg last_applied_tag "${LAST_APPLIED_TAG}" \
    --arg last_applied_sha "${LAST_APPLIED_SHA}" \
    --argjson sync_paths_changed "${sync_json}" \
    --argjson signal_paths_changed "${signal_json}" \
    --argjson applied "${applied}" \
    --arg applied_branch "${applied_branch}" \
    --arg applied_commit "${applied_commit}" \
    --arg result "${result}" \
    '
      def n($v): if $v == "" then null else $v end;
      {
        checked_at: $checked_at,
        upstream_repo: $upstream_repo,
        latest_tag: n($latest_tag),
        upstream_sha: n($upstream_sha),
        last_applied_tag: (if $applied then n($latest_tag) else n($last_applied_tag) end),
        last_applied_sha: (if $applied then n($upstream_sha) else n($last_applied_sha) end),
        sync_paths_changed: $sync_paths_changed,
        signal_paths_changed: $signal_paths_changed,
        applied: $applied,
        applied_branch: n($applied_branch),
        applied_commit: n($applied_commit),
        result: $result
      }
    ' > "${STATUS_OUT}"
}

fail() {
  local msg="$1"
  write_status "error" "[]" "[]" "${TAG}" "" "false" "" ""
  echo "ERROR: ${msg}" >&2
  exit 1
}

if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  fail "working tree must be clean before apply"
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
PROTECTED_PATHS=()
while IFS= read -r _p; do
  PROTECTED_PATHS+=("$_p")
done < <(jq -r '.protected_paths[]' "${CONFIG_PATH}")
[[ "${#SYNC_PATHS[@]}" -gt 0 ]] || fail "config sync_paths is empty"

git fetch origin "${BASE_BRANCH}" --quiet || true
BASE_REF="${BASE_BRANCH}"
if git show-ref --verify --quiet "refs/remotes/origin/${BASE_BRANCH}"; then
  BASE_REF="origin/${BASE_BRANCH}"
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "${current_branch}" != "${BRANCH}" ]]; then
  if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    git checkout "${BRANCH}" >/dev/null
    git reset --hard "${BASE_REF}" >/dev/null
  else
    git checkout -b "${BRANCH}" "${BASE_REF}" >/dev/null
  fi
else
  git reset --hard "${BASE_REF}" >/dev/null
fi

tmp_sync_files="$(mktemp -t upstream_sync_apply_sync.XXXXXX)"
tmp_signal_files="$(mktemp -t upstream_sync_apply_signal.XXXXXX)"
tmp_status="$(mktemp -t upstream_sync_apply_status.XXXXXX)"
trap 'rm -f "${tmp_sync_files}" "${tmp_signal_files}" "${tmp_status}"' EXIT

git diff --name-status --find-renames=0 HEAD "refs/tags/${TAG}" -- "${SYNC_PATHS[@]}" > "${tmp_status}"

while IFS=$'\t' read -r status path _rest; do
  [[ -z "${status}" || -z "${path}" ]] && continue
  case "${status}" in
    D*)
      if git ls-files --error-unmatch "${path}" >/dev/null 2>&1; then
        git rm -f -- "${path}" >/dev/null
      fi
      ;;
    *)
      git checkout "refs/tags/${TAG}" -- "${path}"
      ;;
  esac
done < "${tmp_status}"

git add -A -- "${SYNC_PATHS[@]}"

if git diff --cached --quiet; then
  git diff --name-only HEAD "refs/tags/${TAG}" -- "${SYNC_PATHS[@]}" > "${tmp_sync_files}" || true
  git diff --name-only HEAD "refs/tags/${TAG}" -- "${SIGNAL_PATHS[@]}" > "${tmp_signal_files}" || true
  sync_json="$(sort -u "${tmp_sync_files}" | sed '/^$/d' | jq -R . | jq -s .)"
  signal_json="$(sort -u "${tmp_signal_files}" | sed '/^$/d' | jq -R . | jq -s .)"
  write_status "clean" "${sync_json}" "${signal_json}" "${TAG}" "${UPSTREAM_SHA}" "false" "${BRANCH}" ""
  echo "No sync-path changes to apply for tag ${TAG}."
  exit 0
fi

staged_files="$(git diff --cached --name-only)"
while IFS= read -r staged; do
  [[ -z "${staged}" ]] && continue
  for protected in "${PROTECTED_PATHS[@]}"; do
    if [[ "${staged}" == "${protected}" || "${staged}" == "${protected}/"* ]]; then
      fail "protected fork path staged unexpectedly: ${protected}"
    fi
  done
done <<< "${staged_files}"

commit_msg="chore(sync): upstream update to ${TAG} (${UPSTREAM_SHA})"
git commit -m "${commit_msg}" >/dev/null
applied_commit="$(git rev-parse HEAD)"

git diff --name-only HEAD~1 HEAD -- "${SYNC_PATHS[@]}" > "${tmp_sync_files}" || true
git diff --name-only HEAD "refs/tags/${TAG}" -- "${SIGNAL_PATHS[@]}" > "${tmp_signal_files}" || true

sort -u "${tmp_sync_files}" -o "${tmp_sync_files}"
sort -u "${tmp_signal_files}" -o "${tmp_signal_files}"

sync_json="$(sed '/^$/d' "${tmp_sync_files}" | jq -R . | jq -s .)"
signal_json="$(sed '/^$/d' "${tmp_signal_files}" | jq -R . | jq -s .)"
write_status "applied" "${sync_json}" "${signal_json}" "${TAG}" "${UPSTREAM_SHA}" "true" "${BRANCH}" "${applied_commit}"

{
  echo "# Upstream Sync Report"
  echo
  echo "- Applied at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- Upstream: \`${UPSTREAM_REPO}\`"
  echo "- Applied tag: \`${TAG}\`"
  echo "- Upstream SHA: \`${UPSTREAM_SHA}\`"
  echo "- Branch: \`${BRANCH}\`"
  echo "- Commit: \`${applied_commit}\`"
  echo
  echo "## Applied Sync Files"
  if [[ "$(jq 'length' <<<"${sync_json}")" -eq 0 ]]; then
    echo "_None_"
  else
    while IFS= read -r f; do
      [[ -n "${f}" ]] && echo "- \`${f}\`"
    done < "${tmp_sync_files}"
  fi
  echo
  echo "## Signal Drift (Not Applied)"
  if [[ "$(jq 'length' <<<"${signal_json}")" -eq 0 ]]; then
    echo "_None_"
  else
    while IFS= read -r f; do
      [[ -n "${f}" ]] && echo "- \`${f}\`"
    done < "${tmp_signal_files}"
  fi
  echo
  echo "Next step: open a PR from \`${BRANCH}\` to \`${BASE_BRANCH}\`."
} > "${REPORT_OUT}"

echo "Applied upstream tag ${TAG} on branch ${BRANCH}"
echo "Commit: ${applied_commit}"
echo "Status: ${STATUS_OUT}"
echo "Report: ${REPORT_OUT}"
