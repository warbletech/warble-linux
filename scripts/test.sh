#!/usr/bin/env bash
# Stage 2 of build -> test -> publish. CI runs exactly these commands.
#
#   scripts/test.sh iso-verify <iso>            real (mock=no), size guard, archiso initramfs hook
#   scripts/test.sh iso  <iso> <bios|uefi>      boot headless in QEMU to a serial login prompt
#   scripts/test.sh wsl  <wsl.tar.gz>           tar structure + docker import + smoke commands
#   scripts/test.sh vm   <libvirt.box> <bios|uefi>  boot box disk in QEMU, SSH as vagrant, checks
#   scripts/test.sh ova  <file.ova>             OVA layout, manifest checksums, VMDK format
#   scripts/test.sh all  [out_dir]              every test above for everything in out_dir
#
# Every sandbox is disposable: QEMU runs with -snapshot (image never modified)
# and is killed afterwards; the docker image is removed. A passing test writes a
# marker to $OK_DIR (default out/ok) that scripts/publish.sh requires.
# Needs: qemu-system-x86_64 (+ OVMF for uefi; KVM strongly recommended), ssh,
# curl, docker (wsl), tar, sha256sum, qemu-img (ova/vm), xorriso + lsinitcpio
# (iso-verify; optional locally).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OK_DIR="${OK_DIR:-$ROOT_DIR/out/ok}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/out/logs}"
MAX_ISO_BYTES="${MAX_ISO_BYTES:-2040109465}"   # 1.9 GiB guard (GitHub asset limit is 2 GiB)
VAGRANT_KEY_URL="https://raw.githubusercontent.com/hashicorp/vagrant/dc55920a284544919340b975098b4ac9005b08b0/keys/vagrant.key.ed25519"
SSH_PORT="${SSH_PORT:-2222}"

log() { printf '[test] %s\n' "$*"; }
die() { printf '[test] FAIL: %s\n' "$*" >&2; exit 1; }
usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
need() { local c; for c in "$@"; do command -v "$c" >/dev/null || die "missing tool: $c"; done; }
mkdir -p "$OK_DIR" "$LOG_DIR"

# edition number from an artifact file name
edition_of() {
  local b n i=0; b=$(basename "$1")
  for n in minimal developer cloud-native full; do
    i=$((i + 1))
    case "$b" in warble-linux-"$n"-*|warble-linux-wsl2-"$n"-*) echo "$i"; return ;; esac
  done
  die "cannot tell the edition from file name: $b"
}

summary() { [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] && echo "$*" >> "$GITHUB_STEP_SUMMARY" || true; }

# Firmware args for QEMU (sets global FW array)
firmware_args() {
  FW=()
  [[ "$1" == bios ]] && return 0
  [[ "$1" == uefi ]] || die "firmware must be bios or uefi"
  local code="" vars="" f
  for f in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/edk2/x64/OVMF_CODE.4m.fd /usr/share/edk2-ovmf/x64/OVMF_CODE.fd; do
    [[ -f "$f" ]] && { code="$f"; break; }
  done
  for f in /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd /usr/share/edk2/x64/OVMF_VARS.4m.fd /usr/share/edk2-ovmf/x64/OVMF_VARS.fd; do
    [[ -f "$f" ]] && { vars="$f"; break; }
  done
  [[ -n "$code" && -n "$vars" ]] || die "OVMF firmware not found (install ovmf / edk2-ovmf)"
  VARS_COPY=$(mktemp); cp "$vars" "$VARS_COPY"
  FW=(-drive "if=pflash,format=raw,readonly=on,file=$code" -drive "if=pflash,format=raw,file=$VARS_COPY")
}

accel() { if [[ -w /dev/kvm ]]; then echo kvm; else echo tcg; fi; }

stop_qemu() {
  local pid=$1
  kill "$pid" 2>/dev/null || true
  for _ in 1 2 3 4 5; do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
  kill -9 "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

t_iso_verify() {
  local iso="$1" man size
  [[ -f "$iso" ]] || die "no such ISO: $iso"
  man=$(find "$(dirname "$iso")" -maxdepth 1 -name 'MANIFEST-*.txt' | head -1)
  [[ -n "$man" ]] && { cat "$man"; grep -qx 'mock=no' "$man" || die "MANIFEST does not say mock=no"; }
  size=$(stat -c%s "$iso")
  log "ISO size: $size bytes ($((size / 1024 / 1024)) MiB), guard $MAX_ISO_BYTES"
  summary "| edition $(edition_of "$iso") | $(basename "$iso") | ${size} B | $((size / 1024 / 1024)) MiB | limit ${MAX_ISO_BYTES} B |"
  (( size > 200 * 1024 * 1024 )) || die "ISO too small to be real ($size bytes)"
  (( size < MAX_ISO_BYTES )) || die "ISO is $size bytes, over the ${MAX_ISO_BYTES}-byte guard"
  if command -v xorriso >/dev/null; then
    xorriso -indev "$iso" -ls /arch/boot/x86_64/ 2>/dev/null | tee /tmp/bootfiles.txt
    grep -q vmlinuz-linux /tmp/bootfiles.txt && grep -q initramfs-linux.img /tmp/bootfiles.txt || die "kernel/initramfs missing"
    if command -v lsinitcpio >/dev/null; then
      xorriso -osirrox on -indev "$iso" -extract /arch/boot/x86_64/initramfs-linux.img /tmp/initramfs.img >/dev/null 2>&1
      lsinitcpio /tmp/initramfs.img | grep -qE '^hooks/archiso$' || die "initramfs lacks the archiso hook"
    fi
  else
    log "xorriso not installed: skipping boot-file checks"
  fi
  log "PASS iso-verify $(basename "$iso")"
}

t_iso() {
  local iso="$1" fwname="$2" ed limit acc serial qpid result=timeout t=0
  need qemu-system-x86_64
  [[ -f "$iso" ]] || die "no such ISO: $iso"
  ed=$(edition_of "$iso"); acc=$(accel); limit=$([[ $acc == kvm ]] && echo 600 || echo 1200)
  firmware_args "$fwname"
  serial="$LOG_DIR/serial-iso-${ed}-${fwname}.log"; : > "$serial"
  log "boot ISO edition $ed ($fwname, accel=$acc, timeout ${limit}s)"
  timeout --kill-after=15 "$((limit + 30))" \
    qemu-system-x86_64 -accel "$acc" -m 2048 -smp 2 "${FW[@]}" \
      -cdrom "$iso" -boot d -snapshot -nic user,model=virtio-net-pci \
      -display none -monitor none -serial "file:$serial" &
  qpid=$!
  for ((t = 0; t < limit; t += 5)); do
    sleep 5
    if grep -qE 'Kernel panic|emergency shell|You are now being dropped|ERROR: .*device did not show up|Please configure the system' "$serial"; then result=failed; break; fi
    if grep -q 'login:' "$serial"; then result=ok; break; fi
    kill -0 "$qpid" 2>/dev/null || { result=exited; break; }
  done
  stop_qemu "$qpid"
  echo "----- serial console (tail) -----"; tail -n 40 "$serial" || true
  [[ "$result" == ok ]] || die "ISO boot ($fwname): $result after ~${t}s (log: $serial)"
  echo "edition=$ed firmware=$fwname boot=ok" > "$OK_DIR/boot-ok-${ed}-${fwname}.txt"
  log "PASS iso $fwname edition $ed after ~${t}s"
}

t_wsl() {
  local tgz="$1" ed list tag
  need tar docker
  [[ -f "$tgz" ]] || die "no such file: $tgz"
  ed=$(edition_of "$tgz"); list=$(mktemp)
  tar -tzf "$tgz" > "$list"
  log "$(wc -l < "$list") entries"
  for p in ./etc/wsl.conf ./etc/os-release ./usr/bin/bash ./usr/lib/systemd/systemd ./etc/sudoers.d/10-warble; do
    grep -qx "$p" "$list" || die "missing $p"
  done
  # a kernel = /boot images or an installed kernel package's modules tree
  if grep -E '^\./boot/(vmlinuz|initramfs)|^\./usr/lib/modules/[^/]+/vmlinuz$' "$list"; then
    die "WSL rootfs must not contain a kernel"
  fi
  tar -xzOf "$tgz" ./etc/wsl.conf | tee "$list.conf"
  grep -qx 'systemd=true' "$list.conf" && grep -qx 'default=warble' "$list.conf" || die "wsl.conf lacks systemd=true / default=warble"
  tag="warble-wsl-test:$$"
  docker import "$tgz" "$tag" >/dev/null
  if ! docker run --rm --user warble "$tag" bash -lc '
      set -e
      cat /etc/warble-release; id
      sudo -n true && echo "sudo ok"
      echo "packages: $(pacman -Q | wc -l)"
      test ! -e /boot/vmlinuz-linux
      command -v git curl'; then
    docker image rm "$tag" >/dev/null; die "WSL smoke commands failed"
  fi
  docker image rm "$tag" >/dev/null
  echo "edition=$ed wsl=ok" > "$OK_DIR/img-ok-${ed}-wsl.txt"
  log "PASS wsl edition $ed"
}

t_vm() {
  local box="$1" fwname="$2" ed dir key acc limit serial qpid result=timeout t=0
  need qemu-system-x86_64 qemu-img ssh curl tar python3
  [[ -f "$box" ]] || die "no such box: $box"
  ed=$(edition_of "$box"); dir=$(mktemp -d)
  tar -xf "$box" -C "$dir"
  python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); assert m["provider"]=="libvirt" and m["format"]=="qcow2", m' "$dir/metadata.json"
  qemu-img info "$dir/box.img"
  key="$dir/vagrant_key"; curl -fsSL "$VAGRANT_KEY_URL" -o "$key"; chmod 600 "$key"
  acc=$(accel); limit=$([[ $acc == kvm ]] && echo 420 || echo 900)
  firmware_args "$fwname"
  serial="$LOG_DIR/serial-vm-${ed}-${fwname}.log"; : > "$serial"
  log "boot Vagrant box edition $ed ($fwname, accel=$acc), SSH on 127.0.0.1:$SSH_PORT"
  timeout --kill-after=15 "$((limit + 60))" \
    qemu-system-x86_64 -accel "$acc" -m 2048 -smp 2 "${FW[@]}" \
      -drive "file=$dir/box.img,if=virtio,format=qcow2" -snapshot \
      -nic "user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22" \
      -display none -monitor none -serial "file:$serial" &
  qpid=$!
  local ssh_opts=(-i "$key" -p "$SSH_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o BatchMode=yes -o LogLevel=ERROR)
  for ((t = 0; t < limit; t += 5)); do
    sleep 5
    if grep -qE 'Kernel panic|emergency shell|You are now being dropped' "$serial"; then result=failed; break; fi
    kill -0 "$qpid" 2>/dev/null || { result=exited; break; }
    if ssh "${ssh_opts[@]}" vagrant@127.0.0.1 true 2>/dev/null; then result=ssh; break; fi
  done
  if [[ "$result" == ssh ]]; then
    if ssh "${ssh_opts[@]}" vagrant@127.0.0.1 'set -e
        cat /etc/warble-release; uname -r; id
        sudo -n true && echo "sudo ok"
        sudo nft list chain inet filter input | tee /tmp/input.nft
        grep -qE "tcp dport (22|ssh) accept" /tmp/input.nft
        findmnt /; findmnt /boot
        systemctl is-system-running --wait || systemctl --failed --no-pager'; then
      result=ok
    else
      result=checks-failed
    fi
  fi
  stop_qemu "$qpid"
  rm -rf "$dir"
  echo "----- serial console (tail) -----"; tail -n 30 "$serial" || true
  [[ "$result" == ok ]] || die "Vagrant box ($fwname): $result after ~${t}s (log: $serial)"
  echo "edition=$ed vm=$fwname ok" > "$OK_DIR/img-ok-${ed}-vm-${fwname}.txt"
  log "PASS vm $fwname edition $ed after ~${t}s"
}

t_ova() {
  local ova="$1" dir
  need tar qemu-img sha256sum
  dir=$(mktemp -d)
  tar -tf "$ova" | tee "$dir/list"
  head -1 "$dir/list" | grep -q '\.ovf$' || die "OVF descriptor must be the first OVA entry"
  tar -xf "$ova" -C "$dir"
  (cd "$dir" && sed -E 's/^SHA256\((.*)\)= (.*)$/\2  \1/' ./*.mf | sha256sum -c) || die "OVA manifest checksum mismatch"
  qemu-img info "$dir"/*.vmdk | tee "$dir/info"
  grep -q 'create type: streamOptimized' "$dir/info" || die "VMDK is not streamOptimized"
  rm -rf "$dir"
  log "PASS ova $(basename "$ova")"
}

t_all() {
  local out="${1:-$ROOT_DIR/out}" f fw rc=0
  shopt -s nullglob
  for f in "$out"/warble-linux-*.iso; do
    t_iso_verify "$f" || rc=1
    for fw in bios uefi; do (t_iso "$f" "$fw") || rc=1; done
  done
  for f in "$out"/warble-linux-wsl2-*.tar.gz; do (t_wsl "$f") || rc=1; done
  for f in "$out"/warble-linux-*-libvirt.box; do
    for fw in bios uefi; do (t_vm "$f" "$fw") || rc=1; done
  done
  for f in "$out"/warble-linux-*.ova; do (t_ova "$f") || rc=1; done
  log "markers in $OK_DIR:"; ls -1 "$OK_DIR"
  return "$rc"
}

case "${1:-}" in
  iso-verify) t_iso_verify "${2:?iso}" ;;
  iso) t_iso "${2:?iso}" "${3:?bios|uefi}" ;;
  wsl) t_wsl "${2:?wsl tarball}" ;;
  vm) t_vm "${2:?box}" "${3:?bios|uefi}" ;;
  ova) t_ova "${2:?ova}" ;;
  all) t_all "${2:-}" ;;
  -h|--help|"") usage ;;
  *) usage 1 ;;
esac
