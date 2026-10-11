#!/usr/bin/env bash
# Stage 3 of build -> test -> publish. CI runs the same assembly.
#
#   scripts/publish.sh [--dist DIR] [--ok DIR] [--version V] [--tag T] [--assets DIR]
#                      [--draft-release]
#
# Collects artifacts from --dist (searched recursively; default out/) and
# includes ONLY the ones whose tests passed (markers in --ok, default out/ok,
# written by scripts/test.sh):
#   ISO          : MANIFEST mock=no + boot-ok-<ed>-bios + boot-ok-<ed>-uefi
#   WSL tarball  : img-ok-<ed>-wsl
#   box + OVA    : img-ok-<ed>-vm-bios + img-ok-<ed>-vm-uefi
# Everything must be < 2 GiB. Writes <assets>/ (default out/release-assets) with
# SHA256SUMS.txt, plus release-body.md next to it. Fails if no ISO qualifies.
#
# DEFAULT IS A DRY RUN: nothing leaves your machine. --draft-release uploads to
# a DRAFT prerelease (tag dryrun-local-<timestamp> unless --tag) with the gh CLI;
# delete it afterwards: gh release delete <tag> --yes --cleanup-tag
# Real releases are created only by pushing a vX.Y.Z tag (release.yml).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT_DIR/out"; OK="$ROOT_DIR/out/ok"; ASSETS="$ROOT_DIR/out/release-assets"
VERSION="${VERSION:-$(cat "$ROOT_DIR/VERSION")}"; TAG=""; DRAFT=0
NAMES=([1]=minimal [2]=developer [3]=cloud-native [4]=full)
LIMIT=$((2 * 1024 * 1024 * 1024))

while (( $# )); do
  case "$1" in
    --dist) DIST="$2"; shift 2 ;;
    --ok) OK="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --assets) ASSETS="$2"; shift 2 ;;
    --draft-release) DRAFT=1; shift ;;
    -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
log() { printf '[publish] %s\n' "$*"; }
die() { printf '[publish] ERROR: %s\n' "$*" >&2; exit 1; }
has() { [[ -f "$OK/$1" ]]; }

rm -rf "$ASSETS"; mkdir -p "$ASSETS"
META="$(dirname "$ASSETS")"
: > "$META/published.txt"; : > "$META/skipped.txt"

# ── ISOs ───────────────────────────────────────────────────────────────────
mapfile -t mans < <(find "$DIST" -name 'MANIFEST-*.txt' -not -path "$ASSETS/*" | sort)
declare -A iso_done=()
for m in "${mans[@]}"; do
  d=$(dirname "$m")
  ed=$(sed -n 's/^edition=.*(\([0-9]\)).*/\1/p' "$m")
  [[ -n "$ed" && -z "${iso_done[$ed]:-}" ]] || continue
  grep -qx 'mock=no' "$m" || { log "edition $ed: MANIFEST is not mock=no, skipping"; continue; }
  iso=$(find "$d" -maxdepth 1 -name "warble-linux-${NAMES[$ed]}-*.iso" | head -1)
  [[ -n "$iso" ]] || continue
  if ! has "boot-ok-${ed}-bios.txt" || ! has "boot-ok-${ed}-uefi.txt"; then
    log "edition $ed: ISO did not pass BIOS and UEFI boot tests, skipping"; continue
  fi
  if [[ -f "$d/SHA256SUMS-real-iso.txt" ]]; then (cd "$d" && sha256sum -c --quiet SHA256SUMS-real-iso.txt) || die "checksum mismatch in $d"; fi
  cp "$iso" "$m" "$ASSETS/"; iso_done[$ed]=1
  echo "ISO ${NAMES[$ed]}: $(basename "$iso")" >> "$META/published.txt"
done
for e in 1 2 3 4; do [[ -n "${iso_done[$e]:-}" ]] || echo "${NAMES[$e]}: ISO" >> "$META/skipped.txt"; done
compgen -G "$ASSETS/*.iso" >/dev/null || die "no ISO passed build + boot tests — nothing to publish"

# ── WSL / Vagrant / OVA ────────────────────────────────────────────────────
pick() { find "$DIST" -name "$1" -not -path "$ASSETS/*" | sort | tail -1; }
for e in 1 2 3 4; do
  n=${NAMES[$e]}
  wsl=$(pick "warble-linux-wsl2-${n}-${VERSION}.tar.gz")
  if [[ -n "$wsl" ]] && has "img-ok-${e}-wsl.txt"; then
    cp "$wsl" "$ASSETS/"; echo "WSL $n: $(basename "$wsl")" >> "$META/published.txt"
  else
    echo "${n}: WSL" >> "$META/skipped.txt"
  fi
  box=$(pick "warble-linux-${n}-${VERSION}-libvirt.box"); ova=$(pick "warble-linux-${n}-${VERSION}.ova")
  if [[ -n "$box" && -n "$ova" ]] && has "img-ok-${e}-vm-bios.txt" && has "img-ok-${e}-vm-uefi.txt"; then
    cp "$box" "$ova" "$ASSETS/"
    echo "Vagrant $n: $(basename "$box")" >> "$META/published.txt"
    echo "OVA $n: $(basename "$ova")" >> "$META/published.txt"
  else
    echo "${n}: Vagrant/OVA" >> "$META/skipped.txt"
  fi
done
# image checksums from the build stage, if present
while IFS= read -r s; do
  (cd "$(dirname "$s")" && sha256sum -c --quiet --ignore-missing "$(basename "$s")") || die "image checksum mismatch: $s"
done < <(find "$DIST" -name 'SHA256SUMS-images-*.txt' -not -path "$ASSETS/*")

for f in "$ASSETS"/*; do
  (( $(stat -c%s "$f") < LIMIT )) || die "$(basename "$f") exceeds 2 GiB"
done
(cd "$ASSETS" && sha256sum -- * > SHA256SUMS.txt)

# ── Release notes ──────────────────────────────────────────────────────────
{
  echo "## Warble Linux ${TAG:-$VERSION}"
  echo ""
  echo "Every asset below passed its CI test before upload:"
  echo "- **ISO:** real \`mkarchiso\` build, booted in QEMU on BIOS and UEFI to a serial login prompt."
  echo "- **WSL2 rootfs:** tar checks plus a \`docker import\` smoke test."
  echo "- **Vagrant libvirt box:** booted in QEMU on BIOS and UEFI and reached over SSH as \`vagrant\`."
  echo "- **OVA:** the same disk as the box. Its structure and checksums are verified, but it is **not** boot-tested in VirtualBox."
  echo ""
  echo "| Asset | Size |"
  echo "|-------|------|"
  for f in "$ASSETS"/*.iso "$ASSETS"/*.tar.gz "$ASSETS"/*.box "$ASSETS"/*.ova; do
    [[ -f "$f" ]] && echo "| \`$(basename "$f")\` | $(( $(stat -c%s "$f") / 1024 / 1024 )) MiB |"
  done
  if [[ -s "$META/skipped.txt" ]]; then
    echo ""
    echo "Not published this time (build or test failed): $(paste -sd, "$META/skipped.txt" | sed 's/,/, /g')"
  fi
  echo ""
  echo "### Verify"
  echo '```bash'
  echo "sha256sum -c SHA256SUMS.txt --ignore-missing"
  echo "gh attestation verify <file> -R warbletech/warble-linux"
  echo '```'
  echo ""
  echo "### Disposable sandboxes (create, use, destroy)"
  echo "See [docs/local-testing.md](https://github.com/warbletech/warble-linux/blob/main/docs/local-testing.md)."
  echo '```bash'
  echo "qemu-system-x86_64 -enable-kvm -m 2048 -snapshot -nic user -cdrom warble-linux-minimal-${VERSION}-*.iso -boot d   # quit to destroy"
  echo "wsl --import warble-sbx \$env:LOCALAPPDATA\\warble-sbx .\\warble-linux-wsl2-minimal-${VERSION}.tar.gz --version 2; wsl -d warble-sbx; wsl --unregister warble-sbx"
  echo "vagrant box add --name warble/minimal warble-linux-minimal-${VERSION}-libvirt.box && vagrant init warble/minimal && vagrant up --provider=libvirt && vagrant ssh"
  echo "vagrant destroy -f && vagrant box remove warble/minimal"
  echo '```'
  semver="${VERSION%%-*}"
  if [[ -f "$ROOT_DIR/CHANGELOG.md" ]]; then
    echo ""; echo "### Changelog"; echo ""
    awk -v ver="$semver" '$0 ~ "^## \\[" ver "\\]" {p=1; next} p && $0 ~ /^## \[/ {exit} p {print}' "$ROOT_DIR/CHANGELOG.md" || true
  fi
} > "$META/release-body.md"

log "published:"; sed 's/^/  /' "$META/published.txt"
log "skipped:";   sed 's/^/  /' "$META/skipped.txt"
log "assets in $ASSETS:"; ls -la "$ASSETS"

if (( DRAFT )); then
  command -v gh >/dev/null || die "gh CLI needed for --draft-release"
  TAG="${TAG:-dryrun-local-$(date -u +%Y%m%d%H%M%S)}"
  log "uploading to DRAFT prerelease $TAG"
  gh release create "$TAG" --draft --prerelease --target "$(git -C "$ROOT_DIR" rev-parse HEAD)" \
    --title "Warble Linux $TAG (draft dry run)" --notes-file "$META/release-body.md" "$ASSETS"/*
  log "done. Delete it with: gh release delete $TAG --yes --cleanup-tag"
else
  log "DRY RUN: nothing uploaded. Use --draft-release to upload to a draft release."
fi
