/** Part 1 of docs/SPEC_FRONTEND.md: the acting account, the create form and the list of requests. */
import { BaseError, ContractFunctionRevertedError, parseEther, parseEventLogs, type Address } from "viem";
import { ACCOUNTS, billSplitterAbi, publicClient, walletClientFor, type Deployment } from "./chain";
import { accountName, formatEth, sameAddress } from "./format";
import { askToSign } from "./wallet";

/** F21: a decimal number of zero or more, with at most 18 decimals. */
const AMOUNT_FORMAT = /^\d+(\.\d{1,18})?$/;

type RequestView = { id: bigint; requester: Address; amount: bigint; shares: { participant: Address; share: bigint }[] };

let acting: Address | null = null; // F9
let listVersion = 0; // ignores a list read that a newer one replaced

export function mountRequests(root: HTMLElement, deployment: Deployment): void {
  root.innerHTML = `
    <section>
      <h2>Acting account</h2>
      <label>Act as <select id="acting"><option value="">Choose an account</option></select></label>
      <p>Acting account: <strong id="acting-shown">none</strong></p>
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
      <div id="list"></div>
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
  };
  type Ui = typeof ui;

  select.addEventListener("change", () => {
    const hadNone = acting === null;
    acting = (select.value || null) as Address | null;
    if (hadNone && acting) chooseParticipant(ui.boxes, acting); // F23; F24: no change otherwise
    showActing(ui);
    void renderList(ui.list, deployment); // F18
  });

  ui.form.addEventListener("submit", (event) => {
    event.preventDefault();
    void createRequest(ui, deployment);
  });

  showActing(ui);
  void renderList(ui.list, deployment);

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
    void renderList(ui.list, deployment); // F18
  }
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
      }
    }
    return `The transaction failed: ${error.shortMessage}`;
  }
  return `The transaction failed: ${(error as Error).message}`;
}

/** F7, F8, F17, F19: the requests that involve the acting account, newest first. */
async function renderList(list: HTMLElement, deployment: Deployment): Promise<void> {
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
  for (const r of requests) ul.append(requestItem(r, account));
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
      })),
    );
    views.push({ id, requester, amount, shares: [...shares] });
  }
  return views;
}

function requestItem(r: RequestView, account: Address): HTMLLIElement {
  const li = document.createElement("li");
  li.append(`Request ${r.id}: ${formatEth(r.amount)} ETH, requester `, accountLabel(r.requester, account));
  const shares = document.createElement("ul");
  for (const { participant, share } of r.shares) {
    const item = document.createElement("li");
    item.append(accountLabel(participant, account), `: share ${formatEth(share)} ETH`);
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
