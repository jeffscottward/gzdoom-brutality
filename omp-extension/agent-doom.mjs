// Agent Doom for OMP.
//
// While the agent works on your prompt, GZDoom with Project Brutality opens.
// When the agent replies (or asks you a question), the game closes and OMP shows
// your kills, frags, deaths and K/D for that wait.
//
// The launch is opt-in: `/doom on` (or `agent-doom on`) enables it, `/doom off`
// disables it. Short replies do not open the game: it starts only when the
// agent is still busy after AGENT_DOOM_DELAY_MS (default 8000 ms).
//
// The game itself is managed by the `agent-doom` CLI (start/stop/kd), so the
// same session can run on another machine (AGENT_DOOM_TARGET in its config).
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const HOME = homedir();
const BIN = process.env.AGENT_DOOM_BIN || join(HOME, ".local/bin/agent-doom");
const CONF_DIR = join(process.env.XDG_CONFIG_HOME || join(HOME, ".config"), "agent-doom");
const DELAY_MS = Number.parseInt(process.env.AGENT_DOOM_DELAY_MS ?? "8000", 10);

function run(args, timeout = 20000) {
  return new Promise((resolve) => {
    execFile(BIN, args, { timeout, encoding: "utf8" }, (error, stdout, stderr) => {
      resolve({ ok: !error, stdout: String(stdout || "").trim(), stderr: String(stderr || "").trim() });
    });
  });
}

const isEnabled = () => existsSync(join(CONF_DIR, "enabled"));

function formatScore(json) {
  try {
    const s = JSON.parse(json);
    if (s.running === false) return undefined;
    const mins = Math.floor((s.seconds || 0) / 60);
    const secs = String((s.seconds || 0) % 60).padStart(2, "0");
    return `Agent Doom: ${s.kills} kills, ${s.frags} frags, ${s.deaths} deaths, K/D ${Number(s.kd).toFixed(2)} on ${s.map} (${mins}m${secs}s)`;
  } catch {
    return undefined;
  }
}

// Only the interactive main session controls the game. Extension factories are
// also bound to subagent sessions (task, eval agent(), /tan clones); their
// agent_start/agent_end events must not open or close the game.
const isMainUi = (ctx) => Boolean(ctx?.hasUI) && ctx?.agent?.kind !== "sub";

// Handler errors must never disturb an OMP session (for example a missing CLI).
const guard = (fn) => async (event, ctx) => {
  try {
    await fn(event, ctx);
  } catch {
    // Agent Doom is optional; ignore its failures.
  }
};

export default function agentDoom(pi) {
  let timer;
  let starting; // Promise of a running `agent-doom start`, if any.
  let launched = false;
  let busy = false;

  async function launch(ctx) {
    timer = undefined;
    if (!busy || !isEnabled()) return;
    starting = run(["start"]);
    const res = await starting;
    starting = undefined;
    if (!res.ok) {
      ctx.ui.notify(`Agent Doom did not start: ${res.stderr || res.stdout || "unknown error"}`, "warning");
      return;
    }
    launched = true;
    // The agent replied (or asked a question) while the game was starting.
    if (!busy) await close(ctx, "The agent replied.");
  }

  async function close(ctx, reason) {
    busy = false;
    clearTimeout(timer);
    timer = undefined;
    // A start that is still running must finish first; otherwise stop finds no
    // session and the game opens after the agent has replied.
    if (starting) await starting;
    if (!launched) return;
    launched = false;
    const res = await run(["stop", "--json", "--notify"]);
    const line = formatScore(res.stdout);
    if (line && ctx?.hasUI) ctx.ui.notify(`${line}. ${reason}`, "info");
  }

  pi.on("agent_start", guard((_event, ctx) => {
    // Print mode, RPC --no-ui and subagent sessions never launch the game.
    if (!isMainUi(ctx) || !isEnabled()) return;
    busy = true;
    if (!launched && !starting && !timer) timer = setTimeout(() => void launch(ctx).catch(() => {}), Math.max(0, DELAY_MS));
  }));

  pi.on("agent_end", guard(async (event, ctx) => {
    if (!isMainUi(ctx)) return;
    if (event?.willContinue === true || event?.isTerminal === false) return;
    if (ctx.hasPendingMessages?.()) return;
    await close(ctx, "The agent replied.");
  }));

  pi.on("tool_call", guard(async (event, ctx) => {
    if (isMainUi(ctx) && event?.toolName === "ask") await close(ctx, "The agent needs your input.");
  }));

  pi.on("session_shutdown", guard(async (_event, ctx) => {
    if (ctx?.agent?.kind === "sub") return;
    await close(ctx, "OMP closed.");
  }));

  pi.registerCommand("doom", {
    description: "Agent Doom: play GZDoom + Project Brutality while the agent works (`/doom on|off|status|kd|play`)",
    handler: async (args, ctx) => {
      const sub = String(args ?? "").trim() || "status";
      if (sub === "on" || sub === "off") {
        const res = await run([sub]);
        ctx.ui.notify(res.stdout || res.stderr, res.ok ? "info" : "warning");
      } else if (sub === "kd") {
        const res = await run(["kd", "--json"]);
        ctx.ui.notify(formatScore(res.stdout) || "No finished Agent Doom session yet.", "info");
      } else if (sub === "play") {
        const res = await run(["start"]);
        launched = res.ok;
        ctx.ui.notify(res.ok ? "Agent Doom started. It closes when the agent replies." : res.stderr, res.ok ? "info" : "warning");
      } else if (sub === "status") {
        const res = await run(["status"]);
        ctx.ui.notify(`Agent Doom auto-launch: ${isEnabled() ? "on" : "off"}; session: ${res.stdout || "unknown"}`, "info");
      } else {
        ctx.ui.notify("Usage: /doom on | off | status | kd | play", "warning");
      }
    },
  });
}
