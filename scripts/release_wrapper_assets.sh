#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAPPER_DIR="${ROOT_DIR}/codeagent-wrapper"
DIST_ROOT="${ROOT_DIR}/dist/release"

TAG=""
REPO="liafonx/myclaude"
UPLOAD=false
SKIP_TESTS=false
NOTES_FILE=""

usage() {
  cat <<'EOF'
Build (and optionally upload) codeagent-wrapper release assets.

Usage:
  scripts/release_wrapper_assets.sh --tag <vX.Y.Z> [options]

Options:
  --tag <tag>         Required. Release tag (example: v1.2.3).
  --repo <owner/repo> Target GitHub repo for release upload (default: liafonx/myclaude).
  --upload            Upload built assets to GitHub release with gh CLI.
  --notes-file <path> Release notes file for creating a new release.
  --skip-tests        Skip `go test ./...` before build.
  -h, --help          Show this help.

Behavior:
  - Builds assets for:
    darwin/amd64, darwin/arm64, linux/amd64, linux/arm64, windows/amd64, windows/arm64
  - Outputs to: dist/release/<tag>/
  - Copies install.sh and install.bat into the same output folder.
  - If --upload is set:
    - Creates release if missing
    - Uploads assets with --clobber
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --upload)
      UPLOAD=true
      shift
      ;;
    --notes-file)
      NOTES_FILE="${2:-}"
      shift 2
      ;;
    --skip-tests)
      SKIP_TESTS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${TAG}" ]]; then
  echo "ERROR: --tag is required" >&2
  usage >&2
  exit 2
fi

if [[ ! "${REPO}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "ERROR: invalid --repo value: ${REPO}" >&2
  exit 2
fi

if [[ ! -d "${WRAPPER_DIR}" ]]; then
  echo "ERROR: missing wrapper directory: ${WRAPPER_DIR}" >&2
  exit 1
fi

if [[ -n "${NOTES_FILE}" && ! -f "${NOTES_FILE}" ]]; then
  echo "ERROR: notes file not found: ${NOTES_FILE}" >&2
  exit 1
fi

OUT_DIR="${DIST_ROOT}/${TAG}"
mkdir -p "${OUT_DIR}"

if [[ "${SKIP_TESTS}" != "true" ]]; then
  echo "Running tests in codeagent-wrapper..."
  (
    cd "${WRAPPER_DIR}"
    GOCACHE="${GOCACHE:-/tmp/go-build-cache}" go test ./...
  )
fi

targets=(
  "darwin amd64"
  "darwin arm64"
  "linux amd64"
  "linux arm64"
  "windows amd64"
  "windows arm64"
)

echo "Building assets into ${OUT_DIR}..."
for target in "${targets[@]}"; do
  read -r goos goarch <<<"${target}"
  ext=""
  if [[ "${goos}" == "windows" ]]; then
    ext=".exe"
  fi
  out="codeagent-wrapper-${goos}-${goarch}${ext}"
  echo "  -> ${out}"
  (
    cd "${WRAPPER_DIR}"
    CGO_ENABLED=0 GOOS="${goos}" GOARCH="${goarch}" \
      go build \
      -ldflags="-s -w -X codeagent-wrapper/internal/app.version=${TAG}" \
      -o "${OUT_DIR}/${out}" \
      ./cmd/codeagent-wrapper
  )
done

cp "${ROOT_DIR}/install.sh" "${OUT_DIR}/install.sh"
cp "${ROOT_DIR}/install.bat" "${OUT_DIR}/install.bat"

echo "Built files:"
ls -1 "${OUT_DIR}"

if [[ "${UPLOAD}" == "true" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh CLI is required for --upload" >&2
    exit 1
  fi

  gh auth status >/dev/null

  if ! gh release view "${TAG}" -R "${REPO}" >/dev/null 2>&1; then
    echo "Release ${TAG} does not exist in ${REPO}; creating..."
    if [[ -n "${NOTES_FILE}" ]]; then
      gh release create "${TAG}" -R "${REPO}" --title "${TAG}" --notes-file "${NOTES_FILE}"
    else
      gh release create "${TAG}" -R "${REPO}" --title "${TAG}" --generate-notes
    fi
  fi

  echo "Uploading assets to ${REPO} (${TAG})..."
  gh release upload "${TAG}" "${OUT_DIR}"/codeagent-wrapper-* "${OUT_DIR}/install.sh" "${OUT_DIR}/install.bat" -R "${REPO}" --clobber
  echo "Upload complete."
fi

echo "Done."
