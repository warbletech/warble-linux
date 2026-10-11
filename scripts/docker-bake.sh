#!/bin/bash
# Build a real ISO via Docker (Arch + archiso). Requires Docker + ~15GB free.
# Fails (non-zero) if a real ISO cannot be produced — never emits a mock.
# Usage:
#   EDITION=2 ./scripts/docker-bake.sh
#   ./scripts/docker-bake.sh EDITION=2      # same, as an argument
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for arg in "$@"; do
  case "$arg" in
    EDITION=*) EDITION="${arg#EDITION=}" ;;
    *) echo "error: unknown argument '$arg' (usage: EDITION=N $0)" >&2; exit 2 ;;
  esac
done
EDITION="${EDITION:-1}"
IMAGE="${WARBLE_BAKE_IMAGE:-warble-linux-bake:local}"
OUT_DIR="${OUT_DIR:-$ROOT/out}"

command -v docker >/dev/null || { echo "error: docker required" >&2; exit 1; }

log() { printf '==> %s\n' "$*"; }

log "Building bake image $IMAGE (first run may take several minutes)..."
docker build -f "$ROOT/Dockerfile.bake" -t "$IMAGE" "$ROOT"

mkdir -p "$OUT_DIR"
log "Running mkarchiso path for EDITION=$EDITION (privileged; long)..."
docker run --rm --privileged \
  -e EDITION="$EDITION" \
  -e VERSION="${VERSION:-}" \
  -e GIT_SHA="${GIT_SHA:-}" \
  -e MOCK_ONLY=0 \
  -e REQUIRE_REAL=1 \
  -e OUT_DIR=/src/out \
  -v "$ROOT:/src:rw" \
  -w /src \
  "$IMAGE" \
  bash -lc 'chmod +x scripts/*.sh make-and-bake.sh && make bake EDITION="$EDITION"'

log "Done. Inspect $OUT_DIR and MANIFEST mock= line (should be no if bake succeeded)."
ls -la "$OUT_DIR"
