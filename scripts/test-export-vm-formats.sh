#!/usr/bin/env bash
# Offline fixture test for scripts/export-vm-formats.sh.
# Builds a tiny libvirt box with qemu-img (no pacstrap, no network, no root).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
need() { local c; for c in "$@"; do command -v "$c" >/dev/null || { echo "missing tool: $c" >&2; exit 1; }; done; }
need qemu-img tar python3

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
out="$tmp/out"
mkdir -p "$tmp/box" "$out"

qemu-img create -f qcow2 "$tmp/box/box.img" 8M >/dev/null
printf '{"provider":"libvirt","format":"qcow2","virtual_size":1}\n' > "$tmp/box/metadata.json"
# empty Vagrantfile is fine for the exporter (it only reads metadata + box.img)
printf 'Vagrant.configure("2") { |c| }\n' > "$tmp/box/Vagrantfile"
tar -cf "$out/warble-linux-minimal-0.0.0-libvirt.box" -C "$tmp/box" metadata.json Vagrantfile box.img

"$ROOT_DIR/scripts/export-vm-formats.sh" "$out"

[[ -f "$out/warble-linux-minimal-0.0.0.qcow2" ]] || { echo "missing qcow2" >&2; exit 1; }
[[ -f "$out/warble-linux-minimal-0.0.0.raw" ]] || { echo "missing raw" >&2; exit 1; }

python3 - "$out" <<'PY'
import json, subprocess, sys
out = sys.argv[1]
def info(path):
    raw = subprocess.check_output(["qemu-img", "info", "--output=json", path], text=True)
    return json.loads(raw)
q = info(f"{out}/warble-linux-minimal-0.0.0.qcow2")
r = info(f"{out}/warble-linux-minimal-0.0.0.raw")
assert q.get("format") == "qcow2", q
assert r.get("format") == "raw", r
assert int(q["virtual-size"]) == int(r["virtual-size"]) == 8 * 1024 * 1024
print("ok: export-vm-formats fixture (qcow2 + raw, 8MiB)")
PY
