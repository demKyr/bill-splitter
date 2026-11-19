/**
 * The chain connection. It is already set up: build the page on top of it.
 *
 * How the web app reaches the contract (slide 16):
 *   read  -> publicClient.readContract(...)   an eth_call to the node: no signature, no gas
 *   write -> walletClientFor(account).writeContract(...)   a signed transaction that costs gas
 *
 * There is no browser wallet in this practical. The app signs with Anvil's well-known test keys,
 * which are public and hold no real funds. Never put any other private key in a web app.
 */
import { createPublicClient, createWalletClient, http, type Address, type Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { foundry } from "viem/chains";

export { billSplitterAbi } from "./abi";

/** The local Anvil node. */
export const RPC_URL = "http://127.0.0.1:8545";

/** Anvil's first four default accounts. Each starts with 10,000 test ETH. */
export const ACCOUNTS: { label: string; address: Address; privateKey: Hex }[] = [
  {
    label: "Alice",
    address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    privateKey: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  },
  {
    label: "Bob",
    address: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    privateKey: "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
  },
  {
    label: "Carol",
    address: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
    privateKey: "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",
  },
  {
    label: "Dave",
    address: "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
    privateKey: "0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6",
  },
];

/** Reads from the chain. */
export const publicClient = createPublicClient({ chain: foundry, transport: http(RPC_URL) });

/** Signs and sends transactions as one of ACCOUNTS. */
// Typical use: simulate first so that a revert gives its error, then send and wait.
//   const { request } = await publicClient.simulateContract({ address, abi, functionName, args, account });
//   const hash = await walletClientFor(account).writeContract(request);
//   await publicClient.waitForTransactionReceipt({ hash });
export function walletClientFor(address: Address) {
  const entry = ACCOUNTS.find((a) => a.address.toLowerCase() === address.toLowerCase());
  if (!entry) throw new Error(`Not a test account: ${address}`);
  return createWalletClient({
    account: privateKeyToAccount(entry.privateKey),
    chain: foundry,
    transport: http(RPC_URL),
  });
}

/** What `node scripts/deploy.mjs` wrote: which contract the app talks to. */
export type Deployment = { contract: "MockBillSplitter" | "BillSplitter"; address: Address; chainId: number };

/** Returns null until a contract is deployed. Read at run time, so a new deployment needs only a page reload. */
export async function loadDeployment(): Promise<Deployment | null> {
  const response = await fetch("/deployment.json", { cache: "no-store" });
  if (!response.ok || !response.headers.get("content-type")?.includes("json")) return null;
  return (await response.json()) as Deployment;
}
