#!/usr/bin/env bash
# Push a WSL rootfs tarball to GHCR as several small layers.
# One docker-import layer timed out on the blob upload.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

tar_path="${1:?rootfs tar.gz}"
ver="${2:?version}"
img="${3:-ghcr.io/warbletech/warble-linux}"
budget="${LAYER_BYTES:-40000000}"

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/rootfs" "$root/layers"
tar -xzf "$tar_path" -C "$root/rootfs"
lic="${LICENSE_FILE:-LICENSE}"
if [[ -f "$lic" ]]; then
  mkdir -p "$root/rootfs/usr/share/licenses/warble-linux"
  cp "$lic" "$root/rootfs/usr/share/licenses/warble-linux/LICENSE"
fi

python3 - "$root/rootfs" "$root/layers" "$budget" <<'PY'
import os, sys, tarfile
from pathlib import Path
root, out, budget = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3])
entries = []
for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
    for name in dirnames + filenames:
        path = Path(dirpath) / name
        rel = path.relative_to(root).as_posix()
        try:
            size = path.lstat().st_size
        except OSError:
            size = 0
        entries.append((rel, size))
batches, cur, cur_size = [], [], 0
for rel, size in entries:
    if cur and cur_size + size > budget and cur_size > 0:
        batches.append(cur)
        cur, cur_size = [], 0
    cur.append(rel)
    cur_size += size
if cur:
    batches.append(cur)
print(f"layers={len(batches)}", flush=True)
for i, batch in enumerate(batches, 1):
    dest = out / f"layer-{i:03d}.tar"
    with tarfile.open(dest, "w") as tf:
        for rel in batch:
            tf.add(root / rel, arcname=rel, recursive=False)
    print(f"{dest.name} {dest.stat().st_size}", flush=True)
PY

{
  echo "FROM scratch"
  for layer in "$root"/layers/layer-*.tar; do
    echo "ADD $(basename "$layer") /"
  done
  echo 'LABEL org.opencontainers.image.licenses="GPL-2.0-only"'
  echo 'LABEL org.opencontainers.image.title="warble-linux"'
  echo 'LABEL org.opencontainers.image.source="https://github.com/warbletech/warble-linux"'
  echo 'LABEL org.opencontainers.image.vendor="Warble"'
} > "$root/layers/Dockerfile"

export DOCKER_CLIENT_TIMEOUT=900
export COMPOSE_HTTP_TIMEOUT=900
docker build -t "$img:$ver" "$root/layers"
docker tag "$img:$ver" "$img:0"

push_one() {
  local ref="$1" n
  for n in 1 2 3 4 5; do
    if docker push "$ref"; then
      return 0
    fi
    echo "push $ref attempt $n failed, retrying" >&2
    sleep 15
  done
  return 1
}
push_one "$img:$ver"
push_one "$img:0"
