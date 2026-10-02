#!/usr/bin/env bash
# Record a short GIF of Project Brutality deathmatch vs bots for the README.
# Needs: wf-recorder, ffmpeg, Hyprland. Records only the left part of output DP-1
# (the game) so desktop notifications on the right are not captured.
# Usage: tests/record-demo.sh [seconds] [out.gif]
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
secs="${1:-12}"
out="${2:-$repo/evidence/demo.gif}"
tmp=$(mktemp -d)
trap 'agent-doom stop >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
log="${XDG_STATE_HOME:-$HOME/.local/state}/agent-doom/session.log"

python3 -c "import os,sys,zipfile; z=zipfile.ZipFile(sys.argv[2],'w',zipfile.ZIP_DEFLATED); [z.write(os.path.join(sys.argv[1],n),n) for n in sorted(os.listdir(sys.argv[1]))]; z.close()" "$repo/tests/demo" "$tmp/demo.pk3"

agent-doom stop >/dev/null 2>&1 || true
agent-doom start --mode bots --map MAP01 --bots 3 -- -file "$tmp/demo.pk3"
deadline=$((SECONDS + 120))
until grep -aq 'Rebase joined the game' "$log" 2>/dev/null; do
	((SECONDS > deadline)) && { echo "FAIL: bots did not join" >&2; exit 1; }
	sleep 1
done
sleep 4

# Logical coordinates (output scale 1.6667): left 1008x864 = physical 1680x1440.
timeout -s INT "$secs" wf-recorder -y -o DP-1 -g '0,0 1008x864' -f "$tmp/demo.mp4" >/dev/null 2>&1 || true
agent-doom stop >/dev/null || true

ffmpeg -y -loglevel error -i "$tmp/demo.mp4" \
	-vf "fps=10,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
	"$out"
ls -la "$out"
