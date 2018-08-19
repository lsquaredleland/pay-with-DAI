pragma solidity ^0.4.23;

import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract PayWithDAI {
  event ValidSignature(bool validSignature);
  event SufficientFunds(bool sufficientBalance, bool sufficientAllowance);
  event ValidPayload(bool validPayload);
  event TransactionDelegationComplete(address feeRecipient, uint256 fee);

  address public constant DelegateBank = 0x0; // Incorrect address
  ERC20 token = ERC20(0xC4375B7De8af5a38a93548eb8453a498222C4fF2); // DAI address on Kovan

  mapping (bytes32 => bool) public signatures; // Prevent transaction replays

  function verifySignature(address initiator, bytes32 hash, uint8 v, bytes32 r, bytes32 s) private returns(bool) {
    require(signatures[hash] == false);

    bool validSignature = ecrecover(hash, v, r, s) == initiator;
    emit ValidSignature(validSignature);

    return validSignature;
  }

  function verifyPayload(bytes32 hash, uint256 fee, uint256 gasLimit, uint256 executeBy, address executionAddress, bytes32 executionMessage) private returns(bool) {
    bool validPayload = keccak256(abi.encode(fee, gasLimit, executeBy, executionAddress, executionMessage)) == hash;
    emit ValidPayload(validPayload);

    return validPayload;
  }

  // Note this function is called after `verifySignature` --> initiator is known be valid
  function verifyFunds(address initiator, address feeRecipient, uint256 fee) private returns(bool) {
    bool sufficientBalance = token.balanceOf(initiator) >= fee;
    bool sufficientAllowance = token.allowance(initiator, feeRecipient) >= fee;
    emit SufficientFunds(sufficientBalance, sufficientAllowance);

    return sufficientBalance && sufficientAllowance;
  }

  /**
   * @notice Submit a presigned smart contract transaction to execute
   * @param initiator -> Address who's private key signed the hash
   * @param hash -> hash of `fee`, `gasLimit`, `executeBy`, `amount`, `recipient`
   * @param v ->
   * @param r ->
   * @param s ->
   * @param fee -> fee paid to Delegator
   * @param gasLimit -> gasLimit definied by the initiator
   * @param executeBy -> blockheigh which the Delegator must execute the contract by
   * @param executionAddress -> address of smart contract to call
   * @param executionMessage -> message to be passed to the smart contract
   * @param feeRecipient -> reciever of the fee
  **/
  function executeTransaction(address initiator, bytes32 hash, uint8 v, bytes32 r, bytes32 s, uint256 fee, uint256 gasLimit, uint256 executeBy, address executionAddress, bytes32 executionMessage, address feeRecipient) public returns(bool) {
    require(verifySignature(initiator, hash, v, r, s));
    require(verifyPayload(hash, fee, gasLimit, executeBy, executionAddress, executionMessage));
    require(block.number < executeBy); // After payload verification, know executeBy value is correct
    require(verifyFunds(initiator, DelegateBank, fee));

    bool executed = executionAddress.call.gas(gasLimit)(executionMessage);

    // What is the difference between putting this into an `if` statement vs `require`
    if(executed) {
      token.transferFrom(initiator, DelegateBank, fee); // transfer the tokens from initiator -> DelegateBank
      require(DelegateBank.call(bytes4(keccak256("deposit(uint256, address)")), fee, feeRecipient)); // log the deposit into DelegateBank
      signatures[hash] = true;

      emit TransactionDelegationComplete(feeRecipient, fee);
    }
  }

  /**
   * @notice Submit a presigned ERC20 transfer
   * @param initiator -> Address who signed the hash
   * @param hash -> hash of `fee`, `gasLimit`, `executeBy`, `amount`, `recipient`
   * @param v ->
   * @param r ->
   * @param s ->
   * @param fee -> fee paid to Delegator
   * @param gasLimit -> gasLimit definied by the initiator
   * @param executeBy -> blockheigh which the Delegator must execute the contract by
   * @param amount -> amount of DAI to be sent
   * @param recipient -> recipient of the DAI
   * @param feeRecipient -> reciever of the fee
  **/
  function executeTokenTransfer(address initiator, bytes32 hash, uint8 v, bytes32 r, bytes32 s, uint256 fee, uint256 gasLimit, uint256 executeBy, uint256 amount, address recipient, address feeRecipient) public returns(bool) {
    require(verifySignature(initiator, hash, v, r, s));
    require(keccak256(abi.encodePacked(fee, gasLimit, executeBy, amount, recipient)) == hash); // Equivilant of verifyPayload
    require(block.number < executeBy);
    require(verifyFunds(initiator, DelegateBank, fee + amount));

    // Add more error checking etc here
    require(token.transferFrom(msg.sender, DelegateBank, fee + amount)); // Tranfer all the tokens to bank
    require(DelegateBank.call(bytes4(keccak256("send(address, uint256)")), recipient, amount)); // Transfers tokens to final recipient
    require(DelegateBank.call(bytes4(keccak256("deposit(uint256, address)")), fee, feeRecipient)); // report fee deposit

    signatures[hash] = true;
  }
}
