# Principles of Distributed Ledgers: Lecture 9 Practical

## Building a bill splitter with a coding agent (50 minutes)

The aim of this practical is to build a small app that splits a bill between friends on a blockchain, using a coding agent such as Claude Code, Codex or Grok.

Someone paid a bill for a group and wants the money back. This person, the **requester**, creates a **request** in a smart contract. A request holds an amount and the list of people who share it, the **participants**. Each participant owes an equal part of the amount, called a **share**. For example, Alice paid 0.3 ETH for dinner with Bob, Carol and Dave. She creates a request for 0.3 ETH with those three participants, and each of them owes 0.1 ETH.

The app has two parts:

- **Part 1 (required): requests.** Anyone can create a request, and anyone can read the requests and the shares, both in the contract and on a web page.
- **Part 2 (optional): payments.** The participants pay their shares in ETH, and the requester withdraws the money.

As discussed in the lecture, what matters is not a standard workflow or a particular skill, but a systematic way to build confidence that the system is ready to be released. Steps 1 to 3 below follow the workflow from the lecture for Part 1, and Step 4 repeats them for Part 2. Each step lists tools from the lecture that may help. We encourage you to use and adapt them, but none of them is required: you are free to explore your own way, as long as you end up with a product that you trust.

More information can be found in [docs/REFERENCE.md](docs/REFERENCE.md) (the files and the commands), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (how the pieces connect) and [docs/AGENT_SETUP.md](docs/AGENT_SETUP.md) (how to add skills, hooks and an MCP server to your agent). The agent follows its own instructions in [AGENTS.md](AGENTS.md) and does not read this file.

## 0. Initial setup

All the `bash` commands below should be run from the repository root (the folder that contains this file), and your agent should be started in the same folder.

The following command installs the packages of the web app:

```bash
npm install --prefix webapp
```

Note that the contracts depend on the Solidity test library, which is fetched by `git clone --recurse-submodules`. If you cloned the repository without that option, `contracts/lib/forge-std` will be empty. In that case, run `git submodule update --init --recursive`.

## 1. Discovering and planning: a clear specification

The system is described by two specifications: [docs/SPEC_CONTRACTS.md](docs/SPEC_CONTRACTS.md) for the contract and [docs/SPEC_FRONTEND.md](docs/SPEC_FRONTEND.md) for the web page. For this step, start with Part 1 of each. Note that the specifications may have gaps. You are free to decide how to fill each gap, as long as you can explain what the system does when someone asks. Each decision should be recorded as a new numbered rule in the specification concerned. `AGENTS.md` tells the agent to stop and ask whenever a specification does not decide a behaviour.

The following tools may help:

- **`grill-me`** A skill that makes the agent interview you about what the system should do. Its installation is described in [docs/AGENT_SETUP.md](docs/AGENT_SETUP.md).
- **A separate interviewing agent** An agent that did not write the specification can find what its author took for granted.
- **Simplified Technical English** The ASD-STE100 skill, which helps you write rules that an agent cannot misread.

This step is complete when, for every case of Part 1 that you can think of, you can say what the system does, and the specifications say so too.

Once you have agreed on a specification, we advise you to lock it, so that the agent cannot change it without you. The interface between the contract and the page, as well as the ready-made tests, are already on the list of locked files. This list is enforced by a hook: see "Hooks" in [docs/AGENT_SETUP.md](docs/AGENT_SETUP.md) for how to register it and how to lock more files.

## 2. Building

To start the system, open two more terminals. In the first one, start the local chain and leave it running:

```bash
anvil
```

In the second one, deploy the *mock*, a stand-in contract with fixed data that lets the page work before your own contract is ready. Then start the web app and leave it running:

```bash
node scripts/deploy.mjs mock
npm run dev --prefix webapp
```

Once the web app has started, `npm run dev` prints a `Local:` link, usually http://localhost:5173/, which you should open in your browser. For now, the page in `webapp/src/main.ts` only contains the plumbing, and should show three lines similar to the following (the address and the numbers may differ):

```text
Bill splitter
- Anvil at http://127.0.0.1:8545: connected (chain 31337, block 6)
- Alice's balance: 9999.998776051382982162 ETH
- Deployed contract: MockBillSplitter at 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9, 2 requests
```

If a line starts with "failed" or says "nothing deployed", check that `anvil` is running and deploy again. Note that Anvil's first four test accounts are Alice, Bob, Carol and Dave. Their private keys are public, so they should never be used on a real network.

The task in this step is to build the contract in `contracts/src/Requests.sol`, following Part 1 of `docs/SPEC_CONTRACTS.md`, and the rest of the page in `webapp/src/`, following Part 1 of `docs/SPEC_FRONTEND.md`. The contract and the page only meet at the fixed interface `IBillSplitter.sol`, which the mock already implements. Hence, one agent can build the contract while a second agent, started in another terminal in the repository root, builds the page against the mock.

This step is complete when:

1. The ready-made tests pass: run `forge test --match-path 'test/core/*'` in `contracts/`.
2. The tests that your agent wrote in `contracts/test/unit/` pass, and you have read them.
3. `npm run typecheck --prefix webapp` passes.
4. After running `node scripts/deploy.mjs contract` and reloading the page, a request of 0.3 ETH for Bob, Carol and Dave shows 0.1 ETH for each of them, and a request of 0 ETH shows a reason that the user can act on.

The following tools may help:

- **`AGENTS.md`** Already in the repository. You can adapt it to the way you work.
- **OpenZeppelin Skills and Cyfrin solskill** Skills for writing secure Solidity. Their sources are listed in [docs/AGENT_SETUP.md](docs/AGENT_SETUP.md).
- **Hooks** `forge-check.sh` builds the contracts after each edit and sends any error back to the agent.
- **Two agents in parallel** One for the contract and one for the page, both working against the locked interface and the mock.

## 3. Verifying: would you release it?

The contract is already partly written, and it may contain bugs. We encourage you to find them.

The following tools may help:

- **A test for each decision** Then break a rule by hand and check that a test fails. This is the idea behind mutation testing.
- **Fuzz tests** Built into Foundry: a test function that takes parameters is run with many random inputs.
- **Slither** A static analyser by Trail of Bits. It can be run in `contracts/` with `uvx --from slither-analyzer==0.11.5 slither .`, or given to your agent as an MCP server (see [docs/AGENT_SETUP.md](docs/AGENT_SETUP.md)).
- **solidity-auditor** A skill for auditing Solidity code.
- **Your own review** For each requirement, point at the lines of code that enforce it.

This step is complete when both of the following hold:

1. You would be comfortable releasing your contract and page to manage £10M, and being held responsible for them.
2. You can explain what your system does in every case that someone asks about, and show the evidence.

## 4. Part 2: payments (optional)

Once Part 1 is done and verified, repeat Steps 1 to 3 for payments: Part 2 of `docs/SPEC_CONTRACTS.md`, implemented in `contracts/src/Payments.sol`, and Part 2 of `docs/SPEC_FRONTEND.md`, on the page.

Part 2 is complete when:

1. `forge test` passes in `contracts/`, and `npm run typecheck --prefix webapp` passes.
2. On the page, you can create a request as Alice, pay as Bob, and withdraw as Alice.
3. The two conditions of Step 3 hold for the whole system.
