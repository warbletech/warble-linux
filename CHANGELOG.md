# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.3.0] — 2026-10-11

First release with **real, boot-tested ISOs** (edition 1, minimal).

### Added

- Real `mkarchiso` build in CI (privileged Arch container) with a headless QEMU
  BIOS + UEFI boot test to a serial login prompt (`real-iso.yml`).
- Release workflow publishes only real, boot-tested ISOs + MANIFEST +
  SHA256SUMS with build provenance attestations; draft dry runs via dispatch.
- gitleaks secret scan, Dependabot for GitHub Actions and the bake image.

### Changed

- Bootable archiso profile (archiso hooks, releng basics, current boot modes,
  serial console, no interactive firstboot).
- Firewall: deny inbound, allow outbound (documented offline mode).
- Workflows: least-privilege tokens, actions pinned to commit SHAs, runners
  pinned to `ubuntu-24.04`.
- Full GPL-2.0 LICENSE text; links point to `warbletech/warble-linux`.

### Fixed

- Failed real builds no longer fall back silently to mock artifacts labelled `mock=no`.
- Mock artifacts are never published as a real release (v0.2.0 relabelled as mock).

## [0.2.0] — 2026-08-10

### Added

- Semver **`VERSION`** file + `scripts/version.sh` (`print` / `bump` / `nightly` / `tag`).
- GitHub Actions **Release** workflow (tag `vX.Y.Z` or dispatch with bump/set).
- Nightly prereleases use semver tags: `vX.Y.Z-nightly.N`.
- `scripts/test-artifacts.sh` + `make test-artifacts` / `make release-check`.
- CI `test-matrix` job before prerelease/release.
- archiso **releng** bootloaders under `profile/{syslinux,grub,efiboot}` (rebranded)
  + `scripts/sync-bootloaders.sh`, `scripts/docker-bake.sh`, `docs/bootloaders.md`.
- README releases & versioning section.

### Changed

- **Open-source redesign**: modular `editions/` package lists, `scripts/` layout,
  `Makefile`, architecture/building docs, CONTRIBUTING / CoC / SECURITY.
- Bake prefers `VERSION` file for artifact filenames (over date-only).
- Bake refuses real `mkarchiso` when syslinux/grub trees are missing
  (avoids half-broken profiles) and falls back to mock artifacts.

### Fixed

- (Prior) GitHub Releases reject 0-byte assets — mock path always emits non-empty files.

## [0.1.0] — 2026-08

- Initial public packaging: mock bake, four editions, prerelease workflow,
  airootfs helpers and Openbox live skeleton.
