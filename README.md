# Warble Linux

<p align="center">
  <img src="assets/logo.jpg" alt="Warble Linux" width="160"/>
</p>

**Sandbox-oriented Linux live images** for isolated testing, learning, and
cloud-native workflows — open source, rebuildable, multi-format.

[![Build & nightly](https://github.com/warbletech/warble-linux/actions/workflows/publish.yml/badge.svg)](https://github.com/warbletech/warble-linux/actions/workflows/publish.yml)
[![Release](https://github.com/warbletech/warble-linux/actions/workflows/release.yml/badge.svg)](https://github.com/warbletech/warble-linux/actions/workflows/release.yml)
[![License: GPL-2.0](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](LICENSE)
[![semver](https://img.shields.io/badge/semver-0.3.0-blue.svg)](VERSION)

Part of the Warble ecosystem · MCP ops demo: [mcp.warbleoss.org](https://mcp.warbleoss.org)

## Releases & versioning

**[Semver](https://semver.org/)** lives in [`VERSION`](VERSION). Details: [docs/releases.md](docs/releases.md).

| Kind | Tag | Trigger |
|------|-----|---------|
| **Stable** | `vX.Y.Z` | Tag push → [Release workflow](https://github.com/warbletech/warble-linux/actions/workflows/release.yml): real ISO, boot-tested, provenance-attested |
| **Nightly** | `vX.Y.Z-nightly.N` | Push to `main` (prerelease, **mock** artifacts) |

| | |
|--|--|
| **Latest stable** | [Releases · Latest](https://github.com/warbletech/warble-linux/releases/latest) |
| **All releases** | [github.com/warbletech/warble-linux/releases](https://github.com/warbletech/warble-linux/releases) |

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing          # after download
gh attestation verify warble-linux-*.iso -R warbletech/warble-linux

# Maintainers — cut a stable release (see docs/releases.md)
make bump-minor            # in a PR; main is protected
git tag -a "v$(cat VERSION)" -m "Warble Linux v$(cat VERSION)" && git push origin "v$(cat VERSION)"
```

---

## Why Warble Linux?

| You want… | Warble gives you… |
|-----------|-------------------|
| A disposable lab | Live-oriented images; RAM-first sandbox mindset |
| Clear package choices | Four **editions** with reviewable package lists |
| CI-friendly artifacts | ISO · WSL tarball · OVF · Vagrant `.box` · checksums |
| Open governance | GPL-2.0, CoC, security policy, contributing guide |

This is **not** a full daily-driver desktop (see [Omarchy](https://omarchy.org) for that style of distro). Warble is an **artifact factory + live profile** for sandboxes.

## Editions

| # | Name | Focus |
|---|------|--------|
| 1 | **Minimal** | Openbox + Firefox + Terminator |
| 2 | **Developer** | Go, Rust, Python, Node, Neovim, CLI tools |
| 3 | **Cloud-Native** | Docker, kubectl, helm |
| 4 | **Full** | Developer + Cloud-Native |

Package sources of truth: [`editions/`](editions/). Details: [docs/editions.md](docs/editions.md).

## Quick start

```bash
git clone https://github.com/warbletech/warble-linux.git
cd warble-linux

make bake EDITION=1       # one edition
make all-editions         # 1–4 → out/
make test-artifacts       # validate ISO / WSL / OVF / box / checksums
make release-check        # lint + all editions + artifact tests
make check                # lint + mock minimal bake
```

On Ubuntu/macOS (no `mkarchiso`), builds produce **valid non-empty mock** packages
suitable for CI and release pipelines. Real bootable ISOs need Arch + a complete
archiso profile — see [docs/building.md](docs/building.md).

```bash
# Real bootable ISO (Arch host + profile bootloaders — now in-tree)
sudo pacman -S archiso
make bake EDITION=4

# Or Docker (privileged Arch container):
EDITION=1 ./scripts/docker-bake.sh
```

## Repository layout

```text
editions/     # package lists (edit these)
profile/      # archiso airootfs + profiledef
scripts/      # make-and-bake, multi-edition, optional GCP push
docs/         # architecture, building, editions
assets/       # branding
out/          # build products (gitignored)
```

## CI

GitHub-hosted **`ubuntu-24.04`** only (pinned) (no self-hosted runners). All actions are
pinned to full commit SHAs; workflow tokens are read-only except on publish jobs.

| Workflow | What it does |
|----------|--------------|
| [`real-iso.yml`](.github/workflows/real-iso.yml) | **Real** `mkarchiso` build of edition 1 in a privileged Arch container (fails on mock), then a headless QEMU boot test (BIOS + UEFI) that waits for a serial `login:` prompt. Provenance attested on `main`. |
| [`publish.yml`](.github/workflows/publish.yml) | Matrix bake of editions 1–4, artifact tests, nightly prerelease on `main` (labeled **MOCK** when built without `mkarchiso`). |
| [`release.yml`](.github/workflows/release.yml) | Stable releases on `vX.Y.Z` tags: real ISO(s) via `real-iso.yml`, boot-tested, provenance-attested; mock artifacts are never published. Dispatch `dry_run` → draft release. |
| [`gitleaks.yml`](.github/workflows/gitleaks.yml) | Secret scan of the full git history on every push/PR. |

Verify a downloaded artifact: `sha256sum -c SHA256SUMS-*.txt` and
`gh attestation verify <file> -R warbletech/warble-linux`.

## Live helpers (full image goal)

Under `/usr/local/bin` when the live rootfs is complete:

- `mount-wsl.sh` · `mount-vagrant.sh` · `mount-filestorage.sh`

## Status

| Area | Status |
|------|--------|
| Mock artifacts + CI prerelease | **Working** |
| Modular editions + Makefile | **Working** |
| Bootloaders (syslinux/grub/efiboot) | **In tree** — [docs/bootloaders.md](docs/bootloaders.md) |
| Full real ISO on public CI | **WIP** (use Arch host or `docker-bake.sh`) |
| Real WSL / Vagrant disks | Stubs |
| GCP registry push | Optional (`scripts/push-to-gcp.sh`, `DRY_RUN=1` default) |

## Contributing

We welcome issues and PRs. Start here:

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [SECURITY.md](SECURITY.md)
- [SUPPORT.md](SUPPORT.md)

## License

Warble Linux is free software under the **GNU General Public License v2.0**.
See [LICENSE](LICENSE).

Exception: the vendored archiso bootloader configs under `profile/syslinux/`,
`profile/grub/` and `profile/efiboot/` are **GPL-3.0-or-later** (adapted from
Arch Linux archiso releng). See [NOTICE](NOTICE) and
[profile/BOOTLOADERS.NOTICE](profile/BOOTLOADERS.NOTICE).

Third-party packages inside a built image remain under their own licenses
(Arch Linux and upstream projects); see [NOTICE](NOTICE) for where to obtain
their corresponding source.
