#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="warble-linux"
iso_label="WARBLE_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Warble Linux <https://github.com/warbletech/warble-linux>"
iso_application="Warble Linux live sandbox"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
# Current (non-deprecated) archiso boot modes, as in upstream releng:
# BIOS via syslinux (profile/syslinux), UEFI via systemd-boot (profile/efiboot).
# profile/grub is kept for anyone switching to 'uefi.grub'.
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.xinitrc"]="0:0:755"
  ["/etc/profile.d/warble-tutorial.sh"]="0:0:755"
  ["/etc/profile.d/zz-warble-motd.sh"]="0:0:755"
  ["/usr/local/bin/warble-wallpaper"]="0:0:755"
  ["/usr/local/bin/mount-filestorage.sh"]="0:0:755"
  ["/usr/local/bin/mount-vagrant.sh"]="0:0:755"
  ["/usr/local/bin/mount-wsl.sh"]="0:0:755"
)
