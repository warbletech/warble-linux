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

Publishes **only real, boot-tested ISOs**. Flow: resolve version → for each
published edition call `real-iso.yml` (mkarchiso + QEMU BIOS/UEFI boot test) →
verify `mock=no`, size < 2 GiB and checksums → attest provenance → upload
ISO + MANIFEST + `SHA256SUMS.txt` to the release (Latest for stable tags).
WSL / OVF / Vagrant stubs are never uploaded.

Real editions published today: **1 (minimal)**. Add more to the `real` job
matrix only after they build, stay under 2 GiB and boot in CI.

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
