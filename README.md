# Pay with DAI
A smart contract that allows individuals with only DAI in their wallets to transact on the Ethereum network. This is done by delegating transaction sending to other network participants and paying them in DAI.

## UX
 1. User creates create the payload
 ![GitHub Logo](/datafields.png)
 2. User signs the payload
 3. User posts the signature + payload somewhere online
 4. Random Delegator finds signature + payload
 5. Random Delegator submits it to the smart contract
 6. Smart contract executes logic: calling an external contract or transfering ERC20
 6. Random Delegator withdrawls fees from DelegateBank

## Implimentation Notes
 * Signer must set allowance for specific delegator(s) or a DelegateBank contract
 * DelegateBank recieves all + delegators withdraw from it
 * Delegators must use the DelegateBank

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

## Next Iteration
 * How to convert DAI to ETH without having the Delegator having to be maker (supplying ETH + recieving DAI)
  * Integration with Oasis DEX via Oasis Direct proxy contracts
  * Or perhaps using forwarding contracts
 * Send ETH to an address which is not from the Delegator
 	* Enables purchasing of crypto assets such as CryptoKitties (buying items priced in ETH in DAI)
 * Wyre Integration
 * Impliment 0x like relayer
 * Impliment 0x like code patterns for orderHash verification (EIP712), order schema, etc
 * Implimenting proxy contracts

## Function Interaction
The steps below are all done by the Delegator. The signer generates payload offline and send the payload and signature to delegators who submit on their behalf.
 1. `verifySignature()` checks that signature is from the signer
 	* Checks that signature hasn't been executed before
 2. wDAI to DAI conversion step
 	* Checks if there is a Balance of wDAI
 	* Call `withdrawTo` in WDAI contract
 		* Check that msg.sender is DelegateBank
 		* Clears balance of wDAI
 		* Transfers DAI balance of WDAI contract to signer
	* Sets DAI approve for DelegateBank to infinite
 3. `verifyPayload()` checks that the payload content equals the hash
 4. `verifyExecutionTime()` checks if execution height hasn't passed yet
 5. `verifyFunds()` checks that signer has enough DAI and appropiate allowance with DelegateBank
 6. Transfers the amount of DAI required to the DelegateBank
 7. Calls `send()` in DelegateBank to transfer funds to intended recipient
 8. Calls `deposit()` in DelegateBank to report how much the fee was
 9. Sets the signature as used, so cannot be replayed
 10. Calls `withdraw()` in DelegateBank to withdraw the accumulated fees

## Initial Submission
This was initially done at MakerDAO's and Wyre's [hackathon](https://www.eventbrite.com/e/unblock-the-hackathon-tickets-48209728596) in August 2018. With Leland Lee, Alan Lai (Blockchain at Berkeley) and Phillip Liu Jr. (JLab)
