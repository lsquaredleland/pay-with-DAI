# Pay with DAI
A smart contract that allows individuals with only DAI in their wallets to transact on the Ethereum network. This is done by delegating transaction sending to other network participants and paying them in DAI.

## UX
 1. User creates create the payload
 2. User signs the payload
 3. User posts the signature + payload somewhere online
 4. Random Delegator finds signature + payload
 5. Random Delegator submits it to the smart contract
 6. Random Delegator withdrawls fees from DelegatorBank

## Implimentation Notes
 * Initiator must set allowance for specific delegator(s) or a DelegatorBank contract
 * DelegatorBank recieves all + delegators withdraw from it
 * Probably should force all delegators to use the DelegatorBank, makes setting up the approval more easily (set feeRecipient as DelegatorBank)

## Test Cases
 * [NOTE initiator cannot send pure ERC20 tokens...]
 * Call OasisDEX or another DEX (using DAI as a base trade)
 * v2 -> Wyre integration
 * v3 -> buying an item that is priced in ETH in DAI
 * v4 -> Writing the special smart contract

## How to Circumvent Allowances
 1. Give people "Wrapped DAI" (wDAI)
 2. wDAI has an infinte allowance with the DelegateBank (aka special smart contract)
 3. On the 1st transaction a small amount of wDAI is converted to DAI then ETH
 4. Which is is used to set up the allowance with the DelegateBank (close to infinite allowance) (need to worry about gas price variations)
 5. Now users are spending normal DAI
