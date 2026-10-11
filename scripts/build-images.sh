#!/usr/bin/env bash
# Build REAL secondary images for one edition from the same package lists as
# the ISO (editions/base.packages + editions/<edition>.packages):
#
#   wsl   warble-linux-wsl2-<ename>-<ver>.tar.gz     WSL2 rootfs (no kernel/bootloader)
#   disk  warble-linux-<ename>-<ver>-libvirt.box     Vagrant box (libvirt/qcow2)
#         warble-linux-<ename>-<ver>.ova             OVF 1.0 + streamOptimized VMDK
#
# The live ISO has no installer or sshd, so instead of driving it with Packer we
# pacstrap a root filesystem directly. The disk image is assembled WITHOUT loop
# devices or mounts: a FAT32 /boot (syslinux for BIOS, systemd-boot for UEFI,
# populated with mtools) plus an ext4 root built with `mkfs.ext4 -d`.
#
# Needs root on Arch Linux (CI: privileged archlinux container), with
# arch-install-scripts dosfstools mtools e2fsprogs syslinux qemu-img libarchive.
# Usage: build-images.sh <edition 1-4> <wsl|disk|all> [out_dir]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EDITION="${1:?edition (1-4)}"
WHAT="${2:-all}"
OUT_DIR="${3:-$ROOT_DIR/out}"
VERSION="${VERSION:-$(cat "$ROOT_DIR/VERSION" 2>/dev/null || echo 0.0.0)}"
WORK_DIR="${WORK_DIR:-/tmp/warble-images}"
MAX_ASSET_BYTES="${MAX_ASSET_BYTES:-2040109465}"   # 1.9 GiB (GitHub limit is 2 GiB)
# Vagrant's well-known insecure public keys (rsa + ed25519), pinned commit.
VAGRANT_PUB_URL="https://raw.githubusercontent.com/hashicorp/vagrant/dc55920a284544919340b975098b4ac9005b08b0/keys/vagrant.pub"

log() { printf '[images] %s\n' "$*"; }
die() { printf '[images] ERROR: %s\n' "$*" >&2; exit 1; }

case "$EDITION" in
  1) ENAME=minimal ;; 2) ENAME=developer ;; 3) ENAME=cloud-native ;; 4) ENAME=full ;;
  *) die "edition must be 1-4" ;;
esac
[[ $EUID -eq 0 ]] || die "must run as root (pacstrap)"
mkdir -p "$OUT_DIR" "$WORK_DIR"

# Packages that only make sense on the live ISO / bare metal.
ISO_ONLY=(mkinitcpio-archiso squashfs-tools memtest86+ memtest86+-efi edk2-shell syslinux amd-ucode intel-ucode)
# Additionally not wanted in WSL (WSL provides kernel, init networking, DNS).
WSL_DROP=(linux mkinitcpio dhcpcd networkmanager nftables)

read_pkgs() {
  local f
  for f in "$ROOT_DIR/editions/base.packages" "$ROOT_DIR/editions/${ENAME}.packages"; do
    [[ -f "$f" ]] && grep -hv -e '^\s*#' -e '^\s*$' "$f" | awk '{print $1}'
  done | sort -u
}

# pkgs_without <drop...>: edition packages minus the given names
pkgs_without() {
  local drop=" $* " p
  while read -r p; do
    [[ "$drop" == *" $p "* ]] || echo "$p"
  done < <(read_pkgs)
}

pacstrap_root() {
  local root="$1"; shift
  rm -rf "$root"; mkdir -p "$root"
  log "pacstrap $(($#)) packages -> $root"
  # -C: our pacman.conf (NoExtract docs/man/locales); -K: fresh keyring (removed below)
  pacstrap -C "$ROOT_DIR/profile/pacman.conf" -K -c "$root" "$@"
}

common_config() {
  local root="$1"
  echo warble > "$root/etc/hostname"
  ln -sf /usr/share/zoneinfo/UTC "$root/etc/localtime"
  echo 'en_US.UTF-8 UTF-8' > "$root/etc/locale.gen"
  echo 'LANG=en_US.UTF-8' > "$root/etc/locale.conf"
  arch-chroot "$root" locale-gen >/dev/null
  { echo "ID=warble-linux"; echo "NAME=\"Warble Linux\""; echo "VERSION=$VERSION"; echo "VARIANT=$ENAME"; } > "$root/etc/warble-release"
  # Never ship a shared pacman keyring / machine-id: recreate on first boot.
  rm -rf "$root/etc/pacman.d/gnupg"
  install -Dm644 "$ROOT_DIR/images/pacman-init.service" "$root/etc/systemd/system/pacman-init.service"
  mkdir -p "$root/etc/systemd/system/multi-user.target.wants"
  ln -sf /etc/systemd/system/pacman-init.service "$root/etc/systemd/system/multi-user.target.wants/pacman-init.service"
  : > "$root/etc/machine-id"
  rm -rf "$root/var/cache/pacman/pkg/"* "$root/var/lib/pacman/sync/"* "$root/var/log/"*.log
}

check_size() {
  local f="$1" s
  s=$(stat -c%s "$f")
  log "$(basename "$f"): $s bytes ($((s / 1024 / 1024)) MiB)"
  (( s < MAX_ASSET_BYTES )) || die "$(basename "$f") is $s bytes, over the ${MAX_ASSET_BYTES}-byte guard"
}

build_wsl() {
  local root="$WORK_DIR/wsl-root" out="$OUT_DIR/warble-linux-wsl2-${ENAME}-${VERSION}.tar.gz"
  mapfile -t pkgs < <(pkgs_without "${ISO_ONLY[@]}" "${WSL_DROP[@]}")
  pacstrap_root "$root" "${pkgs[@]}"
  common_config "$root"
  arch-chroot "$root" useradd -m -G wheel -s /bin/bash warble
  arch-chroot "$root" passwd -l warble >/dev/null
  install -Dm440 /dev/stdin "$root/etc/sudoers.d/10-warble" <<<'warble ALL=(ALL:ALL) NOPASSWD: ALL'
  install -Dm644 "$ROOT_DIR/images/wsl.conf" "$root/etc/wsl.conf"
  rm -f "$root/etc/resolv.conf"            # WSL generates it
  rm -rf "$root/boot/"*                    # no kernel / bootloader in WSL
  log "packing WSL rootfs"
  (cd "$root" && bsdtar --numeric-owner --xattrs -czf "$out" --exclude './dev/*' --exclude './proc/*' --exclude './sys/*' --exclude './run/*' --exclude './tmp/*' .)
  check_size "$out"
}

build_disk() {
  local root="$WORK_DIR/disk-root" img="$WORK_DIR/disk"
  local base="warble-linux-${ENAME}-${VERSION}"
  mapfile -t pkgs < <(pkgs_without "${ISO_ONLY[@]}" networkmanager dhcpcd)
  pkgs+=(openssh)
  pacstrap_root "$root" "${pkgs[@]}"
  common_config "$root"

  # vagrant user, insecure key, passwordless sudo (Vagrant box conventions)
  arch-chroot "$root" useradd -m -G wheel -s /bin/bash vagrant
  echo 'vagrant:vagrant' | arch-chroot "$root" chpasswd
  install -d -m700 -o 1000 -g 1000 "$root/home/vagrant/.ssh"
  curl -fsSL "$VAGRANT_PUB_URL" -o "$root/home/vagrant/.ssh/authorized_keys"
  grep -q 'vagrant insecure public key' "$root/home/vagrant/.ssh/authorized_keys" || die "bad vagrant key download"
  chown 1000:1000 "$root/home/vagrant/.ssh/authorized_keys"; chmod 600 "$root/home/vagrant/.ssh/authorized_keys"
  install -Dm440 /dev/stdin "$root/etc/sudoers.d/10-vagrant" <<<'vagrant ALL=(ALL:ALL) NOPASSWD: ALL'
  printf 'UseDNS no\nPermitRootLogin no\n' > "$root/etc/ssh/sshd_config.d/10-warble.conf"

  # Networking: systemd-networkd DHCP on any wired NIC, resolved for DNS
  install -Dm644 "$ROOT_DIR/images/20-wired.network" "$root/etc/systemd/network/20-wired.network"
  ln -sf /run/systemd/resolve/stub-resolv.conf "$root/etc/resolv.conf"
  # Firewall: same deny-inbound policy as the ISO, plus SSH for Vagrant
  sed 's/^\(\s*\)udp sport 67 udp dport 68 accept/\1tcp dport 22 accept   # SSH (Vagrant)\n\1udp sport 67 udp dport 68 accept/' \
    "$ROOT_DIR/profile/airootfs/etc/nftables.conf" > "$root/etc/nftables.conf"
  grep -q 'tcp dport 22 accept' "$root/etc/nftables.conf" || die "nftables ssh rule not added"
  arch-chroot "$root" systemctl enable sshd systemd-networkd systemd-resolved nftables >/dev/null

  # Generic initramfs (no autodetect: the build host is not the target VM)
  install -Dm644 "$ROOT_DIR/images/mkinitcpio-vm.conf" "$root/etc/mkinitcpio.conf.d/10-vm.conf"
  sed -i "s/^PRESETS=.*/PRESETS=('default')/" "$root/etc/mkinitcpio.d/linux.preset"
  rm -f "$root/boot/initramfs-linux-fallback.img"
  arch-chroot "$root" mkinitcpio -P
  printf 'LABEL=WARBLE_ROOT / ext4 rw,relatime 0 1\nLABEL=WBOOT /boot vfat rw,relatime,fmask=0022,dmask=0022 0 2\n' > "$root/etc/fstab"

  # /boot (FAT32, 512 MiB): kernel, initramfs, syslinux (BIOS), systemd-boot (UEFI)
  local cmdline="root=LABEL=WARBLE_ROOT rw console=tty0 console=ttyS0,115200 systemd.firstboot=off"
  rm -rf "$img"; mkdir -p "$img"
  mkfs.fat -F32 -n WBOOT -C "$img/boot.img" $((512 * 1024)) >/dev/null
  export MTOOLS_SKIP_CHECK=1
  mmd -i "$img/boot.img" ::/syslinux ::/EFI ::/EFI/BOOT ::/loader ::/loader/entries
  mcopy -i "$img/boot.img" "$root/boot/vmlinuz-linux" "$root/boot/initramfs-linux.img" ::/
  printf 'DEFAULT warble\nPROMPT 0\nTIMEOUT 10\nLABEL warble\n  LINUX /vmlinuz-linux\n  INITRD /initramfs-linux.img\n  APPEND %s\n' "$cmdline" > "$img/syslinux.cfg"
  mcopy -i "$img/boot.img" "$img/syslinux.cfg" ::/syslinux/
  mcopy -i "$img/boot.img" "$root/usr/lib/systemd/boot/efi/systemd-bootx64.efi" ::/EFI/BOOT/BOOTX64.EFI
  printf 'default warble.conf\ntimeout 1\n' > "$img/loader.conf"
  printf 'title Warble Linux\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions %s\n' "$cmdline" > "$img/warble.conf"
  mcopy -i "$img/boot.img" "$img/loader.conf" ::/loader/
  mcopy -i "$img/boot.img" "$img/warble.conf" ::/loader/entries/
  syslinux --directory /syslinux --install "$img/boot.img"
  rm -rf "$root/boot/"*

  # Root ext4 sized to content + 2 GiB headroom, populated without mounting
  local used_mb root_mb
  used_mb=$(du -sm --apparent-size "$root" | cut -f1)
  root_mb=$(( used_mb * 115 / 100 + 2048 ))
  mkfs.ext4 -q -F -L WARBLE_ROOT -d "$root" "$img/root.img" "${root_mb}M"

  # MBR disk: p1 FAT (type ef, active: BIOS via syslinux MBR, UEFI via ESP type), p2 ext4
  local total_mb=$(( 1 + 512 + root_mb ))
  truncate -s "${total_mb}M" "$img/disk.raw"
  sfdisk -q "$img/disk.raw" <<SFD
label: dos
start=2048, size=$((512 * 2048)), type=ef, bootable
start=$(( 2048 + 512 * 2048 )), type=83
SFD
  dd if="$img/boot.img" of="$img/disk.raw" bs=1M seek=1 conv=notrunc,sparse status=none
  dd if="$img/root.img" of="$img/disk.raw" bs=1M seek=513 conv=notrunc,sparse status=none
  dd if=/usr/lib/syslinux/bios/mbr.bin of="$img/disk.raw" bs=440 count=1 conv=notrunc status=none
  rm -f "$img/boot.img" "$img/root.img"

  # Vagrant libvirt box: plain tar (qcow2 is already compressed)
  local vgb_gb=$(( (total_mb + 1023) / 1024 ))
  qemu-img convert -c -O qcow2 "$img/disk.raw" "$img/box.img"
  printf '{"provider":"libvirt","format":"qcow2","virtual_size":%d}\n' "$vgb_gb" > "$img/metadata.json"
  install -m644 "$ROOT_DIR/images/Vagrantfile.libvirt" "$img/Vagrantfile"
  (cd "$img" && bsdtar -cf "$OUT_DIR/${base}-libvirt.box" metadata.json Vagrantfile box.img)
  check_size "$OUT_DIR/${base}-libvirt.box"

  # OVA: OVF descriptor first, then a streamOptimized VMDK, then the manifest
  qemu-img convert -O vmdk -o subformat=streamOptimized "$img/disk.raw" "$img/${base}-disk1.vmdk"
  local vmdk_size cap_bytes
  vmdk_size=$(stat -c%s "$img/${base}-disk1.vmdk")
  cap_bytes=$(stat -c%s "$img/disk.raw")
  sed -e "s/@NAME@/Warble-Linux-${ENAME}-${VERSION}/g" -e "s/@VMDK@/${base}-disk1.vmdk/g" \
      -e "s/@VMDK_SIZE@/${vmdk_size}/g" -e "s/@CAPACITY@/${cap_bytes}/g" \
      "$ROOT_DIR/images/template.ovf" > "$img/${base}.ovf"
  (cd "$img" && { echo "SHA256(${base}.ovf)= $(sha256sum "${base}.ovf" | cut -d' ' -f1)"
                  echo "SHA256(${base}-disk1.vmdk)= $(sha256sum "${base}-disk1.vmdk" | cut -d' ' -f1)"; } > "${base}.mf")
  (cd "$img" && bsdtar --format ustar -cf "$OUT_DIR/${base}.ova" "${base}.ovf" "${base}-disk1.vmdk" "${base}.mf")
  check_size "$OUT_DIR/${base}.ova"
  rm -f "$img/disk.raw" "$img/${base}-disk1.vmdk"
}

case "$WHAT" in
  wsl) build_wsl ;;
  disk) build_disk ;;
  all) build_wsl; build_disk ;;
  *) die "unknown target: $WHAT" ;;
esac
(cd "$OUT_DIR" && sha256sum -- *.tar.gz *.box *.ova 2>/dev/null > "SHA256SUMS-images-${ENAME}.txt" || true)
log "done: $(ls "$OUT_DIR")"
