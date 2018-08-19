pragma solidity ^0.4.23;

import "./ERC20.sol";
import "./DelegateBank.sol";
contract PayWithDAI {
  event ValidSignature(bool validSignature);
  event SufficientFunds(bool sufficientBalance, bool sufficientAllowance);
  event ValidPayload(bool validPayload);
  event DelegationComplete(bool signature, address feeRecipient, uint256 fee);

  // feeRecipient can be set to DelegateBank
  // Currently this is not set as a default. Thus delegators need to check that they have been given allowances
  // Though in practice the ability to be given an alloance is very low
  address public constant DelegateBank = 0xC4375B7De8af5a38a93548eb8453a498222C4fF2; // Incorrect address
  address private constant DAIAddress = 0xC4375B7De8af5a38a93548eb8453a498222C4fF2;

  ERC20 token = ERC20(DAIAddress);

  mapping (bytes32 => bool) public signatures; // Prevent transaction replays

  function verifySignature(address initiator, bytes32 hash, uint8 v, bytes32 r, bytes32 s) private returns(bool) {
    bool validSignature = ecrecover(hash, v, r, s) == initiator;
    emit ValidSignature(validSignature);

    return validSignature;
  }

  function verifyPayload(bytes32 hash, uint256 fee, uint256 gasLimit, uint256 executeBy, address executionAddress, bytes32 executionMessage) private returns(bool) {
    bool validPayload = keccak256(abi.encodePacked(fee, gasLimit, executeBy, executionAddress, executionMessage)) == hash;
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

  function settle(bytes32 hash, address feeRecipient, uint256 fee) private returns (bool) {
    token.transferFrom(msg.sender, feeRecipient, fee); // transfer the tokens

    if (feeRecipient == DelegateBank) {
      require(DelegateBank.call(bytes4(keccak256("deposit(uint256)")), fee)); // log the deposit into DelegateBank
    }
    signatures[hash] = true;

    emit DelegationComplete(signatures[hash], feeRecipient, fee);

    return true;
  }

  // Delegators must use DelegateBank
  function executeTransaction(address initiator, bytes32 hash, uint8 v, bytes32 r, bytes32 s, uint256 fee, uint256 gasLimit, uint256 executeBy, address executionAddress, bytes32 executionMessage, address feeRecipient) public returns(bool) {
    require(signatures[hash] == false);
    require(verifySignature(initiator, hash, v, r, s));
    require(verifyPayload(hash, fee, gasLimit, executeBy, executionAddress, executionMessage));
    require(block.number < executeBy); // After payload verification, know executeBy value is correct
    require(verifyFunds(initiator, DelegateBank, fee));

    bool executed = executionAddress.call.gas(gasLimit)(executionMessage);

    if(executed) {
      settle(hash, feeRecipient, fee);
    }
  }

  // Delegators must use the DelegateBank
  function executeTokenTransfer(address initiator, bytes32 hash, uint8 v, bytes32 r, bytes32 s, uint256 fee, uint256 gasLimit, uint256 executeBy, uint256 amount, address recipient, address feeRecipient) public returns(bool) {
    require(signatures[hash] == false);
    require(verifySignature(initiator, hash, v, r, s));
    require(keccak256(abi.encodePacked(fee, gasLimit, executeBy, amount, recipient)) == hash); // Equivilant of verifyPlayload
    require(block.number < executeBy);
    require(verifyFunds(initiator, DelegateBank, fee + amount));

    // Add more error checking etc here
    token.transferFrom(msg.sender, feeRecipient, fee + amount); // Tranfer all the tokens to bank
    require(DelegateBank.call(bytes4(keccak256("send(address, uint256)")), recipient, amount)); // Transfers tokens to final recipient
    require(DelegateBank.call(bytes4(keccak256("deposit(uint256)")), fee)); // report fee deposit

    signatures[hash] = true;
  }
}
