# Bill splitter web page specification

This file describes the web page in `webapp/`, from the user's side. The page shows the contract that `node scripts/deploy.mjs` deployed, and sends transactions to it. All contract behaviour comes from [docs/SPEC_CONTRACTS.md](SPEC_CONTRACTS.md).

## Terms

- **Acting account**: the account that the user chose to act as. The page signs transactions as this account.
- **Test account**: one of Anvil's first four default accounts, named Alice, Bob, Carol and Dave. The page can sign only for these accounts.

## Already in place

`webapp/src/main.ts` has only plumbing: it shows whether Anvil answers, Alice's balance, and which contract is deployed. `webapp/src/chain.ts` holds the test accounts and their keys, and the clients that read from the chain and send transactions.

## Constraint

- C1. The page calculates no share and no status. It shows the values that the contract returns.

## Part 1: requests

- F1. The user chooses the acting account from the four test accounts, and can change it at any time. The page always shows the acting account.
- F2. The page has a form to create a request. The user enters an amount in ETH, and chooses the participants from the four test accounts. The button names the acting account, e.g., "Create request as Alice".
- F3. The page disables the button when no account is chosen. Next to the button, the page shows the reason.
- F4. Before the page sends a transaction, it shows the user what the transaction does, and the user confirms or cancels it. If the user cancels, the page tells the user that it sent nothing.
- F5. When the contract rejects a request, the page tells the user why, in terms that the user can act on. The form keeps the values that the user entered.
- F6. After the contract creates a request, the page says so, and the form clears.
- F7. The page lists the requests that involve the acting account, as requester or as participant, with their count. For each request, the page shows its ID, its amount, its requester, and each participant's share as the contract returns it.
- F8. When no account is chosen, the list says that the user must choose one. When no request involves the acting account, the list says so.
- F9. When the page opens, the page has no acting account.
- F10. Every choice list offers all four test accounts, including the acting account. The page chooses no value for the user, except as F23 says.
- F11. The page does not apply the rules of the contract itself. When the contract rejects a value, the page shows the reason, as F5 says.
- F12. Before the page shows the signing screen, the page asks the contract if it accepts the transaction. This step sends no transaction. If the contract rejects the transaction, the page does not show the signing screen. The page shows the reason, as F5 says.
- F13. The confirmation in F4 is a mock wallet signing screen. The signing screen shows the acting account, the action and each value that the transaction sends. The signing screen has a "Sign" button and a "Cancel" button.
- F14. Each success message names the item that the transaction created or changed, e.g., "Request 4 created."
- F15. The page shows a test account as its name and its short address, e.g., "Alice (0xf39F…2266)". The page shows any other address as its short address, e.g., "0x9965…A4dc". A short address is the first 6 characters and the last 4 characters of the address.
- F16. The page rounds each number to at most 6 decimals, e.g., "0.333333" and "1".
- F17. Each list shows the newest item first.
- F18. The page reads its data again when the user changes the acting account. The page reads its data again after each transaction that it sends. The page does not watch the chain for other changes.
- F19. The page highlights the acting account wherever a list shows it.
- F20. The page shows an amount that is more than zero and less than 0.000001 as "<0.000001". This rule overrides F16 for such amounts. An amount of zero is shown as "0".
- F21. The page accepts an amount only if it is a decimal number of zero or more, with at most 18 decimals. For any other input, for example "abc", "-1" or a number with 19 decimals, the page sends nothing and tells the user to enter an amount in ETH with at most 18 decimals. The form keeps the values that the user entered. This rule checks the format of the input only. An amount of zero is not valid. The page does not check it itself: the contract rejects it (R2), the page sends no transaction, and the page tells the user to enter an amount above zero, as F5 and F12 say.
- F22. The page does not check the number of participants itself. When the user chooses no participant, the contract rejects the request, and the page tells the user to choose at least one participant, as F5 and F12 say.
- F23. When the user chooses an acting account and no account was chosen before, the participant list of the create form has that account chosen. The user can remove it. The page chooses no other participant. After the contract creates a request, the form clears, and the acting account is chosen again as a participant.
- F24. When the user changes the acting account, the participant list of the create form does not change. The page does not choose the new acting account as a participant.

## Part 2: payments (optional)

- G1. For each request in the list, the page shows which participants paid their share.
- G2. When the acting account is a participant of a request and has not paid, the page shows a button to pay its share.
- G3. The page shows the amount that the acting account can withdraw.
- G4. When that amount is above zero, the page shows a button to withdraw it.
- G5. Paying and withdrawing follow F4 and F5: the user confirms each transaction, and the page tells the user why the contract rejected it.
- G6. Paying and withdrawing follow F11 and F12. The page does not stop a transaction that the contract accepts.
- G7. Next to each participant's share, the list shows "Paid" or "Not paid". The page shows no status for a request as a whole, as C1 says.
- G8. The pay button is in the entry of its request in the list, next to the share of the acting account.
- G9. When a button pays or withdraws ETH, the button names the amount and the acting account. Example: "Pay 1 ETH as Bob" and "Withdraw 2 ETH as Alice".
- G10. When no account is chosen, each part of the page that shows data for the acting account says that the user must choose one.
- G11. Next to the acting account, the page shows the ETH balance of that account.
- G12. When a transaction concerns a request, the signing screen names the request and its requester. Example: "Pay 1 ETH for request 4 (requester Alice (0xf39F…2266))".
