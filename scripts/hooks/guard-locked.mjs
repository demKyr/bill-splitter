#!/usr/bin/env node
// Agent hook: before the agent edits a file, refuse the edit if the file is locked.
// Exit code 2 blocks the edit and sends the message to the agent.
// With --after, it runs after each edit and shell command instead. It asks git whether a locked
// file was changed, removed or moved by any means, for example by `rm` or `sed -i`, and sends the
// list to the agent.
// docs/AGENT_SETUP.md says how to register it with your agent, and how to add files to LOCKED.
//
// Each run adds a line to .hooks.log in the repository root. That line is the evidence that the
// agent's program ran the hook: an agent can also refuse an edit only because AGENTS.md says so.
//
// The agent passes a JSON description of the edit on standard input.
// Claude Code sends the file path. Codex sends a patch: its "*** Update File:" lines name the files.
import { execFileSync } from "node:child_process";
import { appendFileSync, readFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const LOCKED = [
  "contracts/src/interfaces/", // the agreed boundary between contract and web app
  "contracts/src/mocks/",
  "contracts/src/BillSplitter.sol", // only joins the parts
  "contracts/src/BillSplitterBase.sol", // the shared state
  "contracts/test/core/", // the ready-made tests
  "contracts/test/payment/",
  "webapp/src/chain.ts",
  "webapp/src/abi.ts",
  "scripts/hooks/", // the checks themselves
  // Once you agree a specification, commit it, then remove the "//" in front of its line.
  "docs/SPEC_CONTRACTS.md",
  "docs/SPEC_FRONTEND.md",
];

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const log = (line) => {
  try {
    appendFileSync(resolve(root, ".hooks.log"), `${new Date().toISOString()} guard-locked ${line}\n`);
  } catch {
    // The log is evidence only. A failure to write it must not change the result.
  }
};
if (process.argv[2] === "--after") checkLockedUnchanged();

let input;
try {
  input = JSON.parse(readFileSync(0, "utf8"));
} catch {
  log("BLOCKED unreadable hook input");
  console.error("guard-locked hook: the hook input is not readable, so the edit is refused.");
  process.exit(2);
}

const toolInput = input.tool_input ?? input.toolInput ?? {};
const paths = [toolInput.file_path, toolInput.path].filter(Boolean);
for (const line of String(toolInput.command ?? "").split("\n")) {
  const match = line.match(/^\*\*\* (?:Add|Update|Delete) File: (.+)$/) ?? line.match(/^\*\*\* Move to: (.+)$/);
  if (match) paths.push(match[1].trim());
}

const blocked = paths
  .map((path) => relative(root, resolve(input.cwd ?? root, path)).replaceAll("\\", "/"))
  .filter((path) => LOCKED.some((locked) => path.toLowerCase().startsWith(locked.toLowerCase())));

const seen = paths.map((path) => relative(root, resolve(input.cwd ?? root, path)).replaceAll("\\", "/"));
if (blocked.length > 0) {
  log(`BLOCKED ${blocked.join(", ")}`);
  console.error(`Locked: ${blocked.join(", ")}. Do not edit it another way. Stop and ask the human.`);
  process.exit(2);
}
log(`allowed ${seen.join(", ") || "(no file path in the hook input)"}`);

// The locked files are committed, so git status lists every change to them, however it was made.
function checkLockedUnchanged() {
  try {
    readFileSync(0);
  } catch {
    // The hook input is not needed here.
  }
  let status;
  try {
    status = execFileSync("git", ["status", "--porcelain", "--", ...LOCKED], { cwd: root, encoding: "utf8" });
  } catch {
    process.exit(0); // Without git, the guard before each edit still applies.
  }
  const lines = status.split("\n").filter(Boolean);
  if (lines.length === 0) process.exit(0);
  const tracked = lines.filter((line) => !line.startsWith("??")).map((line) => line.slice(3).split(" -> ")[0]);
  const added = lines.filter((line) => line.startsWith("??")).map((line) => line.slice(3));
  log(`CHANGED ${lines.map((line) => line.slice(3)).join(", ")}`);
  console.error(`Locked files were changed, removed or moved:\n${lines.join("\n")}`);
  if (tracked.length > 0) console.error(`Restore them: git checkout HEAD -- ${tracked.join(" ")}`);
  if (added.length > 0) console.error(`Delete the new files: ${added.join(" ")}`);
  console.error("Then stop and ask the human.");
  process.exit(2);
}
