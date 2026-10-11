# Building Warble Linux

## Quick start (any Linux / macOS / CI)

No Arch tools required. Produces **mock** (non-bootable) release artifacts that are non-empty and CI-safe:

```bash
make bake EDITION=1          # minimal
make all-editions            # all four editions → out/
make test-artifacts          # validate ISO / WSL / OVF / box / checksums
make release-check           # lint + all-editions + test-artifacts
```

Or:

```bash
EDITION=4 ./scripts/make-and-bake.sh
MOCK_ONLY=1 EDITION=2 ./scripts/make-and-bake.sh
```

Artifacts land in `out/`:

| Artifact | Description |
|----------|-------------|
| `warble-linux-<edition>-<ver>-<sha>.iso` | Real ISO when mkarchiso can run (failure is fatal); mock only when it cannot run or `MOCK_ONLY=1` |
| `warble-linux-wsl2-*.tar.gz` | WSL-style rootfs tarball (mock until full rootfs bake) |
| `warble-linux-*.ovf` | OVF stub for packaging pipelines |
| `warble-linux-*.box` | Vagrant box stub |
| `MANIFEST-*.txt` / `SHA256SUMS-*.txt` | Build metadata + checksums |

## Real bootable ISO (Arch host)

1. Install tools:

   ```bash
   sudo pacman -S archiso
   ```

2. (Bootloaders are vendored in-tree; see below.)

3. Build:

   ```bash
   make bake EDITION=4
   ```

The bake script only calls `mkarchiso` when:

- `mkarchiso` is on `PATH`
- `profile/profiledef.sh` and `profile/pacman.conf` exist
- `profile/syslinux/`, `profile/grub/` **or** `profile/efiboot/` is present

If those conditions hold, a real bake is attempted and **any `mkarchiso`
failure fails the build** (no silent mock fallback). If they do not hold, the
script builds mock artifacts and records `mock=yes` in the MANIFEST. Set
`REQUIRE_REAL=1` to fail instead of mocking (CI real-bake job and
`docker-bake.sh` do this).

## Bootloaders (landed)

`profile/syslinux`, `profile/grub`, and `profile/efiboot` are vendored from
archiso **releng** and rebranded. Details: [bootloaders.md](bootloaders.md).

```bash
./scripts/sync-bootloaders.sh   # refresh from upstream + re-apply branding
```

Also verify:

- `profile/packages.x86_64` is generated from `editions/*.packages` (do not hand-edit long-term)
- Live user / network / display defaults under `profile/airootfs/`

## Docker real bake (optional)

If you have Docker but not a native Arch host:

```bash
EDITION=1 ./scripts/docker-bake.sh
```

This builds an Arch container with `archiso`, mounts the repo, and runs
`REQUIRE_REAL=1 make bake`. Needs **privileged** mode, network for pacman, and substantial
disk/time. Inspect `MANIFEST-*.txt` for `mock=no` after success.

## Environment variables

| Variable | Default | Meaning |
|----------|---------|---------|
| `EDITION` | `1` (or dialog) | `1`–`4` |
| `VERSION` | contents of `VERSION` (semver) | Version string in filenames |
| `GIT_SHA` | short git HEAD | Embedded in ISO name |
| `OUT_DIR` | `./out` | Artifact directory |
| `WORK_DIR` | `/tmp/warble-linux-work` | Scratch |
| `MOCK_ONLY` | `0` | Force mock path when `1` |
| `REQUIRE_REAL` | `0` | Fail unless a real `mkarchiso` ISO is produced |

## Semver & releases

- Source of truth: root [`VERSION`](../VERSION) file (`X.Y.Z`).
- Helpers: `./scripts/version.sh print|bump|nightly|tag` · `make version` · `make bump-patch`.
- **Nightly** (CI on `main`): GitHub prerelease tag `vX.Y.Z-nightly.N` — workflow [`.github/workflows/publish.yml`](../.github/workflows/publish.yml).
- **Stable**: push tag `vX.Y.Z` or run **Release** — workflow [`.github/workflows/release.yml`](../.github/workflows/release.yml).

## Optional GCP publish

```bash
DRY_RUN=1 ./scripts/push-to-gcp.sh   # default: print plan only
DRY_RUN=0 ./scripts/push-to-gcp.sh   # requires gcloud + docker auth
```
