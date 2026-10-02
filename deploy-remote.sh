#!/usr/bin/env bash
# Copy this repo (with releases/) to another machine over SSH and run install.sh there.
#
# Usage: ./deploy-remote.sh <ssh-alias> [expected-hostname]
#   ./deploy-remote.sh omarchy-mac omarchy-mac
#
# GZDoom itself must already be installed on the target, natively for its
# architecture (for example `yay -S gzdoom` on Arch Linux ARM, which builds the
# AUR package from source on aarch64). This script never installs packages and
# never copies binaries between machines.
set -euo pipefail

target="${1:?usage: $0 <ssh-alias> [expected-hostname]}"
expect="${2:-$target}"
repo=$(cd "$(dirname "$0")" && pwd)
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=8)

info=$(ssh "${ssh_opts[@]}" "$target" 'printf "%s %s %s\n" "$(hostname)" "$(uname -m)" "$(id -un)"')
read -r host arch user <<<"$info"
echo "target: $host ($arch) as $user"
[[ "$host" == "$expect" ]] || { echo "refusing: hostname is $host, expected $expect" >&2; exit 1; }

if ! ssh "${ssh_opts[@]}" "$target" 'command -v gzdoom >/dev/null || [ -x "$HOME/.local/bin/gzdoom" ]'; then
	echo "GZDoom is not installed on $host. Install it natively first (yay -S gzdoom)." >&2
	exit 2
fi

ssh "${ssh_opts[@]}" "$target" 'mkdir -p "$HOME/Github/fun/gzdoom-brutality"'
rsync -a --info=stats1 --exclude .work/ --exclude .git/ \
	"$repo/" "$target:Github/fun/gzdoom-brutality/"
ssh "${ssh_opts[@]}" "$target" 'cd "$HOME/Github/fun/gzdoom-brutality" && ./install.sh'
