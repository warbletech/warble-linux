# Releases

## Semver

| File | Role |
|------|------|
| [`VERSION`](../VERSION) | Base version `MAJOR.MINOR.PATCH` |

```bash
make version                 # print
make bump-patch              # 0.2.0 → 0.2.1
./scripts/version.sh nightly 12   # → v0.2.0-nightly.12
./scripts/version.sh tag          # → v0.2.0
```

## Workflows

### Build & nightly — `.github/workflows/publish.yml`

Triggers: push/`main`, pull_request, workflow_dispatch.

1. Resolve semver from `VERSION`
2. Matrix bake editions 1–4 (`VERSION=X.Y.Z-nightly.N`)
3. `test-artifacts`
4. On `main` only: GitHub **prerelease** tag `vX.Y.Z-nightly.N`

### Release — `.github/workflows/release.yml`

Publishes **only real, boot-tested ISOs**. Flow: resolve version → build and
boot-test **every edition (1–4)** via `real-iso.yml` (mkarchiso + QEMU BIOS/UEFI
boot test; build fails if an ISO is ≥ 1.9 GiB) → `publish` runs even if some
editions failed and uploads only editions with `mock=no`, valid checksums and
**both** boot-success markers → attest provenance → upload ISO + MANIFEST +
`SHA256SUMS.txt` (Latest for stable tags). Skipped editions are listed in the
release notes; the release fails if no edition passed. Stubs are never uploaded.

Sizes after the VM-first size cuts (CI, 2026-10-11; GitHub asset limit 2 GiB,
CI guard 1.9 GiB):

| Edition | ISO size | Boot BIOS / UEFI | Run |
|---------|----------|------------------|-----|
| 1 minimal | 803,549,184 B (766 MiB) | yes / yes | [38105445405](https://github.com/warbletech/warble-linux/actions/runs/38105445405) |
| 2 developer | 1,085,308,928 B (1035 MiB) | yes / yes | [38105446911](https://github.com/warbletech/warble-linux/actions/runs/38105446911) |
| 3 cloud-native | 909,455,360 B (867 MiB) | yes / yes | [38105448327](https://github.com/warbletech/warble-linux/actions/runs/38105448327) |
| 4 full | 1,189,707,776 B (1135 MiB) | yes / yes | [38105450072](https://github.com/warbletech/warble-linux/actions/runs/38105450072) |

Before the size cuts, edition 1 was 1,691,418,624 B and edition 4 was 2,093,498,368 B.

**Size cuts:**
- The images are VM-first: there is no `linux-firmware`, so bare-metal Wi-Fi and GPUs that need firmware won't work.
- No GRUB: UEFI boots via systemd-boot and BIOS via syslinux.
- No PXE/netboot initramfs hooks.
- `NoExtract` drops docs, man/info pages and translations.
- squashfs already uses the strongest archiso setting (`xz -Xbcj x86 -b 1M`), so compression is unchanged.

The CI guard is `MAX_ISO_BYTES` in `real-iso.yml`.

Triggers:

- Push tag `vX.Y.Z` (must equal `VERSION`) → stable release, marked Latest.
  `vX.Y.Z-rc.N` → prerelease.
- `workflow_dispatch` with `dry_run=true` (from any branch) → same build and
  boot test, uploads to a **draft** release `dryrun-<run_id>`; nothing is
  tagged. Delete the draft afterwards.

```bash
# 1. bump VERSION in a PR (main is protected), merge it
make bump-minor            # 0.2.0 -> 0.3.0, commit + PR
# 2. tag the merged commit on main
git checkout main && git pull
git tag -a v0.3.0 -m "Warble Linux v0.3.0" && git push origin v0.3.0
# dry run from a branch
gh workflow run release.yml --ref <branch> -f dry_run=true
```

### WSL / Vagrant / OVA images — `.github/workflows/images.yml`

`scripts/build-images.sh <edition> all` pacstraps the edition's packages, without the live-ISO-only packages, in a privileged Arch container. The live ISO has no installer or sshd, so a pacstrap build replaces "Packer drives the ISO". It produces:

| Asset | What it is | CI test |
|-------|-----------|---------|
| `warble-linux-wsl2-<edition>-<ver>.tar.gz` | WSL2 rootfs. No kernel or bootloader. `/etc/wsl.conf`: `systemd=true`, default user `warble` (passwordless sudo, locked password); WSL generates `resolv.conf`. No firewall or NetworkManager, because WSL owns networking. | Tar structure (no `/boot` kernel, wsl.conf values), `docker import` + smoke commands as `warble` (sudo, pacman, git) |
| `warble-linux-<edition>-<ver>-libvirt.box` | Vagrant box (libvirt, qcow2). MBR disk: FAT32 `/boot` with syslinux (BIOS) and systemd-boot (UEFI), ext4 root. User `vagrant`/`vagrant` with Vagrant's insecure key (pinned commit) and passwordless sudo, sshd, systemd-networkd DHCP, nftables (deny inbound except tcp/22) | QEMU/KVM boot (BIOS **and** UEFI), SSH login as `vagrant` (Vagrant insecure keypair), then checks for sudo, the firewall rule and mounts; VM destroyed |
| `warble-linux-<edition>-<ver>.ova` | OVF 1.0 + streamOptimized VMDK of the same disk (VirtualBox/VMware, SATA + E1000) | OVF-first tar layout, `.mf` checksums, `qemu-img` VMDK check. **Not boot-tested in VirtualBox** (no VirtualBox on hosted runners). |

A test that passes uploads an `imgok-*` marker. `release.yml` calls `images.yml` for editions 1–4 and publishes:
- a WSL tarball only if its WSL test passed
- a box and OVA only if the box passed **both** the BIOS and UEFI SSH tests

Release notes list anything skipped. Each image must be under the 1.9 GiB guard. The pacman keyring and machine-id are generated on first boot and never shipped.

Windows `wsl --import` is not tested in CI. GitHub-hosted Windows runners lack nested virtualization, so WSL2 cannot run there.

### Disposable sandbox (create → use → destroy)

```bash
# ISO: live and RAM-only. Quit QEMU to destroy it.
qemu-system-x86_64 -enable-kvm -m 2048 -smp 2 -snapshot -nic user -cdrom warble-linux-<edition>-<ver>-<sha>.iso -boot d
# WSL2 (PowerShell)
wsl --import warble-sbx $env:LOCALAPPDATA\warble-sbx .\warble-linux-wsl2-<edition>-<ver>.tar.gz --version 2
wsl -d warble-sbx
wsl --unregister warble-sbx
# Vagrant + libvirt
vagrant box add --name warble/<edition> warble-linux-<edition>-<ver>-libvirt.box
vagrant init warble/<edition> && vagrant up --provider=libvirt && vagrant ssh
vagrant destroy -f && vagrant box remove warble/<edition>
# OVA (VirtualBox; untested)
VBoxManage import warble-linux-<edition>-<ver>.ova --vsys 0 --vmname warble-sbx && VBoxManage startvm warble-sbx --type headless
VBoxManage controlvm warble-sbx poweroff && VBoxManage unregistervm warble-sbx --delete
```

### Real ISO — `.github/workflows/real-iso.yml`

Push to `main`, PRs, manual dispatch (choose edition). Builds a real ISO with
`mkarchiso` (`REQUIRE_REAL=1`), checks `mock=no`, size and the archiso
initramfs hook, then boots it in QEMU (BIOS + UEFI) until a serial `login:`
prompt appears. The ISO is a workflow artifact (5-day retention) with SLSA
provenance on `main`.

### Mock labeling

`publish.yml` (nightly) still bakes mock artifacts on Ubuntu without
`mkarchiso`; those prereleases are titled **(MOCK artifacts, not bootable)**
and are never set as Latest. `release.yml` never publishes mock artifacts.

## Artifact names

```text
warble-linux-<edition>-<VERSION>-<gitsha>.iso
warble-linux-wsl2-<edition>-<VERSION>.tar.gz      # release: only if WSL test passed
warble-linux-<edition>-<VERSION>-libvirt.box       # release: only if BIOS+UEFI SSH tests passed
warble-linux-<edition>-<VERSION>.ova               # release: with the box (same disk)
MANIFEST-<edition>-<VERSION>.txt
SHA256SUMS-<edition>-<VERSION>.txt
```

Examples:

- Nightly: `warble-linux-full-0.2.0-nightly.12-abc1234.iso`
- Stable: `warble-linux-full-0.2.0-abc1234.iso`
