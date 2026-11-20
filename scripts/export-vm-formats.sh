#!/usr/bin/env bash
# Export standalone qcow2 and raw disks from a Vagrant libvirt box produced
# by scripts/build-images.sh (the "disk" target).
#
# Usage:
#   scripts/export-vm-formats.sh <out_dir> [box]
#
# If [box] is omitted, every *-libvirt.box in <out_dir> is exported.
# The box is a tar with metadata.json (provider=libvirt, format=qcow2) and
# box.img. This script does not build images and does not need root.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log() { printf '[export-vm] %s\n' "$*"; }
die() { printf '[export-vm] ERROR: %s\n' "$*" >&2; exit 1; }
need() { local c; for c in "$@"; do command -v "$c" >/dev/null || die "missing tool: $c"; done; }

OUT_DIR="${1:-}"
[[ -n "$OUT_DIR" && -d "$OUT_DIR" ]] || die "usage: $0 <out_dir> [box]"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"

export_one() {
  local box="$1" base dir meta
  [[ -f "$box" ]] || die "no such box: $box"
  need tar qemu-img python3
  box="$(cd "$(dirname "$box")" && pwd)/$(basename "$box")"
  case "$(basename "$box")" in
    *-libvirt.box) base="${box%-libvirt.box}" ;;
    *) die "expected a *-libvirt.box, got $(basename "$box")" ;;
  esac
  dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap 'rm -rf "$dir"' RETURN
  tar -xf "$box" -C "$dir"
  [[ -f "$dir/box.img" && -f "$dir/metadata.json" ]] || die "box is missing box.img or metadata.json"
  python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); assert m.get("provider")=="libvirt" and m.get("format")=="qcow2", m' "$dir/metadata.json"
  qemu-img info "$dir/box.img" | tee "$base.qcow2.info"
  # Re-encode to a standalone qcow2 (keeps a compressed, self-contained disk).
  qemu-img convert -c -O qcow2 "$dir/box.img" "$base.qcow2"
  qemu-img convert -O raw "$dir/box.img" "$base.raw"
  qemu-img info "$base.qcow2"
  qemu-img info "$base.raw" | tee "$base.raw.info"
  # The warble-linux disk is always partitioned (FAT /boot + ext4 root) and
  # carries both BIOS (syslinux MBR) and UEFI (ESP) bootloaders. There is no
  # unpartitioned or firmware-specific variant to emit here.
  log "wrote $base.qcow2 and $base.raw"
}

if [[ -n "${2:-}" ]]; then
  export_one "$2"
else
  shopt -s nullglob
  boxes=("$OUT_DIR"/*-libvirt.box)
  [[ ${#boxes[@]} -gt 0 ]] || die "no *-libvirt.box in $OUT_DIR"
  for b in "${boxes[@]}"; do
    export_one "$b"
  done
fi
