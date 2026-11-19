/** docs/SPEC_FRONTEND.md, Part 1 (acting account, create form, list of requests) and Part 2 (payments). */
import { BaseError, ContractFunctionRevertedError, formatEther, parseEther, parseEventLogs, type Address, type Hex } from "viem";
import { ACCOUNTS, billSplitterAbi, publicClient, walletClientFor, type Deployment } from "./chain";
import { accountName, formatEth, sameAddress } from "./format";
import { askToSign } from "./wallet";

/** F21: a decimal number of zero or more, with at most 18 decimals. */
const AMOUNT_FORMAT = /^\d+(\.\d{1,18})?$/;

type ShareView = { participant: Address; share: bigint; paid: boolean };
type RequestView = { id: bigint; requester: Address; amount: bigint; shares: ShareView[] };

let acting: Address | null = null; // F9
let listVersion = 0; // ignores a list read that a newer one replaced
let accountVersion = 0; // the same, for the balance and the withdrawable amount

export function mountRequests(root: HTMLElement, deployment: Deployment): void {
  root.innerHTML = `
    <section>
      <h2>Acting account</h2>
      <label>Act as <select id="acting"><option value="">Choose an account</option></select></label>
      <p>Acting account: <strong id="acting-shown">none</strong> <span id="balance"></span></p>
    </section>
    <section>
      <h2>Create a request</h2>
      <form id="create" novalidate>
        <label>Amount in ETH <input id="amount" type="text" inputmode="decimal" autocomplete="off" /></label>
        <fieldset id="participants"><legend>Participants</legend></fieldset>
        <button id="create-button" type="submit"></button>
        <span id="create-reason"></span>
      </form>
      <p id="message" role="status"></p>
    </section>
    <section>
      <h2>Requests</h2>
      <p id="pay-message" role="status"></p>
      <div id="list"></div>
    </section>
    <section>
      <h2>Withdraw</h2>
      <div id="withdraw"></div>
      <p id="withdraw-message" role="status"></p>
    </section>`;

  const select = root.querySelector<HTMLSelectElement>("#acting")!;
  const fieldset = root.querySelector<HTMLFieldSetElement>("#participants")!;
  // F10: every choice list offers all four test accounts.
  for (const account of ACCOUNTS) {
    select.append(new Option(accountName(account.address), account.address));
    const label = document.createElement("label");
    const box = document.createElement("input");
    box.type = "checkbox";
    box.name = "participant";
    box.value = account.address;
    label.append(box, ` ${accountName(account.address)}`);
    fieldset.append(label);
  }

  const ui = {
    select,
    actingShown: root.querySelector<HTMLElement>("#acting-shown")!,
    form: root.querySelector<HTMLFormElement>("#create")!,
    amount: root.querySelector<HTMLInputElement>("#amount")!,
    boxes: [...fieldset.querySelectorAll<HTMLInputElement>("input[name=participant]")],
    button: root.querySelector<HTMLButtonElement>("#create-button")!,
    reason: root.querySelector<HTMLElement>("#create-reason")!,
    message: root.querySelector<HTMLElement>("#message")!,
    list: root.querySelector<HTMLElement>("#list")!,
    balance: root.querySelector<HTMLElement>("#balance")!,
    payMessage: root.querySelector<HTMLElement>("#pay-message")!,
    withdraw: root.querySelector<HTMLElement>("#withdraw")!,
    withdrawMessage: root.querySelector<HTMLElement>("#withdraw-message")!,
  };
  type Ui = typeof ui;

  select.addEventListener("change", () => {
    const hadNone = acting === null;
    acting = (select.value || null) as Address | null;
    if (hadNone && acting) chooseParticipant(ui.boxes, acting); // F23; F24: no change otherwise
    showActing(ui);
    refresh(); // F18
  });

  ui.form.addEventListener("submit", (event) => {
    event.preventDefault();
    void createRequest(ui, deployment);
  });

  showActing(ui);
  refresh();

  /** F18: reads all data for the acting account again. */
  function refresh(): void {
    void renderList(ui.list, deployment, payShare);
    void renderAccount(ui, deployment, withdraw);
  }

  async function createRequest(ui: Ui, deployment: Deployment): Promise<void> {
    if (!acting) return;
    const account = acting;
    const input = ui.amount.value.trim();
    if (!AMOUNT_FORMAT.test(input)) {
      say(ui, "Enter an amount in ETH, with at most 18 decimals."); // F21
      return;
    }
    const amount = parseEther(input);
    const participants = ui.boxes.filter((box) => box.checked).map((box) => box.value as Address);

    // F12: ask the contract first. This sends nothing.
    let request;
    try {
      ({ request } = await publicClient.simulateContract({
        address: deployment.address,
        abi: billSplitterAbi,
        functionName: "createRequest",
        args: [amount, participants],
        account,
      }));
    } catch (error) {
      say(ui, reasonOf(error)); // F5, F11: the form keeps its values
      return;
    }

    // F4, F13: the mock wallet signing screen.
    const signed = await askToSign({
      account,
      action: "Create request",
      values: [
        ["Amount", amount], // wei: the signing screen shows it exactly (F25)
        ["Participants", participants.length ? participants.map(accountName).join(", ") : "none"],
      ],
    });
    if (!signed) {
      say(ui, "Cancelled. Nothing was sent.");
      return;
    }

    try {
      const hash = await walletClientFor(account).writeContract(request);
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      if (receipt.status !== "success") throw new Error("The transaction was reverted.");
      const [created] = parseEventLogs({ abi: billSplitterAbi, eventName: "RequestCreated", logs: receipt.logs });
      say(ui, `Request ${created.args.requestId} created.`); // F6, F14
      clearForm(ui);
    } catch (error) {
      say(ui, reasonOf(error));
    }
    refresh(); // F18
  }

  /** G2, G5, G6, G12: pays the share that the contract returned. The page calculates nothing (C1). */
  async function payShare(r: RequestView, share: bigint): Promise<void> {
    if (!acting) return;
    const account = acting;
    const message = ui.payMessage;
    let request;
    try {
      ({ request } = await publicClient.simulateContract({
        address: deployment.address,
        abi: billSplitterAbi,
        functionName: "pay",
        args: [r.id],
        value: share,
        account,
      })); // F12
    } catch (error) {
      message.textContent = reasonOf(error); // F5, F11
      return;
    }
    const signed = await askToSign({
      account,
      action: `Pay ${formatEther(share)} ETH for request ${r.id} (requester ${accountName(r.requester)})`, // G12, F25
      values: [
        ["Request", `${r.id}`],
        ["Requester", accountName(r.requester)],
        ["ETH sent", share],
      ],
    });
    if (!signed) {
      message.textContent = "Cancelled. Nothing was sent.";
      return;
    }
    try {
      await sendAndWait(() => walletClientFor(account).writeContract(request));
      message.textContent = `Share of ${accountName(account)} in request ${r.id} paid.`; // F14
    } catch (error) {
      message.textContent = reasonOf(error);
    }
    refresh(); // F18
  }

  /** G4, G5, G6: withdraws the amount that the contract returned. */
  async function withdraw(amount: bigint): Promise<void> {
    if (!acting) return;
    const account = acting;
    const message = ui.withdrawMessage;
    let request;
    try {
      ({ request } = await publicClient.simulateContract({
        address: deployment.address,
        abi: billSplitterAbi,
        functionName: "withdraw",
        account,
      })); // F12
    } catch (error) {
      message.textContent = reasonOf(error); // F5, F11
      return;
    }
    const signed = await askToSign({
      account,
      action: `Withdraw ${formatEther(amount)} ETH`, // F25
      values: [
        ["Amount to receive", amount],
        ["ETH sent", 0n],
      ],
    });
    if (!signed) {
      message.textContent = "Cancelled. Nothing was sent.";
      return;
    }
    try {
      await sendAndWait(() => walletClientFor(account).writeContract(request));
      message.textContent = `Withdrawal of ${formatEth(amount)} ETH to ${accountName(account)} done.`; // F14
    } catch (error) {
      message.textContent = reasonOf(error);
    }
    refresh(); // F18
  }
}

/** Sends a simulated transaction and waits for it. Throws if it reverted. */
async function sendAndWait(send: () => Promise<Hex>): Promise<void> {
  const hash = await send();
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  if (receipt.status !== "success") throw new Error("The transaction was reverted.");
}

/** G3, G4, G9, G10, G11: the balance and the withdrawable amount of the acting account. */
async function renderAccount(
  ui: { balance: HTMLElement; withdraw: HTMLElement },
  deployment: Deployment,
  onWithdraw: (amount: bigint) => void,
): Promise<void> {
  const version = ++accountVersion;
  if (!acting) {
    ui.balance.textContent = "(choose an acting account to see its balance)";
    ui.withdraw.textContent = "Choose an acting account to see what it can withdraw.";
    return;
  }
  const account = acting;
  let balance: bigint, amount: bigint;
  try {
    [balance, amount] = await Promise.all([
      publicClient.getBalance({ address: account }),
      publicClient.readContract({
        address: deployment.address,
        abi: billSplitterAbi,
        functionName: "withdrawable",
        args: [account],
      }),
    ]);
  } catch (error) {
    if (version === accountVersion) ui.withdraw.textContent = `Could not read the account: ${(error as Error).message.split("\n")[0]}`;
    return;
  }
  if (version !== accountVersion) return;

  ui.balance.textContent = `balance ${formatEth(balance)} ETH`;
  ui.withdraw.replaceChildren(`${accountName(account)} can withdraw ${formatEth(amount)} ETH.`);
  if (amount > 0n) {
    const button = document.createElement("button");
    button.textContent = `Withdraw ${formatEth(amount)} ETH as ${labelOf(account)}`; // G9
    button.addEventListener("click", () => onWithdraw(amount));
    ui.withdraw.append(" ", button);
  }
}

function labelOf(address: Address): string {
  return ACCOUNTS.find((a) => sameAddress(a.address, address))?.label ?? accountName(address);
}

/** F1, F3: shows the acting account and the state of the create button. */
function showActing(ui: {
  actingShown: HTMLElement;
  button: HTMLButtonElement;
  reason: HTMLElement;
}): void {
  ui.actingShown.textContent = acting ? accountName(acting) : "none";
  const name = acting ? ACCOUNTS.find((a) => sameAddress(a.address, acting!))!.label : null;
  ui.button.textContent = name ? `Create request as ${name}` : "Create request";
  ui.button.disabled = !acting;
  ui.reason.textContent = acting ? "" : "Choose an acting account first.";
}

function chooseParticipant(boxes: HTMLInputElement[], address: Address): void {
  for (const box of boxes) if (sameAddress(box.value as Address, address)) box.checked = true;
}

/** F6, F23: clears the form and chooses the acting account again. */
function clearForm(ui: { amount: HTMLInputElement; boxes: HTMLInputElement[] }): void {
  ui.amount.value = "";
  for (const box of ui.boxes) box.checked = false;
  if (acting) chooseParticipant(ui.boxes, acting);
}

function say(ui: { message: HTMLElement }, text: string): void {
  ui.message.textContent = text;
}

/** F5: turns a contract rejection into a reason that the user can act on. */
function reasonOf(error: unknown): string {
  if (error instanceof BaseError) {
    const revert = error.walk((e) => e instanceof ContractFunctionRevertedError);
    if (revert instanceof ContractFunctionRevertedError) {
      switch (revert.data?.errorName) {
        case "BillSplitter__InvalidAmount":
          return "Enter an amount above zero."; // F21
        case "BillSplitter__InvalidParticipants":
          return "Choose at least one participant."; // F22
        case "BillSplitter__InvalidParticipant":
          return "Each participant must be a different, valid address.";
        case "BillSplitter__RequestNotFound":
          return "This request does not exist. Reload the page.";
        case "BillSplitter__NotParticipant":
          return "Only a participant of this request can pay a share. Choose that account.";
        case "BillSplitter__AlreadyPaid":
          return "This share is already paid.";
        case "BillSplitter__WrongPayment":
          return "The amount sent does not match the share. Reload the page and pay again.";
        case "BillSplitter__NothingToWithdraw":
          return "This account has nothing to withdraw.";
        case "BillSplitter__TransferFailed":
          return "The contract could not send the ETH to this account. Nothing was withdrawn.";
      }
    }
    return `The transaction failed: ${error.shortMessage}`;
  }
  return `The transaction failed: ${(error as Error).message}`;
}

/** F7, F8, F17, F19: the requests that involve the acting account, newest first. */
async function renderList(
  list: HTMLElement,
  deployment: Deployment,
  onPay: (r: RequestView, share: bigint) => void,
): Promise<void> {
  const version = ++listVersion;
  if (!acting) {
    list.textContent = "Choose an acting account to see its requests.";
    return;
  }
  const account = acting;
  let requests: RequestView[];
  try {
    requests = await readRequests(deployment.address, account);
  } catch (error) {
    if (version === listVersion) list.textContent = `Could not read the requests: ${(error as Error).message.split("\n")[0]}`;
    return;
  }
  if (version !== listVersion) return;

  list.replaceChildren();
  const count = document.createElement("p");
  count.textContent =
    requests.length === 0
      ? `No request involves ${accountName(account)}.`
      : `${requests.length} request${requests.length === 1 ? "" : "s"} involve${requests.length === 1 ? "s" : ""} ${accountName(account)}.`;
  list.append(count);

  const ul = document.createElement("ul");
  for (const r of requests) ul.append(requestItem(r, account, onPay));
  if (requests.length) list.append(ul);
}

async function readRequests(address: Address, account: Address): Promise<RequestView[]> {
  const count = await publicClient.readContract({ address, abi: billSplitterAbi, functionName: "requestCount" });
  const views: RequestView[] = [];
  for (let id = count; id >= 1n; id--) {
    const [requester, amount, participants] = await publicClient.readContract({
      address,
      abi: billSplitterAbi,
      functionName: "getRequest",
      args: [id],
    });
    const involved = sameAddress(requester, account) || participants.some((p) => sameAddress(p, account));
    if (!involved) continue;
    const shares = await Promise.all(
      participants.map(async (participant) => ({
        participant,
        share: await publicClient.readContract({ address, abi: billSplitterAbi, functionName: "shareOf", args: [id, participant] }),
        paid: await publicClient.readContract({ address, abi: billSplitterAbi, functionName: "hasPaid", args: [id, participant] }), // G1
      })),
    );
    views.push({ id, requester, amount, shares: [...shares] });
  }
  return views;
}

function requestItem(r: RequestView, account: Address, onPay: (r: RequestView, share: bigint) => void): HTMLLIElement {
  const li = document.createElement("li");
  li.append(`Request ${r.id}: ${formatEth(r.amount)} ETH, requester `, accountLabel(r.requester, account));
  const shares = document.createElement("ul");
  for (const { participant, share, paid } of r.shares) {
    const item = document.createElement("li");
    item.append(accountLabel(participant, account), `: share ${formatEth(share)} ETH, ${paid ? "Paid" : "Not paid"}`); // G7
    if (!paid && sameAddress(participant, account)) {
      // G2, G8, G9: the button pays the share that the contract returned.
      const button = document.createElement("button");
      button.textContent = `Pay ${formatEth(share)} ETH as ${labelOf(account)}`;
      button.addEventListener("click", () => onPay(r, share));
      item.append(" ", button);
    }
    shares.append(item);
  }
  li.append(shares);
  return li;
}

/** F19: highlights the acting account. */
function accountLabel(address: Address, account: Address): HTMLElement {
  const el = document.createElement(sameAddress(address, account) ? "mark" : "span");
  el.textContent = accountName(address);
  return el;
}
