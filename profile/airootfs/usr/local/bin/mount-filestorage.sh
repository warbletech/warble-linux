#!/bin/bash
# Mount NFS file storage into the live sandbox.
# Usage: mount-filestorage.sh <server:/export> <mount_point>
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <server:/export> <mount_point>" >&2
  exit 2
fi
if [[ $EUID -ne 0 ]]; then
  echo "error: run as root (sudo $0 $*)" >&2
  exit 1
fi
if ! command -v mount.nfs >/dev/null 2>&1; then
  echo "error: mount.nfs not found — install nfs-utils (pacman -S nfs-utils)" >&2
  exit 1
fi

mkdir -p "$2"
if mount -t nfs "$1" "$2"; then
  echo "Mounted $1 at $2"
else
  echo "error: failed to mount NFS share $1 at $2" >&2
  exit 1
fi
