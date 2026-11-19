/**
 * The page. Only plumbing: it checks that the local chain answers, makes one sample read, and
 * shows which contract is deployed. docs/SPEC_FRONTEND.md describes what the page must do.
 */
import { formatEther } from "viem";
import { ACCOUNTS, billSplitterAbi, loadDeployment, publicClient, RPC_URL } from "./chain";

const app = document.querySelector<HTMLElement>("#app")!;

/** Runs one check, and returns its result or the reason that it failed. */
async function check(run: () => Promise<string>): Promise<string> {
  try {
    return await run();
  } catch (error) {
    return `failed: ${(error as Error).message.split("\n")[0]}`;
  }
}

async function render(): Promise<void> {
  const alice = ACCOUNTS[0];

  const chain = await check(async () => {
    const [chainId, block] = await Promise.all([publicClient.getChainId(), publicClient.getBlockNumber()]);
    return `connected (chain ${chainId}, block ${block})`;
  });

  // A sample read: an account's balance, in wei, which formatEther turns into ETH.
  const balance = await check(async () => {
    const wei = await publicClient.getBalance({ address: alice.address });
    return `${formatEther(wei)} ETH`;
  });

  // A sample contract read, through the ABI.
  const contract = await check(async () => {
    const deployment = await loadDeployment();
    if (!deployment) return "nothing deployed. Run: node scripts/deploy.mjs mock";
    const count = await publicClient.readContract({
      address: deployment.address,
      abi: billSplitterAbi,
      functionName: "requestCount",
    });
    return `${deployment.contract} at ${deployment.address}, ${count} requests`;
  });

  app.innerHTML = `
    <h1>Bill splitter</h1>
    <ul>
      <li>Anvil at ${RPC_URL}: ${chain}</li>
      <li>${alice.label}'s balance: ${balance}</li>
      <li>Deployed contract: ${contract}</li>
    </ul>`;
}

void render();
