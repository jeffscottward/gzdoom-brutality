# Agent Doom: GZDoom + Project Brutality while OMP works

This project is an OMP version of an idea from [Jarrod Watts' post](https://x.com/jarrodwatts/status/2105858869482471602). In his Claude Code mod, Doom opens while the agent works. The game closes when the agent replies and shows your K/D. The code here is original. It uses GZDoom, [Project Brutality](https://github.com/pa1nki113r/Project_Brutality) 0.4.1 and the free [Freedoom](https://freedoom.github.io/) IWADs.

## What it does

1. You send a prompt to OMP. If the agent is still busy after 8 seconds, GZDoom with Project Brutality opens.
2. The agent replies, or it asks you a question. The game then closes.
3. OMP shows the score for that wait, for example: `Agent Doom: 12 kills, 0 frags, 2 deaths, K/D 6.00 on MAP07 (3m10s)`. A desktop notification shows the same line.

Automatic launch is off by default. Turn it on with `/doom on` in OMP, `agent-doom on` in a shell, or **Omarchy → Plugins → Games → Project Brutality → Agent wait mode**.

## Parts

| Path | Purpose |
|---|---|
| `bin/agent-doom` | CLI: `play`, `start`, `stop`, `status`, `kd`, `on`, `off`, `doctor`. |
| `agentdoom/` | Source of `agentdoom.pk3`. A ZScript event handler counts kills, frags and deaths and writes `AGENTDOOM ...` lines to the GZDoom log. It only reads game state. |
| `omp-extension/agent-doom.mjs` | OMP extension: starts the game on `agent_start` (after the delay) and stops it on the final `agent_end` or the `ask` tool. Registers `/doom`. |
| `agentdoom-bots.cfg` | Bot roster for deathmatch mode (installed as `~/.config/gzdoom/bots.cfg` if that file does not exist). |
| `install.sh` | Per-machine install (game data, CLI, Omarchy menu entries, OMP extension). |
| `deploy-remote.sh` | Copies the repo to another machine over SSH and runs `install.sh` there. |
| `tests/` | `smoke.sh` (real GZDoom run, scripted score 3 kills / 1 death) and `extension.test.mjs` (extension lifecycle with a stub CLI). |
| `releases/` | Local copies of Project Brutality and Freedoom. See `releases/SOURCES.md`. Git does not track the large files. |

## Game modes

| Mode | Command | IWAD |
|---|---|---|
| Campaign (default) | `agent-doom play` | Freedoom: Phase 2, random map, or `AGENT_DOOM_IWAD` |
| Deathmatch vs bots | `agent-doom play --mode bots` | FreeDM, 3 bots |
| Netgame host | `agent-doom start --mode host --players 2` | FreeDM |
| Netgame join | `agent-doom start --join HOST[:PORT]` | FreeDM |

The agent-wait session uses the mode from the config file.

### Multiplayer limit

In the original post, every other player in the match is a person who waits for their agent. GZDoom cannot join a match that is already running. Its netcode is peer-to-peer lockstep: the host waits until all players connect, and then the game starts. Zandronum supports drop-in play, but Project Brutality needs GZDoom. Because of this, the default agent-wait mode is the campaign (or bots). Host and join modes work for a planned match between machines. The host must allow UDP port 5029 (for example on the Tailscale interface).

## Install

1. Install GZDoom natively:
   - x86_64 Arch/Omarchy: `yay -S gzdoom` (AUR, also builds `zmusic`).
   - aarch64 Arch Linux ARM: `yay -S gzdoom` (the AUR package lists `aarch64` and builds from source).
2. Put the release files in `releases/` (see `releases/SOURCES.md`).
3. Run `./install.sh`. It backs up every config file that it changes.
4. Start a new OMP session to load the extension.

To install on another machine: `./deploy-remote.sh omarchy-mac omarchy-mac` (GZDoom must be installed there first).

## Settings

`~/.config/agent-doom/config` uses `KEY=value` lines:

```sh
AGENT_DOOM_MODE=solo          # solo | bots | host | join
AGENT_DOOM_SKILL=3            # 1-5
AGENT_DOOM_BOTS=3             # bots mode, 0-5
AGENT_DOOM_JOIN=              # join mode: host address
AGENT_DOOM_PLAYERS=2          # host mode: number of players
AGENT_DOOM_PORT=5029
AGENT_DOOM_IWAD=              # your own Doom II IWAD (used in place); empty = Freedoom
AGENT_DOOM_TARGET=local       # SSH alias: run the game on that machine instead
AGENT_DOOM_GZDOOM=            # path to gzdoom when it is not on PATH
```

The extension also reads `AGENT_DOOM_DELAY_MS` (default `8000`) from the OMP environment.

Use `AGENT_DOOM_TARGET` when OMP runs on one machine (for example `omarchy-rig` over SSH) and you sit at another (for example `omarchy-mac`). The CLI then runs `start`, `stop`, `status` and `kd` on that machine through SSH.

## Tests

```sh
node tests/extension.test.mjs   # no game window
tests/smoke.sh                  # opens and closes a real game window
```

## GZDoom lessons (confirmed on omarchy-rig, 2026-10-02, GZDoom 4.14.2)

- Console commands on the command line (`+wait`, `+addbot`, `+netevent`) can run before the map loads. Use `-bots NAME...` with `~/.config/gzdoom/bots.cfg`, or an in-game ZScript handler.
- GZDoom ignores SIGTERM while a netgame waits for players. `agent-doom stop` relies on systemd's SIGKILL after 6 s in that case.
- In join mode, `-port` sets the joiner's own local port. Two copies on one host need different ports.
- `gzdoom -norun` without an IWAD opens a "Fatal error" window. Do not use it to check the version.
