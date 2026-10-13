#!/usr/bin/env bash
# Record a scripted demo of a real Warble Linux ISO (serial console) and render it.
#
#   scripts/demo/record.sh <warble-linux-EDITION-*.iso> [out-dir]
#
# Produces in out-dir (default: demo-out):
#   warble-linux-<edition>-demo.cast   asciicast v2 (boot squeezed, idle capped)
#   warble-linux-<edition>-demo.gif    agg render (README)
#   warble-linux-<edition>-demo.mp4    H.264 / yuv420p (LinkedIn, X)
#
# Needs: qemu-system-x86_64 (KVM recommended), expect, python3, ffmpeg,
#        asciinema >= 3 (headless mode) and agg. CI pins both by sha256
#        (.github/workflows/demo.yml); override paths with ASCIINEMA= / AGG=.
set -euo pipefail

[[ $# -ge 1 ]] || { sed -n '2,13p' "$0"; exit 2; }
iso=$(realpath "$1"); out=${2:-demo-out}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ASCIINEMA=${ASCIINEMA:-asciinema}; AGG=${AGG:-agg}
COLS=${DEMO_COLS:-100}; ROWS=${DEMO_ROWS:-30}

case "$(basename "$iso")" in
  warble-linux-minimal-*) ed=minimal ;;
  warble-linux-developer-*) ed=developer ;;
  warble-linux-cloud-native-*) ed=cloud-native ;;
  warble-linux-full-*) ed=full ;;
  *) [[ -n ${WARBLE_DEMO_FAKE:-} ]] && ed=${WARBLE_DEMO_EDITION:-minimal} || { echo "record.sh: cannot tell edition from $iso" >&2; exit 2; } ;;
esac
for c in expect python3 ffmpeg "$ASCIINEMA" "$AGG"; do
  command -v "$c" >/dev/null || { echo "record.sh: missing $c" >&2; exit 2; }
done

mkdir -p "$out"; out=$(realpath "$out")
name="warble-linux-$ed-demo"
raw="$out/$name.raw.cast"

echo "record.sh: recording $ed edition from $(basename "$iso") (${COLS}x${ROWS})"
WARBLE_DEMO_ISO="$iso" WARBLE_DEMO_EDITION="$ed" \
  "$ASCIINEMA" rec --headless --quiet --return --overwrite \
    --window-size "${COLS}x${ROWS}" --output-format asciicast-v2 --idle-time-limit 2 \
    --title "Warble Linux $ed edition: live ISO serial console" \
    --command "expect -f '$here/demo.exp'" "$raw"

python3 "$here/cast-trim.py" "$raw" "$out/$name.cast" --boot-secs "${DEMO_BOOT_SECS:-7}"
rm -f "$raw"

# Warble palette (assets/brand/README.md): bg #0a0a0f, fg #e8e8f0, accents
# teal #10a6b4, violet #6c63ff, cyan #4fc3f7, success #34d399, warning #fbbf24.
theme="0a0a0f,e8e8f0,1a1a2e,f472b6,34d399,fbbf24,6c63ff,a78bfa,10a6b4,c8c8d8,8888a0,f472b6,34d399,fbbf24,8b84ff,c4b5fd,4fc3f7,ffffff"
"$AGG" --quiet --theme "$theme" --font-size "${DEMO_FONT_SIZE:-20}" --fps-cap 20 \
  --idle-time-limit 2 --last-frame-duration 5 "$out/$name.cast" "$out/$name.gif"

# MP4 for social: H.264 + yuv420p + even dimensions + faststart.
ffmpeg -y -loglevel error -i "$out/$name.gif" \
  -vf "fps=30,scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=neighbor" \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart "$out/$name.mp4"

dur=$(python3 -c 'import json,sys; l=open(sys.argv[1]).read().splitlines(); print(round(json.loads(l[-1])[0],1))' "$out/$name.cast")
echo "record.sh: done: ${dur}s"
ls -l "$out/$name".{cast,gif,mp4}
