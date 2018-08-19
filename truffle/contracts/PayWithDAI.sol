pragma solidity ^0.4.23;

import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract WDAI {
  function withdrawTo(address signer, uint256 wad) public {}
  function balanceOf(address src) public returns(uint256) {}
}

contract PayWithDAI {
  event ValidSignature(bool validSignature);
  event SufficientFunds(bool sufficientBalance, bool sufficientAllowance);
  event ValidPayload(bool validPayload);
  event TransactionDelegationComplete(address feeRecipient, uint256 fee);

  address public constant DelegateBank = 0x0; // Incorrect address
  ERC20 token = ERC20(0xC4375B7De8af5a38a93548eb8453a498222C4fF2); // DAI address on Kovan
  WDAI wtoken = WDAI(0x0); // wDAI address --> how to add a new function to this...?

  mapping (bytes32 => bool) public signatures; // Prevent transaction replays

  function verifySignature(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s) private returns(bool) {
    require(signatures[hash] == false);

    bytes memory prefix = "\x19Ethereum Signed Message:\n32";
    bytes32 prefixedHash = keccak256(prefix, hash);
    bool validSignature = ecrecover(prefixedHash, v, r, s) == signer;
    emit ValidSignature(validSignature);

    return validSignature;
  }

  function verifyPayload(bytes32 hash, uint256 fee, uint256 gasLimit, uint256 executeBy, uint256 value, address executionAddress, bytes32 executionMessage) private returns(bool) {
    bool validPayload = keccak256(abi.encode(fee, gasLimit, executeBy, value, executionAddress, executionMessage)) == hash;
    emit ValidPayload(validPayload);

    return validPayload;
  }

  // Note this function is called after `verifySignature` --> signer is known be valid
  function verifyFunds(address signer, address feeRecipient, uint256 fee) private returns(bool) {
    bool sufficientBalance = token.balanceOf(signer) >= fee;
    bool sufficientAllowance = token.allowance(signer, feeRecipient) >= fee;
    emit SufficientFunds(sufficientBalance, sufficientAllowance);

    return sufficientBalance && sufficientAllowance;
  }

  function convertAllToDAI(address signer) public returns(bool) {
    uint256 wtokenBalance = wtoken.balanceOf(signer);
    bool hasWDAI = wtokenBalance > 0;
    if (hasWDAI) {
      wtoken.withdrawTo(signer, wtokenBalance);
      token.approve(DelegateBank, ~uint(0)); // Setting allowance
    }
    return true;
  }

  /**
   * @notice Submit a presigned smart contract transaction to execute
   * @param signer -> Address who's private key signed the hash
   * @param hash -> hash of `fee`, `gasLimit`, `executeBy`, `amount`, `recipient`
   * @param v ->
   * @param r ->
   * @param s ->
   * @param fee -> fee paid to Delegator
   * @param gasLimit -> gasLimit definied by the signer
   * @param executeBy -> blockheigh which the Delegator must execute the contract by
   * @param value -> value to be sent to the smart contract (payed by delegator)
   * @param executionAddress -> address of smart contract to call
   * @param executionMessage -> message to be passed to the smart contract
   * @param feeRecipient -> reciever of the fee
  **/
  function executeTransaction(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s, uint256 fee, uint256 gasLimit, uint256 executeBy, uint256 value, address executionAddress, bytes32 executionMessage, address feeRecipient) public returns(bool) {
    require(verifySignature(signer, hash, v, r, s));
    require(convertAllToDAI(signer));
    require(verifyPayload(hash, fee, gasLimit, executeBy, value, executionAddress, executionMessage));
    require(block.number < executeBy); // After payload verification, know executeBy value is correct
    require(verifyFunds(signer, DelegateBank, fee));

    // Note test to see if can send value(0) to non payable functions
    bool executed = executionAddress.call.value(value).gas(gasLimit)(executionMessage);

    // What is the difference between putting this into an `if` statement vs `require`
    if(executed) {
      token.transferFrom(signer, DelegateBank, fee); // transfer the tokens from signer -> DelegateBank
      require(DelegateBank.call(bytes4(keccak256("deposit(uint256, address)")), fee, feeRecipient)); // log the deposit into DelegateBank
      signatures[hash] = true;

      emit TransactionDelegationComplete(feeRecipient, fee);
    }
  }

  /**
   * @notice Submit a presigned ERC20 transfer
   * @param signer -> Address who signed the hash
   * @param hash -> hash of `fee`, `gasLimit`, `executeBy`, `amount`, `recipient`
   * @param v ->
   * @param r ->
   * @param s ->
   * @param fee -> fee paid to Delegator
   * @param gasLimit -> gasLimit definied by the signer
   * @param executeBy -> blockheigh which the Delegator must execute the contract by
   * @param amount -> amount of DAI to be sent
   * @param recipient -> recipient of the DAI
   * @param feeRecipient -> reciever of the fee
  **/
  // in 0x how is the `orderHash` verified? Would like to copy a similar model here so there is no need for massive constructors
  function executeTokenTransfer(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s, uint256 fee, uint256 gasLimit, uint256 executeBy, uint256 amount, address recipient, address feeRecipient) public returns(bool) {
    require(verifySignature(signer, hash, v, r, s));
    require(convertAllToDAI(signer));
    require(keccak256(abi.encodePacked(fee, gasLimit, executeBy, amount, recipient)) == hash); // Equivilant of verifyPayload
    require(block.number < executeBy);
    require(verifyFunds(signer, DelegateBank, fee + amount));

    // Add more error checking etc here
    require(token.transferFrom(msg.sender, DelegateBank, fee + amount)); // Tranfer all the tokens to bank
    require(DelegateBank.call(bytes4(keccak256("send(address, uint256)")), recipient, amount)); // Transfers tokens to final recipient
    require(DelegateBank.call(bytes4(keccak256("deposit(uint256, address)")), fee, feeRecipient)); // report fee deposit

    signatures[hash] = true;
  }

  // Need to think about transactions where one must call a function + send Ether at the same time
  // Is there a way to generalised `executeTokenTransfer` and `executeTransaction`?
  // Else there will be a third function --> `executeTransactionAndSendETH`
  // Probably can combine `executeTransaction` + `executeTransactionAndSendETH`

  // Also need to think about the case where one wants to interact with a DEX

  // function DAItoETH(address signer, uint256 wad) public returns(bool) {
  //   address DAIToken = 0xc4375b7de8af5a38a93548eb8453a498222c4ff2;
  //   // Need to set approval for the Proxy Contract to enable transfer + trading
  //   DAIToken.call(bytes4(0x095ea7b3), proxy_contract, ~uint(0));

  //   // Reference Oasis Direct for details
  // }
}
