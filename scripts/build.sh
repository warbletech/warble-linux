#!/usr/bin/env bash
# Stage 1 of build -> test -> publish. CI runs exactly these commands.
#
#   scripts/build.sh deps                 install build tools (Arch, root)
#   scripts/build.sh iso    <edition>     real ISO (mkarchiso, REQUIRE_REAL=1) -> out/
#   scripts/build.sh images <edition>     WSL rootfs + Vagrant box + OVA     -> out/
#   scripts/build.sh all    <edition>     both
#
# Add --docker to run inside the pinned privileged Arch container (any Linux
# host with Docker; no Arch install needed), e.g.
#   scripts/build.sh all 1 --docker
# Env: VERSION (default: VERSION file), OUT_DIR (default out/), WORK_DIR.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCH_IMAGE="archlinux:base-20261004.0.606936"   # keep in sync with the workflows
DEPS=(archiso grub mtools dosfstools libisoburn squashfs-tools nftables mkinitcpio
      git make which tar gzip arch-install-scripts e2fsprogs syslinux qemu-img
      libarchive curl util-linux)

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
die() { printf '[build] ERROR: %s\n' "$*" >&2; exit 1; }

docker_mode=0
args=()
for a in "$@"; do
  case "$a" in
    --docker) docker_mode=1 ;;
    -h|--help) usage ;;
    *) args+=("$a") ;;
  esac
done
set -- "${args[@]}"
WHAT="${1:-}"; EDITION="${2:-${EDITION:-1}}"
[[ -n "$WHAT" ]] || usage 1

if (( docker_mode )); then
  command -v docker >/dev/null || die "docker not found"
  [[ "$WHAT" == deps ]] && exit 0
  exec docker run --rm --privileged \
    -v "$ROOT_DIR:/src" -w /src \
    -e VERSION="${VERSION:-}" -e GIT_SHA="${GIT_SHA:-}" -e MAX_ISO_BYTES="${MAX_ISO_BYTES:-}" \
    "$ARCH_IMAGE" bash -c "git config --global --add safe.directory /src && scripts/build.sh deps && scripts/build.sh '$WHAT' '$EDITION' && chown -R $(id -u):$(id -g) out"
fi

case "$WHAT" in
  deps)
    [[ $EUID -eq 0 ]] || die "deps: run as root"
    command -v pacman >/dev/null || die "deps: Arch Linux only (or use --docker)"
    pacman -Syu --noconfirm --needed "${DEPS[@]}"
    exit 0 ;;
  iso|images|all) ;;
  *) usage 1 ;;
esac
[[ "$EDITION" =~ ^[1-4]$ ]] || die "edition must be 1-4"
[[ $EUID -eq 0 ]] || die "run as root (mkarchiso/pacstrap), or add --docker"

export OUT_DIR="${OUT_DIR:-$ROOT_DIR/out}"
export VERSION="${VERSION:-$(cat "$ROOT_DIR/VERSION")}"
if [[ -z "${GIT_SHA:-}" ]]; then
  GIT_SHA="$(git -C "$ROOT_DIR" rev-parse --short=7 HEAD 2>/dev/null || echo nogit)"
fi
export GIT_SHA
mkdir -p "$OUT_DIR"

if [[ "$WHAT" == iso || "$WHAT" == all ]]; then
  REQUIRE_REAL=1 MOCK_ONLY=0 WORK_DIR="${WORK_DIR:-/tmp/warble-linux-work}" \
    make -C "$ROOT_DIR" bake EDITION="$EDITION"
fi
if [[ "$WHAT" == images || "$WHAT" == all ]]; then
  WORK_DIR=/tmp/warble-images "$ROOT_DIR/scripts/build-images.sh" "$EDITION" all "$OUT_DIR"
fi
ls -la "$OUT_DIR"
