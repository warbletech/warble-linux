#!/bin/bash
# Validate warble-linux out/ artifacts (mock or real).
# Exit 0 only if every check passes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT/out}"
# Editions expected after `make all-editions` (override: EDITIONS="minimal")
read -r -a EDITIONS <<<"${EDITIONS:-minimal developer cloud-native full}"
# Minimum non-empty size (GitHub Releases require >= 1 byte; we require more signal)
MIN_BYTES=32
# A real archiso ISO (kernel + initramfs + squashfs) is far larger than this.
MIN_REAL_ISO_BYTES=$((200 * 1024 * 1024))
FAIL=0

log() { printf '==> %s\n' "$*"; }
ok() { printf '  OK  %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*" >&2; FAIL=1; }

# ISO 9660 primary volume descriptor: "CD001" at byte offset 32769.
is_iso9660() {
  [[ "$(dd if="$1" bs=1 skip=32769 count=5 2>/dev/null)" == "CD001" ]]
}

[[ -d "$OUT_DIR" ]] || { echo "error: missing $OUT_DIR — run make all-editions first" >&2; exit 1; }

log "Testing artifacts in $OUT_DIR"

# ── Per-edition file presence + size ───────────────────────────────────────
for ename in "${EDITIONS[@]}"; do
  log "Edition: $ename"

  # mock=yes|no from the MANIFEST decides how strict the ISO checks are
  man=$(find "$OUT_DIR" -maxdepth 1 -type f -name "MANIFEST-${ename}-*.txt" | sort | tail -1 || true)
  mock=$(grep -m1 '^mock=' "${man:-/dev/null}" 2>/dev/null | cut -d= -f2 || true)

  # ISO: warble-linux-<edition>-<version>-<sha>.iso (glob)
  mapfile -t isos < <(find "$OUT_DIR" -maxdepth 1 -type f -name "warble-linux-${ename}-*.iso" 2>/dev/null | sort)
  if (( ${#isos[@]} == 0 )); then
    bad "no ISO for $ename"
  else
    iso="${isos[-1]}"
    sz=$(wc -c <"$iso" | tr -d ' ')
    if (( sz < MIN_BYTES )); then
      bad "ISO too small ($sz): $(basename "$iso")"
    else
      ok "ISO $(basename "$iso") ($sz bytes)"
    fi
    if is_iso9660 "$iso"; then
      ok "ISO 9660 signature present"
    elif [[ "$mock" == "yes" ]] && gzip -t "$iso" 2>/dev/null; then
      # Mock fallback on hosts without genisoimage/mkisofs/xorriso
      ok "mock ISO is a gzip tarball (no ISO tooling on build host)"
    else
      bad "not an ISO 9660 image: $(basename "$iso")"
    fi
    if [[ "$mock" == "no" ]]; then
      if (( sz < MIN_REAL_ISO_BYTES )); then
        bad "MANIFEST says mock=no but ISO is only $sz bytes"
      else
        ok "real ISO size plausible"
      fi
    fi
  fi

  wsl=$(find "$OUT_DIR" -maxdepth 1 -type f -name "warble-linux-wsl2-${ename}-*.tar.gz" | sort | tail -1 || true)
  if [[ -z "$wsl" || ! -s "$wsl" ]]; then
    bad "missing/empty WSL tarball for $ename"
  else
    ok "WSL $(basename "$wsl") ($(wc -c <"$wsl" | tr -d ' ') bytes)"
    if ! tar -tzf "$wsl" >/dev/null 2>&1; then
      bad "WSL tarball not readable: $(basename "$wsl")"
    else
      if tar -tzf "$wsl" | grep -q 'etc/os-release\|etc/warble-release'; then
        ok "WSL contains release metadata"
      else
        bad "WSL missing etc/*release entries"
      fi
    fi
  fi

  ovf=$(find "$OUT_DIR" -maxdepth 1 -type f -name "warble-linux-${ename}-*.ovf" | sort | tail -1 || true)
  if [[ -z "$ovf" || ! -s "$ovf" ]]; then
    bad "missing/empty OVF for $ename"
  else
    if grep -q 'Envelope\|VirtualSystem' "$ovf"; then
      ok "OVF $(basename "$ovf")"
    else
      bad "OVF does not look like OVF XML: $(basename "$ovf")"
    fi
  fi

  box=$(find "$OUT_DIR" -maxdepth 1 -type f -name "warble-linux-${ename}-*.box" | sort | tail -1 || true)
  if [[ -z "$box" || ! -s "$box" ]]; then
    bad "missing/empty .box for $ename"
  else
    if tar -tzf "$box" 2>/dev/null | grep -q 'metadata.json'; then
      ok "box $(basename "$box") has metadata.json"
    else
      bad "box missing metadata.json: $(basename "$box")"
    fi
  fi

  if [[ -z "$man" || ! -s "$man" ]]; then
    bad "missing MANIFEST for $ename"
  else
    if grep -q "^edition=${ename}" "$man" && grep -q '^mock=' "$man"; then
      ok "MANIFEST $(basename "$man") ($(grep '^mock=' "$man"))"
    else
      bad "MANIFEST incomplete: $(basename "$man")"
    fi
  fi

  sha=$(find "$OUT_DIR" -maxdepth 1 -type f -name "SHA256SUMS-${ename}-*.txt" | sort | tail -1 || true)
  if [[ -z "$sha" || ! -s "$sha" ]]; then
    bad "missing SHA256SUMS for $ename"
  else
    if (
      cd "$OUT_DIR"
      if command -v sha256sum >/dev/null 2>&1; then
        # Only verify lines that reference files present (ISO names may drift with git sha)
        while read -r hash name; do
          [[ -z "${name:-}" ]] && continue
          if [[ -f "$name" ]]; then
            echo "$hash  $name" | sha256sum -c - >/dev/null || exit 1
          fi
        done <"$(basename "$sha")"
      fi
    ); then
      ok "SHA256SUMS verify for existing files ($(basename "$sha"))"
    else
      bad "SHA256SUMS mismatch for $ename"
    fi
  fi
done

# ── Global guards ────────────────────────────────────────────────────────────
log "Global guards"
zeros=$(find "$OUT_DIR" -type f -size 0 2>/dev/null | wc -l | tr -d ' ')
if (( zeros > 0 )); then
  bad "found $zeros zero-byte files (GitHub Releases would reject)"
  find "$OUT_DIR" -type f -size 0 -print >&2 || true
else
  ok "no zero-byte files"
fi

count=$(find "$OUT_DIR" -type f | wc -l | tr -d ' ')
ok "$count files under out/"

if (( FAIL != 0 )); then
  echo ""
  echo "ARTIFACT TESTS FAILED" >&2
  exit 1
fi

echo ""
log "All artifact tests passed"
exit 0
