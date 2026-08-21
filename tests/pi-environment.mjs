import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const { default: installSafety } = await import("../.pi/extensions/pi-safety.ts");

let toolCallHandler;
installSafety({
  on(event, handler) {
    if (event === "tool_call") toolCallHandler = handler;
  },
});
assert.equal(typeof toolCallHandler, "function", "safety extension registers tool_call");

const cwd = process.cwd();
const quietUi = { confirm: async () => false, notify() {} };
const approvingUi = { confirm: async () => true, notify() {} };
const call = (toolName, input, hasUI = false, ui = quietUi) =>
  toolCallHandler({ toolName, input }, { cwd, hasUI, ui });

assert.equal((await call("bash", { command: "git status --short" }))?.block, undefined);
assert.equal((await call("write", { path: ".env.local" }))?.block, true);
assert.equal((await call("write", { path: ".git/config" }))?.block, true);
assert.equal((await call("bash", { command: "rm -rf /" }))?.block, true);
assert.equal((await call("bash", { command: "echo secret > .env.local" }))?.block, true);
assert.equal((await call("bash", { command: "git push origin main --force" }))?.block, true);
assert.equal((await call("bash", { command: "git push origin HEAD" }))?.block, true);
assert.equal((await call("bash", { command: "git push origin HEAD" }, true, approvingUi))?.block, undefined);
assert.equal((await call("bash", { command: "git push origin HEAD" }, true, quietUi))?.block, true);

const settings = JSON.parse(await readFile(".pi/settings.json", "utf8"));
assert.equal(settings.compaction.enabled, true);
assert.equal(settings.defaultThinkingLevel, "high");
assert.equal(settings.enableInstallTelemetry, false);

console.log("Pi environment tests: PASS");
