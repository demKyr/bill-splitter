#!/usr/bin/env node
// Deploys the mock or your contract to the local Anvil node and tells the web app where it is.
// Local only: it refuses any chain other than Anvil (chain ID 31337). Nothing leaves your machine.
//   node scripts/deploy.mjs mock       -> MockBillSplitter (fixed data)
//   node scripts/deploy.mjs contract   -> BillSplitter (your implementation)
// It writes webapp/public/deployment.json. Reload the page to pick it up.
import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RPC_URL = "http://127.0.0.1:8545";
// Anvil's first default account. This key is public and holds no real funds.
const ANVIL_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const TARGETS = {
  mock: { contract: "MockBillSplitter", path: "src/mocks/MockBillSplitter.sol" },
  contract: { contract: "BillSplitter", path: "src/BillSplitter.sol" },
};

const target = TARGETS[process.argv[2]];
if (!target) {
  console.error("Usage: node scripts/deploy.mjs mock|contract");
  process.exit(1);
}

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const run = (cmd, args) => execFileSync(cmd, args, { cwd: join(root, "contracts"), encoding: "utf8" });

let chainId;
try {
  chainId = Number(run("cast", ["chain-id", "--rpc-url", RPC_URL]).trim());
} catch {
  console.error(`No node at ${RPC_URL}. Start one in another terminal with: anvil`);
  process.exit(1);
}
if (chainId !== 31337) {
  console.error(`Refusing to deploy: chain ${chainId} is not a local Anvil node (31337).`);
  process.exit(1);
}

const output = run("forge", [
  "create",
  `${target.path}:${target.contract}`,
  "--rpc-url",
  RPC_URL,
  "--private-key",
  ANVIL_KEY,
  "--broadcast",
  "--json",
]);
const { deployedTo } = JSON.parse(output.slice(output.indexOf("{")));

const file = join(root, "webapp/public/deployment.json");
mkdirSync(dirname(file), { recursive: true });
writeFileSync(file, JSON.stringify({ contract: target.contract, address: deployedTo, chainId }, null, 2) + "\n");
console.log(`${target.contract} deployed to ${deployedTo}`);
console.log("Written to webapp/public/deployment.json. Reload the page.");
