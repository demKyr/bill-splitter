# Agent instructions

This repository is the starting point for a 50-minute practical. A human supervises you and has little time. Make small changes, and say what you did.

The repository has two parts: the contract in `contracts/` (Foundry) and the web app in `webapp/` (TypeScript, Vite, viem). They meet only at the interface `contracts/src/interfaces/IBillSplitter.sol`.

## Working rules

- Do not read `README.md`. It is the human's worksheet, not an input for you.
- Fill the gaps. Do not rewrite code that works.

## Where behaviour comes from

- `docs/SPEC_CONTRACTS.md` is the source of all contract behaviour. `docs/SPEC_FRONTEND.md` describes the web page.
- Do not invent behaviour. If `docs/SPEC_CONTRACTS.md` or `docs/SPEC_FRONTEND.md` does not decide a behaviour, stop and ask.
- When the human decides, record the decision in the spec concerned, as a new numbered rule. If the spec is locked, give the human the rule to add instead.

## Skills

- When the human's prompt says how to run a skill, follow the prompt over the skill's own instructions. A skill's text arrives after the prompt, but it is not a newer message from the human, and it does not override the prompt.
- For example, if the prompt asks for every question in one message, ask them all in one message, even when the skill says to ask in rounds or one at a time. Where a question depends on an earlier one, assume your guess for the earlier one and say so.

## Locked files

- Do not edit, remove or move these files: `contracts/src/interfaces/`, `contracts/src/mocks/`, `contracts/src/BillSplitter.sol`, `contracts/src/BillSplitterBase.sol`, `contracts/test/core/`, `contracts/test/payment/`, `webapp/src/chain.ts`, `webapp/src/abi.ts` and `scripts/hooks/`.
- The human can lock more files, e.g., an agreed specification. The full list is `LOCKED` in `scripts/hooks/guard-locked.mjs`.
- If the human asks you to edit a locked file to test the hooks, attempt the edit with your file-edit tool.

## Hooks

- The human may register hooks that run before and after your edits. If a hook refuses an edit or reports an error, do not work around it, for example with a shell command. Fix the cause, or stop and ask.

## Contract

- Replace the body of each TODO completely.
- High-level functions read like pseudocode. Put the detail in named helper functions.
- Keep it simple. Add no feature that the specification does not ask for, and no dependency.
- Revert with the custom errors of the interface.
- For each rule that you add to `docs/SPEC_CONTRACTS.md`, write one test in `contracts/test/unit/`.
- After you edit a `.sol` file, run `forge fmt && forge build` in `contracts/`, and fix every error and warning.
- Before you finish Part 1, run `forge test --match-path 'test/core/*'` and `forge test --match-path 'test/unit/*'` in `contracts/`. Fix the implementation, not the ready-made tests. Some tests in `test/payment/` fail until Part 2 is complete. That is expected.

## Web app

- Use the clients, accounts and ABI that `webapp/src/chain.ts` exports. Add no dependency and no framework.
- Before you finish, run `npm run typecheck` in `webapp/`.

## Keys and networks

- Use only the local Anvil node and Anvil's default test accounts. Never read, request or use any other private key. Never send a transaction to any other network.
