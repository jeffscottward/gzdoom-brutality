#!/usr/bin/env bash
# Install Agent Doom (GZDoom + Project Brutality + Freedoom) for the current user.
#
# Needs: GZDoom already installed (see README), bsdtar or unzip, python3.
# Steps:
#   1. Extract Freedoom IWADs from releases/ and copy the Project Brutality pk3.
#   2. Build agentdoom.pk3 (score tracker) from agentdoom/.
#   3. Install the agent-doom CLI to ~/.local/bin.
#   4. Add the Omarchy menu entries under Plugins > Games (menu only).
#   5. Install the OMP extension and register it in ~/.omp/agent/config.yml.
#      The extension does nothing until the user runs `agent-doom on` or `/doom on`.
# Every edited config file is backed up first with a timestamped suffix.
set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd)
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/agent-doom"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
pb_version=0.4.1
fd_version=0.13.0

say() { printf '==> %s\n' "$*"; }

extract() { # zip member destination
	local tmp
	tmp=$(mktemp -d)
	if command -v bsdtar >/dev/null 2>&1; then
		bsdtar -xf "$1" -C "$tmp"
	else
		unzip -q "$1" -d "$tmp"
	fi
	install -m 0644 "$(find "$tmp" -type f -iname "$2" | head -n 1)" "$3"
	rm -rf "$tmp"
}

say "Game data -> $data_dir"
mkdir -p "$data_dir/iwads" "$data_dir/mods" "$data_dir/bin"
for w in freedoom1.wad freedoom2.wad; do
	[[ -f "$data_dir/iwads/$w" ]] || extract "$repo/releases/freedoom-$fd_version.zip" "$w" "$data_dir/iwads/$w"
done
[[ -f "$data_dir/iwads/freedm.wad" ]] || extract "$repo/releases/freedm-$fd_version.zip" freedm.wad "$data_dir/iwads/freedm.wad"

pb_src="$repo/releases/Project_Brutality-$pb_version.pk3"
pb_dst="$data_dir/mods/project-brutality-$pb_version.pk3"
if ! cmp -s "$pb_src" "$pb_dst" 2>/dev/null; then
	cp --reflink=auto "$pb_src" "$pb_dst"
fi

say "Build agentdoom.pk3"
python3 - "$repo/agentdoom" "$data_dir/mods/agentdoom.pk3" <<'PY'
import os, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out + ".tmp", "w", zipfile.ZIP_DEFLATED) as z:
    for name in sorted(os.listdir(src)):
        z.write(os.path.join(src, name), name)
os.replace(out + ".tmp", out)
PY

say "Install CLI -> ~/.local/bin/agent-doom"
install -m 0755 "$repo/bin/agent-doom" "$data_dir/bin/agent-doom"
mkdir -p "$HOME/.local/bin"
ln -sfn "$data_dir/bin/agent-doom" "$HOME/.local/bin/agent-doom"

say "Bot roster -> ~/.config/gzdoom/bots.cfg"
mkdir -p "$HOME/.config/gzdoom"
if [[ ! -f "$HOME/.config/gzdoom/bots.cfg" ]]; then
	install -m 0644 "$repo/agentdoom-bots.cfg" "$HOME/.config/gzdoom/bots.cfg"
elif ! grep -q 'Agent Doom bot roster' "$HOME/.config/gzdoom/bots.cfg"; then
	echo "   kept your existing bots.cfg; deathmatch bots need the names in agentdoom-bots.cfg"
fi

say "Omarchy menu: Plugins > Games > Project Brutality"
menu="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
if [[ -f "$menu" ]]; then
	python3 - "$menu" "$menu.agent-doom-new" <<'PY'
import re, sys
path, out = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
skull, play, bots, robot = "\U000f068c", "\U000f040a", "\U000f0787", "\U000f051f"
entries = {
    "plugins.games.project-brutality": f'{{"icon":"{skull}","label":"Project Brutality","description":"GZDoom + Project Brutality 0.4.1 on Freedoom"}}',
    "plugins.games.project-brutality.play": f'{{"icon":"{play}","label":"Play campaign","description":"Freedoom: Phase 2, random map","action":"\\"$HOME/.local/bin/agent-doom\\" play"}}',
    "plugins.games.project-brutality.bots": f'{{"icon":"{bots}","label":"Deathmatch vs bots","description":"FreeDM arena with 3 bots","action":"\\"$HOME/.local/bin/agent-doom\\" play --mode bots"}}',
    "plugins.games.project-brutality.agent": f'{{"icon":"{robot}","label":"Agent wait mode","description":"Open the game while the agent is busy; close it with your K/D when it replies","action":"if \\"$HOME/.local/bin/agent-doom\\" enabled >/dev/null; then \\"$HOME/.local/bin/agent-doom\\" off; else \\"$HOME/.local/bin/agent-doom\\" on; fi","checked":"\\"$HOME/.local/bin/agent-doom\\" enabled >/dev/null"}}',
}
for key, value in entries.items():
    line = f'  "{key}": {value}'
    pattern = re.compile(r'^\s*"' + re.escape(key) + r'"\s*:.*$', re.M)
    if pattern.search(text):
        text = pattern.sub(lambda _m: line, text, count=1)
    else:
        end = text.rstrip().rfind("}")
        text = text[:end].rstrip() + "\n,\n" + line + "\n}\n"
open(out, "w", encoding="utf-8").write(text)
PY
	if cmp -s "$menu" "$menu.agent-doom-new"; then
		rm -f "$menu.agent-doom-new"
	else
		cp -p "$menu" "$menu.bak.agent-doom-$stamp"
		cat "$menu.agent-doom-new" >"$menu" && rm -f "$menu.agent-doom-new"
		echo "   updated (backup: $menu.bak.agent-doom-$stamp)"
	fi
else
	echo "   skipped: $menu not found"
fi

say "OMP extension"
ext_dir="$HOME/.local/share/omp-integrations/agent-doom"
mkdir -p "$ext_dir"
install -m 0644 "$repo/omp-extension/agent-doom.mjs" "$ext_dir/extension.mjs"
omp_conf="$HOME/.omp/agent/config.yml"
if [[ -f "$omp_conf" ]] && ! grep -qF "$ext_dir/extension.mjs" "$omp_conf"; then
	cp -p "$omp_conf" "$omp_conf.bak.agent-doom-$stamp"
	python3 - "$omp_conf" "$ext_dir/extension.mjs" <<'PY'
import sys
path, ext = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().split("\n")
for i, line in enumerate(lines):
    if line.rstrip() == "extensions:":
        j = i + 1
        while j < len(lines) and lines[j].startswith("  - "):
            j += 1
        lines.insert(j, f"  - {ext}")
        break
else:
    lines += ["extensions:", f"  - {ext}"]
open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
	echo "   registered in $omp_conf (new OMP sessions load it)"
fi

say "Check"
"$HOME/.local/bin/agent-doom" doctor
