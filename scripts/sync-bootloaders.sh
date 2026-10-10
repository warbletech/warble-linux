#!/bin/bash
# Refresh profile/{syslinux,grub,efiboot} from upstream archiso releng.
# Re-applies Warble menu branding. Requires network + git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/profile"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

log() { printf '==> %s\n' "$*"; }

log "Cloning archlinux/archiso (sparse releng bootloaders)..."
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/archlinux/archiso.git "$TMP/archiso"
git -C "$TMP/archiso" sparse-checkout set \
  configs/releng/syslinux configs/releng/grub configs/releng/efiboot

for d in syslinux grub efiboot; do
  rm -rf "${DEST:?}/${d:?}"
  cp -a "$TMP/archiso/configs/releng/$d" "$DEST/$d"
done

log "Applying Warble branding to menus..."
sed -i 's/MENU TITLE Arch Linux/MENU TITLE Warble Linux/' \
  "$DEST/syslinux/archiso_head.cfg"

sed -i \
  -e 's/Arch Linux install medium/Warble Linux live sandbox/g' \
  -e 's/Boot the Arch Linux install medium/Boot the Warble Linux live sandbox/g' \
  -e 's/Boot the Arch Linux live medium/Boot the Warble Linux live sandbox/g' \
  -e 's/It allows you to install Arch Linux or perform system maintenance\./Ephemeral sandbox for testing, learning, and cloud-native workflows./g' \
  -e 's/It allows you to install Arch Linux or perform system maintenance with speech feedback\./Ephemeral sandbox with speech feedback for accessibility./g' \
  "$DEST/syslinux/archiso_sys-linux.cfg" \
  "$DEST/syslinux/archiso_pxe-linux.cfg"

sed -i -e 's/Arch Linux install medium/Warble Linux live sandbox/g' \
  "$DEST/grub/grub.cfg" "$DEST/grub/loopback.cfg"

sed -i -e 's/Arch Linux install medium/Warble Linux live sandbox/g' \
  "$DEST/efiboot/loader/entries/01-archiso-linux.conf" \
  "$DEST/efiboot/loader/entries/02-archiso-speech-linux.conf"

cat > "$DEST/BOOTLOADERS.NOTICE" << 'EOF'
Bootloader configuration under syslinux/, grub/, and efiboot/ is adapted from
Arch Linux archiso "releng" profile:

  https://github.com/archlinux/archiso
  configs/releng/{syslinux,grub,efiboot}

archiso is licensed under GPL-3.0-or-later (see upstream). Menu titles and help
text were rebranded for Warble Linux; kernel command-line tokens required by
archiso (archisobasedir, archisosearchuuid, %INSTALL_DIR%, etc.) are unchanged.

To refresh from upstream:
  ./scripts/sync-bootloaders.sh
EOF

log "Done. Review diffs under profile/{syslinux,grub,efiboot}."
