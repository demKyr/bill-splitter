/** How the page shows accounts and amounts (F15, F16, F20). */
import { formatUnits, type Address } from "viem";
import { ACCOUNTS } from "./chain";

const WEI_PER_MICRO_ETH = 10n ** 12n;

export function sameAddress(a: Address, b: Address): boolean {
  return a.toLowerCase() === b.toLowerCase();
}

/** F15: first 6 and last 4 characters. */
export function shortAddress(address: Address): string {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

/** F15: "Alice (0xf39F…2266)" for a test account, else the short address. */
export function accountName(address: Address): string {
  const entry = ACCOUNTS.find((a) => sameAddress(a.address, address));
  return entry ? `${entry.label} (${shortAddress(address)})` : shortAddress(address);
}

/** F16 and F20: an amount in wei as ETH, rounded to at most 6 decimals. */
export function formatEth(wei: bigint): string {
  if (wei === 0n) return "0";
  if (wei < WEI_PER_MICRO_ETH) return "<0.000001";
  const micro = (wei + WEI_PER_MICRO_ETH / 2n) / WEI_PER_MICRO_ETH;
  return formatUnits(micro, 6);
}
