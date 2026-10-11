# Local build → test → publish

CI and your desktop run **the same three scripts**:

| Stage | Script | `make` | CI |
|-------|--------|--------|----|
| build | `scripts/build.sh iso\|images\|all <edition> [--docker]` | `make build EDITION=1 [WHAT=iso\|images\|all] [DOCKER=1]` | `real-iso.yml` / `images.yml` build jobs (privileged Arch container) |
| test | `scripts/test.sh iso-verify\|iso\|wsl\|vm\|ova\|all …` | `make test` | `real-iso.yml` boot jobs, `images.yml` wsl/vm jobs |
| publish | `scripts/publish.sh [--draft-release]` | `make publish [DRAFT=1]` | `release.yml` publish job |

Artifacts flow from `out/` (build) to `out/ok/` markers (test) to `out/release-assets/` (publish).
`publish.sh` only takes artifacts that have passing test markers, so an untested or failed artifact cannot be published.

## Prerequisites

| For | Linux desktop | Notes |
|-----|---------------|-------|
| **Build** | Either Arch Linux with root (`sudo scripts/build.sh deps` installs archiso, arch-install-scripts, syslinux, mtools, dosfstools, e2fsprogs, qemu-img, …) **or** any Linux with Docker (`--docker` / `DOCKER=1` runs the pinned `archlinux:base-20261004.0.606936` image with `--privileged`) | Needs about 15 GB free disk per edition, plus a network connection for packages. A build takes 10–25 min. |
| ISO / Vagrant box tests | `qemu-system-x86_64`, `qemu-img`, OVMF (`ovmf` on Debian/Ubuntu, `edk2-ovmf` on Arch/Fedora), `ssh`, `curl`, `python3` | Use KVM (`/dev/kvm` writable by you). Without it, tests fall back to slow TCG. |
| WSL tarball test (Linux side) | Docker | Runs `docker import` and smoke commands. |
| WSL for real | Windows 10/11 with WSL2 (`wsl --install`) | CI cannot run WSL2: hosted Windows runners lack nested virtualization. |
| Vagrant | Vagrant ≥ 2.3 + the [vagrant-libvirt](https://vagrant-libvirt.github.io/vagrant-libvirt/) plugin, libvirt/KVM | `vagrant plugin install vagrant-libvirt` |
| OVA | VirtualBox ≥ 7 (or VMware) | **Not boot-tested in CI.** Please report results. |
| Publish (draft) | `gh` CLI logged in with `repo` scope | Optional. The default is a dry run. |

Packer is **not** needed. The live ISO has no installer or sshd, so the Vagrant/OVA disk is built with `pacstrap` from the same edition package lists (`scripts/build-images.sh`) instead of Packer driving the ISO.

## Commands

```bash
git clone https://github.com/warbletech/warble-linux.git && cd warble-linux

# 1. build edition 1 (ISO + WSL + Vagrant box + OVA) -> out/
make build EDITION=1 DOCKER=1          # any Linux with Docker
# or, on Arch:  sudo scripts/build.sh all 1

# 2. test everything in out/ -> markers in out/ok/, serial logs in out/logs/
make test
# single tests
scripts/test.sh iso  out/warble-linux-minimal-*.iso uefi
scripts/test.sh wsl  out/warble-linux-wsl2-minimal-*.tar.gz
scripts/test.sh vm   out/warble-linux-minimal-*-libvirt.box bios
scripts/test.sh ova  out/warble-linux-minimal-*.ova

# 3. publish: dry run (default) assembles out/release-assets/ + out/release-body.md
make publish
# optional: upload to a DRAFT prerelease, then delete it
make publish DRAFT=1
gh release delete dryrun-local-<timestamp> --yes --cleanup-tag
```

Real releases are only created by pushing a `vX.Y.Z` tag. That runs `release.yml`, which repeats build → test → publish on GitHub runners. See [releases.md](releases.md).

Size guard: `test.sh iso-verify` and `build-images.sh` fail at 1.9 GiB or more (`MAX_ISO_BYTES` / `MAX_ASSET_BYTES`). GitHub's per-asset limit is 2 GiB.

## Disposable sandboxes: create → use → destroy

Download the assets from a release, or use `out/`, and verify them first with `sha256sum -c SHA256SUMS.txt --ignore-missing`.

### ISO (live, RAM-only)
```bash
# create + use (BIOS; add -bios /usr/share/OVMF/OVMF_CODE.fd or pflash drives for UEFI)
qemu-system-x86_64 -enable-kvm -m 2048 -smp 2 -snapshot -nic user \
  -cdrom warble-linux-minimal-<ver>-<sha>.iso -boot d
# destroy: close the window / Ctrl-A X. Nothing was written anywhere (-snapshot, no disk).
```
It autologins as root on tty1. The firewall denies all inbound traffic.

### WSL2 (Windows, PowerShell)
```powershell
wsl --import warble-sbx $env:LOCALAPPDATA\warble-sbx .\warble-linux-wsl2-minimal-<ver>.tar.gz --version 2   # create
wsl -d warble-sbx                                   # use: user "warble", passwordless sudo, systemd on
wsl --unregister warble-sbx                         # destroy (deletes the VHDX)
Remove-Item -Recurse $env:LOCALAPPDATA\warble-sbx
```
`/etc/wsl.conf`: `systemd=true`, `default=warble`, `appendWindowsPath=false`. There is no kernel or bootloader; WSL supplies them.
The pacman keyring is created on first boot (`pacman-init.service`). If systemd is off, run `sudo pacman-key --init && sudo pacman-key --populate`.

### Vagrant (libvirt)
```bash
vagrant box add --name warble/minimal warble-linux-minimal-<ver>-libvirt.box      # create (import box)
mkdir warble-sbx && cd warble-sbx && vagrant init warble/minimal
vagrant up --provider=libvirt                                                      # create VM
vagrant ssh                                                                        # use
vagrant destroy -f && cd .. && rm -rf warble-sbx                                   # destroy VM
vagrant box remove warble/minimal                                                  # remove box
```
User `vagrant`/`vagrant` with passwordless sudo. Vagrant swaps the insecure key for a fresh key on first `up`.
The firewall allows only inbound SSH (tcp/22). The disk boots on BIOS (syslinux) and UEFI (systemd-boot).

### OVA (VirtualBox; not yet CI-tested)
```bash
VBoxManage import warble-linux-minimal-<ver>.ova --vsys 0 --vmname warble-sbx      # create
VBoxManage startvm warble-sbx --type headless                                      # use (or start from the GUI)
VBoxManage modifyvm warble-sbx --natpf1 "ssh,tcp,127.0.0.1,2222,,22"               # (while powered off) SSH: ssh -p 2222 vagrant@127.0.0.1
VBoxManage controlvm warble-sbx poweroff && VBoxManage unregistervm warble-sbx --delete   # destroy
```

### Checklist when testing on your desktop
- [ ] ISO boots on BIOS and UEFI (`make test`, or by hand above)
- [ ] WSL: `wsl --import` works; `systemctl is-system-running` reports running or degraded; `sudo pacman -Syu` works
- [ ] Vagrant: `vagrant up` / `ssh` / `destroy` cycle
- [ ] OVA in VirtualBox boots and gets network (please report: this is the untested format)
