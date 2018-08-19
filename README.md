# Pay with DAI
A smart contract that allows individuals with only DAI in their wallets to transact on the Ethereum network. This is done by delegating transaction sending to other network participants and paying them in DAI.

## UX
 1. User creates create the payload
 2. User signs the payload
 3. User posts the signature + payload somewhere online
 4. Random Delegator finds signature + payload
 5. Random Delegator submits it to the smart contract

## Implimentation Notes
 * Initiator must pre-approve specific delegator(s) or a special smart contract
 * Special smart contract sends all fees to it + delegators withdraw from it

## Test Cases
 * [NOTE initiator cannot send pure ERC20 tokens...]
 * Call OasisDEX or another OasisDEX (using DAI as a base trade)
 * v2 -> Wyre integration
 * v3 -> buying an item that is priced in ETH in DAI
 * v4 -> Writing the special smart contract
