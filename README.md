# Pay with DAI
A smart contract that allows individuals with only DAI in their wallets to transact on the Ethereum network. This is done by delegating transaction sending to other network participants and paying them in DAI.

## UX
 1. User creates create the payload
 2. User signs the payload
 3. User posts the signature + payload somewhere online
 4. Random Delegator finds signature + payload
 5. Random Delegator submits it to the smart contract
 6. Smart contract executes logic: calling an external contract or transfering ERC20
 6. Random Delegator withdrawls fees from DelegateBank

## Implimentation Notes
 * Initiator must set allowance for specific delegator(s) or a DelegateBank contract
 * DelegateBank recieves all + delegators withdraw from it
 * Delegators must use the DelegateBank

## Test Cases
 * v1 -> Call some external contract (DEXs, etc)
 * v1.5 -> Have a DelegateBank
 * v2 -> Wyre integration
 * v3 -> buying an item that is priced in ETH in DAI
 * v4 -> wDAI integration
 * v5 ->

## How to Circumvent Allowances
 1. Give people "Wrapped DAI" (wDAI)
 2. If transferFrom() is called from the DelegateBank address, allowance limits are ignored
 3. On the 1st transaction a small amount of wDAI is converted to DAI then ETH
 4. Which is is used to set up the allowance with the DelegateBank (close to infinite allowance) (need to worry about gas price variations)
 5. All wDAI is converted to DAI
 6. Now users are spending normal DAI

## Special Case, Transaction using wDAI
This allows first time users who have not set approval with the whitelist DelegateBank contract to transact. Ex: users who are airdropped wDAI into a clean address.
 1. Check to see if the address has wDAI
 2. In PayWithDAI contract, have special case
 3. All wDAI is unwrapped to DAI
 4. Set approval for DAI to whitelist DelegateBank contract
 4. Proceed as normal
