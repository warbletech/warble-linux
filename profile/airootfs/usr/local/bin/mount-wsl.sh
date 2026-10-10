#!/bin/bash
# Make the Windows C: drive available under WSL 2.
# WSL normally auto-mounts Windows drives at /mnt/<letter> via drvfs; this
# helper only verifies that and mounts C: with drvfs if automount is disabled.
set -euo pipefail

TARGET=/mnt/c
if ! grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  echo "error: not running under WSL — nothing to mount" >&2
  exit 1
fi
if mountpoint -q "$TARGET"; then
  echo "Windows C: already available at $TARGET"
  exit 0
fi
if [[ $EUID -ne 0 ]]; then
  echo "error: run as root (sudo $0) to mount C: at $TARGET" >&2
  exit 1
fi

mkdir -p "$TARGET"
if mount -t drvfs 'C:' "$TARGET"; then
  echo "Windows C: mounted at $TARGET"
else
  echo "error: failed to mount C: via drvfs (check [automount] in /etc/wsl.conf)" >&2
  exit 1
fi
