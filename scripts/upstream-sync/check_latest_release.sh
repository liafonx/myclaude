#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REPO="cexll/myclaude"
JSON_OUT=""

usage() {
  cat <<'EOF'
Usage: check_latest_release.sh [--repo <owner/repo>] [--json-out <path>]

Outputs JSON:
{
  "checked_at": "...",
  "upstream_repo": "cexll/myclaude",
  "latest_tag": "vX.Y.Z",
  "upstream_sha": "<commit>"
}
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      UPSTREAM_REPO="${2:-}"
      shift 2
      ;;
    --json-out)
      JSON_OUT="${2:-}"
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

command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "ERROR: git not found" >&2; exit 1; }

AUTH_HEADER=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  AUTH_HEADER=(-H "Authorization: token ${GITHUB_TOKEN}")
elif [[ -n "${GH_TOKEN:-}" ]]; then
  AUTH_HEADER=(-H "Authorization: token ${GH_TOKEN}")
fi

release_json="$(curl -fsSL "${AUTH_HEADER[@]+${AUTH_HEADER[@]}}" "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest")"
latest_tag="$(jq -r '.tag_name // empty' <<<"${release_json}")"
if [[ -z "${latest_tag}" ]]; then
  echo "ERROR: failed to detect latest release tag for ${UPSTREAM_REPO}" >&2
  exit 1
fi

git_url="https://github.com/${UPSTREAM_REPO}.git"
upstream_sha="$(git ls-remote --tags "${git_url}" "refs/tags/${latest_tag}^{}" | awk 'NR==1{print $1}')"
if [[ -z "${upstream_sha}" ]]; then
  upstream_sha="$(git ls-remote --tags "${git_url}" "refs/tags/${latest_tag}" | awk 'NR==1{print $1}')"
fi
if [[ -z "${upstream_sha}" ]]; then
  echo "ERROR: failed to resolve commit sha for tag ${latest_tag}" >&2
  exit 1
fi

checked_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
output="$(jq -n \
  --arg checked_at "${checked_at}" \
  --arg upstream_repo "${UPSTREAM_REPO}" \
  --arg latest_tag "${latest_tag}" \
  --arg upstream_sha "${upstream_sha}" \
  '{checked_at:$checked_at, upstream_repo:$upstream_repo, latest_tag:$latest_tag, upstream_sha:$upstream_sha}')"

if [[ -n "${JSON_OUT}" ]]; then
  mkdir -p "$(dirname "${JSON_OUT}")"
  printf '%s\n' "${output}" > "${JSON_OUT}"
fi

printf '%s\n' "${output}"
