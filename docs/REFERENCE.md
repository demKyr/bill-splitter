# Reference

This document lists the files of the repository and the commands used in the practical. The worksheet is [README.md](../README.md).

## Files in the repository

| Path | What it is | State |
| --- | --- | --- |
| `README.md` | The worksheet. The agent does not read it. | provided |
| `docs/SPEC_CONTRACTS.md` | The specification of the contract. The agent reads it. It was written with the [`asd-ste100`](https://github.com/danyuchn/asd-ste100-skill) skill, which applies Simplified Technical English (short sentences, one meaning per word) to minimise ambiguity. | provided, yours to change |
| `docs/SPEC_FRONTEND.md` | The specification of the web page. The agent reads it. | provided, yours to change |
| `docs/AGENT_SETUP.md` | How to add skills, hooks and the Slither MCP server to your agent, and how to lock files | provided |
| `docs/ARCHITECTURE.md` | How the system fits together, in two diagrams | provided |
| `docs/REFERENCE.md` | This reference | provided |
| `AGENTS.md`, `CLAUDE.md` | Instructions for the agent: the locked files, and where behaviour comes from | provided, yours to adapt |
| `scripts/hooks/` | The edit guard and the build check, with prepared configurations in `examples/` | optional: you register them |
| `contracts/src/interfaces/IBillSplitter.sol` | The interface: the contract's functions and errors, without their code | provided, locked |
| `contracts/src/mocks/MockBillSplitter.sol` | The mock: a stand-in contract with fixed data | provided, locked |
| `contracts/src/Requests.sol` | The contract, Part 1: requests | partly written |
| `contracts/src/Payments.sol` | The contract, Part 2: payments | partly written (optional) |
| `contracts/src/Withdrawals.sol` | The contract: withdrawing | provided |
| `contracts/src/BillSplitter.sol`, `BillSplitterBase.sol` | The deployed contract, which joins the parts, and the data that the parts share | provided, locked |
| `contracts/test/core/`, `contracts/test/payment/` | Ready-made tests for Part 1 and Part 2 | provided, locked |
| `contracts/test/unit/` | Your own tests | written by you and your agent |
| `webapp/src/chain.ts`, `webapp/src/abi.ts` | The connection to the chain, and the ABI | provided, locked |
| `webapp/src/main.ts` | The page: only plumbing, which checks the chain, reads a balance and names the deployed contract | plumbing: you build the page |
| `scripts/deploy.mjs` | Deploys the mock or your contract to the local chain | provided |

*Locked* means that `AGENTS.md` tells the agent not to edit the file, and, once you register the hooks, a hook stops it. [AGENT_SETUP.md](AGENT_SETUP.md) says how to lock more files.

## Commands

The following commands should be run from the repository root, unless the table says otherwise.

| Command | What it does |
| --- | --- |
| `anvil` | Starts the local chain. Leave it running in its own terminal. |
| `node scripts/deploy.mjs mock` | Deploys the mock to the local chain and points the web app at it |
| `node scripts/deploy.mjs contract` | Deploys your `BillSplitter` to the local chain and points the web app at it |
| `npm run dev --prefix webapp` | Serves the web app at http://localhost:5173 |
| `npm run typecheck --prefix webapp` | Type-checks the web app |
| `forge test --match-path 'test/core/*'` (in `contracts/`) | Runs the ready-made tests for Part 1 |
| `forge test --match-path 'test/unit/*' -vv` (in `contracts/`) | Runs your own tests |
| `forge test --match-path 'test/payment/*'` (in `contracts/`) | Runs the ready-made tests for Part 2 |
| `forge test` (in `contracts/`) | Runs all tests. Some Part 2 tests fail until you do Part 2. |
| `uvx --from slither-analyzer==0.11.5 slither .` (in `contracts/`) | Runs Slither without the agent. It reports medium and high findings only. |

`deploy.mjs` refuses any chain other than the local Anvil node. If you restart Anvil, the chain starts empty again, so deploy again.
