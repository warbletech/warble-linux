#!/bin/bash
# Mount the Vagrant shared folder (VirtualBox vboxsf) at /vagrant.
set -euo pipefail

TARGET=/vagrant
if [[ $EUID -ne 0 ]]; then
  echo "error: run as root (sudo $0)" >&2
  exit 1
fi
if mountpoint -q "$TARGET"; then
  echo "Vagrant share already mounted at $TARGET"
  exit 0
fi

mkdir -p "$TARGET"
if mount -t vboxsf vagrant "$TARGET"; then
  echo "Vagrant share mounted at $TARGET"
else
  echo "error: failed to mount Vagrant shared folder (needs VirtualBox Guest Additions / vboxsf module)" >&2
  exit 1
fi
