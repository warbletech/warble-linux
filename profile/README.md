# archiso profile

This directory is an [archiso](https://wiki.archlinux.org/title/Archiso) profile
for **Warble Linux** live images.

| Path | Role |
|------|------|
| `profiledef.sh` | ISO metadata, boot modes, squashfs options |
| `pacman.conf` | pacman config used during `mkarchiso` |
| `packages.x86_64` | **Generated** by `scripts/make-and-bake.sh` from `editions/` |
| `airootfs/` | Overlay root filesystem for the live image |
| `syslinux/` | BIOS boot menus (from archiso releng, rebranded) |
| `grub/` | UEFI GRUB configs (from archiso releng, rebranded) |
| `efiboot/` | systemd-boot style EFI loader entries |
| `BOOTLOADERS.NOTICE` | Upstream provenance for bootloader trees |

## Real bake (Arch host)

```bash
sudo pacman -S archiso
cd /path/to/warble-linux
make bake EDITION=4
```

Requires: network (pacman mirrors), root/sudo for `mkarchiso`, ~10–20 GB free disk.

## Refresh bootloaders

```bash
./scripts/sync-bootloaders.sh
```

## Docker (optional)

```bash
EDITION=1 ./scripts/docker-bake.sh
```

See [docs/building.md](../docs/building.md).
