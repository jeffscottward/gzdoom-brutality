// Lifecycle test for omp-extension/agent-doom.mjs with a stub agent-doom CLI.
// Run: node tests/extension.test.mjs   (or bun)
import assert from "node:assert/strict";
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const dir = mkdtempSync(join(tmpdir(), "agent-doom-ext-"));
const calls = join(dir, "calls.log");
const stub = join(dir, "agent-doom");
writeFileSync(
  stub,
  `#!/usr/bin/env bash
echo "$*" >>"${calls}"
if [ "$1" = start ] && [ -f "${dir}/slow" ]; then sleep 0.5; echo start-finished >>"${calls}"; fi
case "$1" in
on) mkdir -p "${dir}/conf/agent-doom" && : >"${dir}/conf/agent-doom/enabled"; echo on ;;
stop) echo '{"kills":7,"frags":2,"deaths":3,"kd":3.00,"map":"MAP05","seconds":95,"ended":1}' ;;
status) echo running ;;
esac
`,
);
chmodSync(stub, 0o755);
process.env.AGENT_DOOM_BIN = stub;
process.env.AGENT_DOOM_DELAY_MS = "150";
process.env.XDG_CONFIG_HOME = join(dir, "conf");

const { default: agentDoom } = await import("../omp-extension/agent-doom.mjs");

const handlers = {};
const commands = {};
const notes = [];
const pi = {
  on: (name, fn) => ((handlers[name] ??= []).push(fn)),
  registerCommand: (name, spec) => (commands[name] = spec),
};
const ctx = { hasUI: true, hasPendingMessages: () => false, ui: { notify: (msg, level) => notes.push([level, msg]) } };
const emit = async (name, event = {}, c = ctx) => {
  for (const fn of handlers[name] ?? []) await fn(event, c);
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const callLog = () => {
  try {
    return readFileSync(calls, "utf8").trim().split("\n").filter(Boolean);
  } catch {
    return [];
  }
};

agentDoom(pi);
assert.ok(commands.doom, "registers /doom");

// 1. Disabled: nothing happens.
await emit("agent_start");
await sleep(250);
await emit("agent_end", {});
assert.deepEqual(callLog(), [], "disabled: no CLI calls");

// 2. Enable through /doom on.
await commands.doom.handler("on", ctx);
assert.deepEqual(callLog(), ["on"]);

// 3. Short reply (before the delay): game never starts.
await emit("agent_start");
await sleep(50);
await emit("agent_end", {});
await sleep(200);
assert.deepEqual(callLog(), ["on"], "short reply: no start");

// 4. Headless session: never starts.
await emit("agent_start", {}, { ...ctx, hasUI: false });
await sleep(250);
assert.deepEqual(callLog(), ["on"], "headless: no start");

// 5. Long run: starts after the delay, survives a continuing agent_end, stops on the final one.
await emit("agent_start");
await sleep(250);
assert.deepEqual(callLog(), ["on", "start"], "long run: start");
await emit("agent_end", { willContinue: true });
assert.deepEqual(callLog(), ["on", "start"], "willContinue: still playing");
await emit("agent_end", {});
assert.deepEqual(callLog(), ["on", "start", "stop --json --notify"], "final end: stop");
const last = notes.at(-1);
assert.equal(last[0], "info");
assert.match(last[1], /7 kills, 2 frags, 3 deaths, K\/D 3\.00 on MAP05 \(1m35s\)\. The agent replied\./);

// 6. The ask tool closes the game.
await emit("agent_start");
await sleep(250);
await emit("tool_call", { toolName: "ask" });
assert.deepEqual(callLog().slice(-2), ["start", "stop --json --notify"], "ask: stop");
assert.match(notes.at(-1)[1], /needs your input/);
await emit("agent_end", {});
assert.equal(callLog().filter((l) => l.startsWith("stop")).length, 2, "no second stop after ask");

// 7. Subagent sessions neither start nor stop the game.
const sub = { ...ctx, agent: { kind: "sub", id: "x", name: "task", depth: 1 } };
const main = { ...ctx, agent: { kind: "main", id: "m", name: "main", depth: 0 } };
let before = callLog().length;
await emit("agent_start", {}, sub);
await sleep(250);
assert.equal(callLog().length, before, "subagent start: no CLI calls");
await emit("agent_start", {}, main);
await sleep(250);
assert.equal(callLog().at(-1), "start", "main start");
await emit("agent_end", {}, sub);
assert.equal(callLog().at(-1), "start", "subagent end: game keeps running");
await emit("agent_end", {}, main);
assert.equal(callLog().at(-1), "stop --json --notify", "main end: stop");

// 8. The agent replies while `start` is still running: stop runs after start, exactly once.
writeFileSync(join(dir, "slow"), "");
before = callLog().length;
await emit("agent_start");
await sleep(250); // timer fired; start sleeps 0.5 s
await emit("agent_end", {});
await sleep(100);
assert.deepEqual(callLog().slice(before), ["start", "start-finished", "stop --json --notify"], "reply during start: stop after start");

// 9. Same race with the ask tool.
before = callLog().length;
await emit("agent_start");
await sleep(250);
await emit("tool_call", { toolName: "ask" });
await sleep(100);
assert.deepEqual(callLog().slice(before), ["start", "start-finished", "stop --json --notify"], "ask during start: stop after start");

rmSync(dir, { recursive: true, force: true });
console.log("PASS extension lifecycle (9 scenarios)");
