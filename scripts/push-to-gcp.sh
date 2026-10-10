#!/bin/bash
# Optional: publish ISO to GCP Artifact Registry as an OCI artifact.
# Requires: gcloud, docker, authenticated project access.
# Not wired into CI by default — community / maintainer use.
# Note: this publishes the ISO file as an OCI artifact for distribution; it is
# not a bootable Compute Engine image.
#
# Usage: PROJECT_ID=<your-gcp-project> DRY_RUN=0 ./scripts/push-to-gcp.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${PROJECT_ID:-}"   # required: no default project
REPO_NAME="${REPO_NAME:-warble-os-releases}"
LOCATION="${LOCATION:-us-central1}"
IMAGE_NAME="${IMAGE_NAME:-warble-linux-iso}"
VERSION="${VERSION:-$(date -u +%Y.%m.%d)}"
OUT_DIR="${OUT_DIR:-$ROOT/out}"

ISO_FILE=$(ls "$OUT_DIR"/*.iso 2>/dev/null | head -n 1 || true)
if [[ -z "$ISO_FILE" ]]; then
  echo "error: no ISO in $OUT_DIR — run make first" >&2
  exit 1
fi

if [[ "${DRY_RUN:-1}" == "1" ]]; then
  PROJECT_ID="${PROJECT_ID:-<set PROJECT_ID>}"
  echo "DRY_RUN=1 (default): would publish $(basename "$ISO_FILE")"
  echo "  project=$PROJECT_ID repo=$REPO_NAME location=$LOCATION"
  echo "  tag=${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${VERSION}"
  echo "Set DRY_RUN=0 and ensure gcloud/docker auth to push for real."
  exit 0
fi

[[ -n "$PROJECT_ID" ]] || { echo "error: set PROJECT_ID=<your-gcp-project>" >&2; exit 1; }
command -v gcloud >/dev/null || { echo "error: gcloud required" >&2; exit 1; }
command -v docker >/dev/null || { echo "error: docker required" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp "$ISO_FILE" "$TMP/"
cat > "$TMP/Dockerfile" <<EOF
FROM scratch
COPY $(basename "$ISO_FILE") /
EOF

TAG="${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/${IMAGE_NAME}:${VERSION}"
gcloud auth configure-docker "${LOCATION}-docker.pkg.dev" --quiet
docker build -f "$TMP/Dockerfile" -t "$TAG" "$TMP"
docker push "$TAG"
echo "Pushed $TAG"
