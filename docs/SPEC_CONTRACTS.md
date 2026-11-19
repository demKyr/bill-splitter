# Bill splitter contract specification

This file is the source of all contract behaviour. [docs/SPEC_FRONTEND.md](SPEC_FRONTEND.md) describes the web page.

## Terms

- **Requester**: the address that creates a request.
- **Participants**: the addresses that share the amount of a request.
- **Share**: the amount that one participant owes.
- **Wei**: the smallest unit of ETH (1 ETH = 10<sup>18</sup> wei). All amounts in this file are in wei.
- **Rejects ... with `X`**: the contract reverts the call with the custom error `X`, which the interface `IBillSplitter.sol` defines. A reverted call changes nothing.

## Not in scope

The contract handles ETH only: no ERC-20 tokens. It has no deadlines and no partial payments.

## Part 1: requests

- R1. Any address can create a request. The caller becomes the requester.
- R2. The contract rejects an amount of zero with `BillSplitter__InvalidAmount`.
- R3. A request has 1 to 10 participants. The contract rejects any other number with `BillSplitter__InvalidParticipants`.
- R4. The contract rejects the zero address as a participant with `BillSplitter__InvalidParticipant`.
- R5. The contract rejects an address that appears twice in one request with `BillSplitter__InvalidParticipant`.
- R6. Request IDs start at 1 and increase by 1.
- R7. When the amount divides evenly by the number of participants, each participant's share is the amount divided by that number. Example: 3 ETH among 3 participants is 1 ETH each.
- R8. The share of an address that is not a participant is zero.
- R9. Nobody can edit or cancel a request.
- R10. The contract rejects a call with an unknown request ID with `BillSplitter__RequestNotFound`.
- R11. When the amount does not divide evenly by the number of participants, the share of each participant is the amount divided by that number, rounded up to the next whole wei. Each participant owes the same share. Example: 1 wei among 3 participants is 1 wei each. The total of the shares can be up to (number of participants − 1) wei more than the amount. The contract does not overflow for any amount.
- R12. The requester can be one of the participants. The requester then owes a share like any other participant.
- R13. When a request breaks more than one rule, the contract rejects it with the error of the first rule that it breaks. The contract checks in this order: amount (R2), number of participants (R3), then each participant in list order (R4, then R5).
- R14. A request has one of three splits: equal, percentage or exact. Equal is the split of R7 and R11. `createRequest` creates an equal split.
- R15. A percentage split gives one percentage for each participant, in basis points: 1 percent is 100, so 33.33 percent is 3333.
- R16. The contract rejects a percentage split whose percentages do not add up to exactly 10000 with `BillSplitter__InvalidShares`.
- R17. In a percentage split, the share of a participant is the amount multiplied by the percentage and divided by 10000, rounded up to the next whole wei.
- R18. An exact split gives one amount for each participant. The contract rejects an exact split whose amounts do not add up to exactly the amount of the request with `BillSplitter__InvalidShares`. In an exact split, the share of a participant is its amount.
- R19. The contract rejects a percentage or an amount of zero with `BillSplitter__InvalidShares`.
- R20. The contract rejects a percentage split or an exact split whose list of percentages or amounts has a different length than the list of participants with `BillSplitter__InvalidShares`. When such a request breaks more than one rule, the contract rejects it with the error of the first rule that it breaks. The contract checks in this order: amount (R2, R22), number of participants (R3), length of the list of percentages or amounts (R20), then each participant in list order (R4, then R5), then each percentage or amount in list order (R19), then the sum (R16 or R18).
- R21. `shareOf` returns the share that R7, R11, R17 or R18 defines for the split of the request. It returns zero for an address that is not a participant (R8). A payment must equal this share (P9).
- R22. The contract rejects the amount of a percentage split that is more than `type(uint256).max / 10000` with `BillSplitter__InvalidAmount`.

## Part 2: payments (optional)

- P1. A participant pays its own share of a request in one payment, with ETH sent in the call.
- P2. The contract rejects a payment below the share with `BillSplitter__WrongPayment`.
- P3. The contract rejects a second payment by the same participant for the same request with `BillSplitter__AlreadyPaid`.
- P4. The contract rejects a payment from an address that is not a participant with `BillSplitter__NotParticipant`.
- P5. The contract keeps the paid ETH and adds it to the amount that the requester can withdraw.
- P6. A requester withdraws all its collected ETH in one call. The contract rejects a withdrawal of zero with `BillSplitter__NothingToWithdraw`.
- P7. The contract rejects a call to `hasPaid` for an address that is not a participant with `BillSplitter__NotParticipant`.
- P8. When a payment breaks more than one rule, the contract rejects it with the error of the first rule that it breaks. The contract checks in this order: request ID (R10), participant (P4), second payment (P3), amount (P2).
- P9. The contract rejects a payment that is above the share with `BillSplitter__WrongPayment`. A payment must be equal to the share. This check is part of the amount check (P2) in the order of P8.
- P10. When the ETH transfer of a withdrawal fails, the contract rejects the withdrawal with `BillSplitter__TransferFailed`. The requester keeps its collected ETH.
