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
warble-linux-wsl2-<edition>-<VERSION>.tar.gz
warble-linux-<edition>-<VERSION>.ovf
warble-linux-<edition>-<VERSION>.box
MANIFEST-<edition>-<VERSION>.txt
SHA256SUMS-<edition>-<VERSION>.txt
```

Examples:

- Nightly: `warble-linux-full-0.2.0-nightly.12-abc1234.iso`
- Stable: `warble-linux-full-0.2.0-abc1234.iso`
