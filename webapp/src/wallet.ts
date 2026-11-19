/** The mock wallet signing screen (F4, F13, F25). */
import { formatEther, type Address } from "viem";
import { accountName } from "./format";

/** A value is text, or an amount in wei (a bigint), which the screen shows in ETH exactly (F25). */
export type SigningDetails = { account: Address; action: string; values: [label: string, value: string | bigint][] };

/** Shows the signing screen. Resolves true on "Sign", false on "Cancel". */
export function askToSign(details: SigningDetails): Promise<boolean> {
  const dialog = document.createElement("dialog");
  dialog.className = "wallet";

  const title = document.createElement("h2");
  title.textContent = "Mock wallet: sign transaction";
  const list = document.createElement("dl");
  const rows: [string, string | bigint][] = [["Account", accountName(details.account)], ["Action", details.action], ...details.values];
  for (const [label, value] of rows) {
    const dt = document.createElement("dt");
    dt.textContent = label;
    const dd = document.createElement("dd");
    dd.textContent = typeof value === "bigint" ? `${formatEther(value)} ETH` : value; // F25: no rounding
    list.append(dt, dd);
  }

  const sign = document.createElement("button");
  sign.textContent = "Sign";
  const cancel = document.createElement("button");
  cancel.textContent = "Cancel";
  dialog.append(title, list, sign, cancel);
  document.body.append(dialog);
  dialog.showModal();

  return new Promise((resolve) => {
    const close = (signed: boolean) => {
      dialog.close();
      dialog.remove();
      resolve(signed);
    };
    sign.addEventListener("click", () => close(true));
    cancel.addEventListener("click", () => close(false));
    dialog.addEventListener("cancel", (event) => {
      event.preventDefault(); // Escape counts as Cancel
      close(false);
    });
  });
}
