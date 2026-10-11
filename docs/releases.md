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

Triggers:

- Push tag matching `v*.*.*`
- Manual **workflow_dispatch** with:
  - `bump`: `none` | `patch` | `minor` | `major`
  - `version`: exact `X.Y.Z` (optional)
  - `prerelease`: boolean

Dispatch flow bumps `VERSION`, commits, tags `vX.Y.Z`, bakes all editions,
tests, publishes a GitHub Release (latest).

```bash
# CLI
gh workflow run release.yml -f bump=patch
gh workflow run release.yml -f version=1.0.0
# or local tag
git tag v0.2.0 && git push origin v0.2.0
```

### Real ISO — `.github/workflows/real-iso.yml`

Push to `main`, PRs, manual dispatch (choose edition). Builds a real ISO with
`mkarchiso` (`REQUIRE_REAL=1`), checks `mock=no`, size and the archiso
initramfs hook, then boots it in QEMU (BIOS + UEFI) until a serial `login:`
prompt appears. The ISO is a workflow artifact (5-day retention) with SLSA
provenance on `main`.

### Mock labeling

`publish.yml` / `release.yml` still bake on Ubuntu without `mkarchiso`. When
any MANIFEST says `mock=yes`, the release title is suffixed **(MOCK, not
bootable)**, it is marked prerelease, and it is never set as Latest.

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
