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

## Part 2: payments (optional)

- P1. A participant pays its own share of a request in one payment, with ETH sent in the call.
- P2. The contract rejects a payment below the share with `BillSplitter__WrongPayment`.
- P3. The contract rejects a second payment by the same participant for the same request with `BillSplitter__AlreadyPaid`.
- P4. The contract rejects a payment from an address that is not a participant with `BillSplitter__NotParticipant`.
- P5. The contract keeps the paid ETH and adds it to the amount that the requester can withdraw.
- P6. A requester withdraws all its collected ETH in one call. The contract rejects a withdrawal of zero with `BillSplitter__NothingToWithdraw`.
- P7. The contract rejects a call to `hasPaid` for an address that is not a participant with `BillSplitter__NotParticipant`.
- P8. When a payment breaks more than one rule, the contract rejects it with the error of the first rule that it breaks. The contract checks in this order: request ID (R10), participant (P4), second payment (P3), amount (P2).
