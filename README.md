# Pay with DAI
A smart contract that allows individuals with only DAI in their wallets to transact on the Ethereum network. This is done by delegating transaction sending to other network participants and paying them in DAI.

## UX
 1. User creates create the payload
 ![GitHub Logo](/imgs/datafields.png)
 2. User signs the payload
 3. User posts the signature + payload somewhere online
 4. Random Delegator finds signature + payload
 5. Random Delegator submits it to the smart contract
 6. Smart contract executes logic: calling an external contract or transfering ERC20
 6. Random Delegator withdrawls fees from DelegateBank

# Technical Details
Here we will elaborate on how we achieved a censorship resistant(ish) method for delegating transactions to other actors. In a nutshell, there is a pre-signed commitment that a signer creates and a delegator submits it to a smart contract that executes the logic contained within the commitment. However there are some nuances around the ERC-20 standard that we had to circumvent. This portion will get quite technical and feel free to skip over it. For additional technical details go through the repository. As a side note our implementation is extremely bug ridden with poor test coverage and exists merely to prove a point rather than be used in production, and perhaps it is broken.

We started by looking at the existing literature on delegation in Ethereum, the closest thing we found was EIP-865 (turns out there are more, oops) which extended ERC-20 to natively allow for token transfers where another actor pays for gas. Although valuable, blockchains are more interesting with smart contracts, so we made a more generalised approach that would work for both transfers and smart contract execution and would have no modification to the underlying ERC20 contract. Therefore it can exist on top of existing standards.

## High Level Model
![High Level Flow Diagram](/imgs/highLevel.png)
1. A signer initiate a transaction by signing a [data packet]() comprised of the necessary fields and submitting it to a delegator (offchain interaction).
2. The delegator submits the signature and the preimage of the hash to the `PayWithToken` smart contract.
	1. ECDSA signature is verified.
	2. Payload contents are verified.
	3. Verify that the execution height hasn't passed yet.
	4. Verify that the signer sufficient token balance is available.
	5. External method is called or tokens are transferred.
	6. Delegator pays gas and receives a fee in ERC20 token
3. Delegators get paid.

In principle all the above would work, however due to some quirks of the ERC20 standard additional steps are needed. Because the delegator is requesting tokens on behalf of the signer, the signer must set up an initial [`allowance`](), but how can this allowance be setup if the signer has no Ether? Instead of airdropping normal tokens, a special token is given instead. This is called a `wrapped token`, this closely follows the implementation of [wrapped ether](). This token however has an infinite allowance with a particular smart contract that we call the DelegateBank. Everytime tokens needs to be sent to the delegator as a fee or to a recipient, the necessary amount of wToken is unwrapped to token and sent to the DelegateBank where it is transferred to the final destination.

The DelegateBank allows a delegator to withdraw tokens owned by the signer directly to the bank. This is done to only have one allowance setup, else every single delegator would have to have an allowance. The DelegateBank allows anyone to be a delegator, as tokens are withdrawn from the signer's address directly to the bank which already has an allowance. Delegators can withdraw their accumulated fees from the bank whenever they feel the need to.

## Detailed Model (Token Transfer)
![First Token Transfer](/imgs/firstTransfer.png)
1. A signer initiate a transaction by filling out the field below and signing the concatenation of all the fields which is submitted to a delegator
2. The delegator submits the signature and the preimage of the hash to the `PayWithToken` smart contract and calls `ExecuteTokenTransfer`.
	1. Signature is verified.
	2. Payload contents are verified.
	3. Verify that the execution height hasn't passed yet.
	4. Verify that the signer sufficient token balance is available
3. Fees in wToken are converted to token then sent to the bank
4. Tokens are then sent from the Bank to the Recipient, Delegator pays for the gas of the entire transaction
5. Transaction fee from delegation is logged into the DelegateBank
6. Delegators can withdraw from DelegateBank whenever they want to

For an externally owned account (E)A) function call, it is similar to above, but in step 2 `ExecuteTransaction()` is called and step 4 becomes calling the external contract and passing in parameters rather than performing a token transfer.

## wToken to Token
![wToken to Token](/imgs/wTokenToToken.png)
1. Checking `BalanceOf()` signer to ensure that they have wToken
2. `withdrawTo()` is called from PayWithToken, the signer's wToken balance is deducted
3. Tokens ownership gets transferred from the wToken contract to DelegateBank
4. If this is a token transfer, then `send()` is called to transfer to the token recipient, else this is skipped
5. The fee is logged as a `deposit()` in the DelegateBank contract for the Delegator to reclaim whenever they want to.

## Notes on Implimentation
Reminder this was a proof of concept if we were to extend it some alternative architectural designs. An updated ERC20 would be the cleanest approach especially for dApps that natively want to have this behaviour with their own token.

## Potential Design Issues
1. Censorship resistance, how to ensure that users are not being censored by the delegators? There needs to be an entity or entities who are incentivized to delegate, whether by financial gain or on behalf of their community (for a particular dApp)
2. Discoverability of signed commitments, There needs to be an off-chain communication system between delegators and signers (similar to 0x).
3. High gas usage
4. Delegators ending up with large quantity of micro ERC-20 token balances, Delegators who frequently carry out transactions may need a way to immediately liquidate ERC-20 tokens paid as fees to ETH.

---

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

## Initial Submission
This was initially done at MakerDAO's and Wyre's [hackathon](https://www.eventbrite.com/e/unblock-the-hackathon-tickets-48209728596) in August 2018. With Leland Lee, Alan Lai (Blockchain at Berkeley) and Phillip Liu Jr. (JLab)
