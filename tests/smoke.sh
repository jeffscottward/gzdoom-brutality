#!/usr/bin/env bash
# End-to-end smoke test for the installed agent-doom (run install.sh first).
#
# It opens a real GZDoom + Project Brutality window. A test-only helper
# (tests/kdtest) kills 3 monsters for the player and then kills the player once.
# The test then takes a screenshot (grim, when available), closes the game
# through `agent-doom stop` and checks the reported score: 3 kills, 1 death,
# K/D 3.00.
#
# Usage: tests/smoke.sh [screenshot.png]
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
shot="${1:-/tmp/agent-doom-smoke-$(hostname).png}"
log="${XDG_STATE_HOME:-$HOME/.local/state}/agent-doom/session.log"
tmp=$(mktemp -d)
trap 'agent-doom stop >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT

python3 -c "import os,sys,zipfile; z=zipfile.ZipFile(sys.argv[2],'w',zipfile.ZIP_DEFLATED); [z.write(os.path.join(sys.argv[1],n),n) for n in sorted(os.listdir(sys.argv[1]))]; z.close()" "$repo/tests/kdtest" "$tmp/kdtest.pk3"

agent-doom stop >/dev/null 2>&1 || true
agent-doom start --mode solo --map MAP01 --skill 3 -- -file "$tmp/kdtest.pk3"

deadline=$((SECONDS + 120))
until grep -aq '^AGENTDOOM kills=3 frags=0 deaths=1 ' "$log" 2>/dev/null; do
	if ((SECONDS > deadline)); then
		echo "FAIL: score lines did not reach kills=3 deaths=1 in 120 s" >&2
		grep -a '^AGENTDOOM' "$log" >&2 || true
		exit 1
	fi
	if [[ "$(agent-doom status)" != running ]]; then
		echo "FAIL: GZDoom exited early" >&2
		tail -n 30 "$log" >&2 || true
		exit 1
	fi
	sleep 2
done

if command -v grim >/dev/null 2>&1; then
	sleep 1
	grim "$shot" && echo "screenshot: $shot"
fi

json=$(agent-doom stop --json)
echo "score: $json"
[[ "$(agent-doom status)" == stopped ]] || { echo "FAIL: session still running" >&2; exit 1; }
grep -q '"kills":3,"frags":0,"deaths":1,"kd":3.00' <<<"$json" || { echo "FAIL: unexpected score" >&2; exit 1; }
echo "PASS"
