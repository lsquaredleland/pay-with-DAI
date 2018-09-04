pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./wToken.sol";

// Assume only individials using wrapped tokens are using this.

contract PayWithToken {
  event ValidSignature(bool validSignature);
  event SufficientFunds(bool sufficientBalance);
  event ValidPayload(bool validPayload);
  event TransactionDelegationComplete(address feeRecipient, uint256 fee);

  address public DelegateBank;
  ERC20 token;
  wToken wtoken;

  mapping (bytes32 => bool) public signatures; // Prevent transaction replays

  constructor(address _token, address _wToken, address _delegateBankAddress) public {
    token = ERC20(_token);
    wtoken = wToken(_wToken);
    DelegateBank = _delegateBankAddress;
  }

  function verifySignature(address _signer, bytes32 _hash, uint8 _v, bytes32 _r, bytes32 _s) private returns (bool) {
    require(signatures[_hash] == false);

    bytes memory prefix = "\x19Ethereum Signed Message:\n32";
    bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, _hash));
    bool validSignature = ecrecover(prefixedHash, _v, _r, _s) == _signer;
    emit ValidSignature(validSignature);

    return validSignature;
  }

  function verifyPayload(bytes32 _hash, uint256 _fee, uint256 _gasLimit, uint256 _expiration, uint256 _value, address _executionAddress, bytes32 _executionMessage, uint256 _nonce) private returns (bool) {
    bool validPayload = keccak256(abi.encode(_fee, _gasLimit, _expiration, _value, _executionAddress, _executionMessage, _nonce)) == _hash;
    emit ValidPayload(validPayload);

    return validPayload;
  }

  function verifyTokenTransferPayload(bytes32 _hash, uint256 _fee, uint256 _gasLimit, uint256 _expiration, uint256 _amount, address _recipient, uint256 _nonce) private returns (bool) {
    bool validPayload = keccak256(abi.encodePacked(_fee, _gasLimit, _expiration, _amount, _recipient, _nonce)) == _hash;
    emit ValidPayload(validPayload);

    return validPayload;
  }

  // Note this function is called after `verifySignature` --> signer is known be valid
  function verifyFunds(address _signer, uint256 _fundsRequired) private returns (bool) {
    // no need to check allowance as it's already set ot infinite
    bool sufficientBalance = wtoken.balanceOf(_signer) >= _fundsRequired;
    emit SufficientFunds(sufficientBalance);

    return sufficientBalance;
  }

  /**
   * @notice Submit a presigned smart contract transaction to execute
   * @param _signer -> Address who's private key signed the hash
   * @param _hash -> hash of `fee`, `gasLimit`, `expiration`, `amount`, `recipient`
   * @param _v ->
   * @param _r ->
   * @param _s ->
   * @param _fee -> fee paid to Delegator
   * @param _gasLimit -> gasLimit definied by the signer
   * @param _expiration -> blockheigh which the Delegator must execute the contract by
   * @param _value -> value to be sent to the smart contract (payed by delegator)
   * @param _executionAddress -> address of smart contract to call
   * @param _executionMessage -> message to be passed to the smart contract
   * @param _feeRecipient -> reciever of the fee
  **/
  function executeTransaction(address _signer,
    bytes32 _hash,
    uint8 _v,
    bytes32 _r,
    bytes32 _s,
    uint256 _fee,
    uint256 _gasLimit,
    uint256 _expiration,
    uint256 _value,
    address _executionAddress,
    bytes32 _executionMessage,
    address _feeRecipient,
    uint256 _nonce
  ) public returns (bool) {
    // Note order of the reuqires does not matter as they will all be called before execution
    require(verifySignature(_signer, _hash, _v, _r, _s));
    require(verifyPayload(_hash, _fee, _gasLimit, _expiration, _value, _executionAddress, _executionMessage, _nonce));
    require(block.number < _expiration);
    require(verifyFunds(_signer, _fee));

    // Note test to see if can send value(0) to non payable functions
    require(_executionAddress.call.value(_value).gas(_gasLimit)(_executionMessage));

    // What is the difference between putting this into an `if` statement vs `require`
    //Instead of withdrawing the wToken to DAI, could just keep everything as wToken if it uses less gas....
    require(wtoken.withdrawTo(_signer, DelegateBank, _fee));
    require(DelegateBank.call(bytes4(keccak256("deposit(uint256, address)")), _fee, _feeRecipient)); // log the deposit into DelegateBank
    signatures[_hash] = true;

    emit TransactionDelegationComplete(_feeRecipient, _fee);
    return true;
  }

  /**
   * @notice Submit a presigned ERC20 transfer
   * @param _signer -> Address who signed the hash
   * @param _hash -> hash of `fee`, `gasLimit`, `expiration`, `amount`, `recipient`
   * @param _v ->
   * @param _r ->
   * @param _s ->
   * @param _fee -> fee paid to Delegator
   * @param _gasLimit -> gasLimit definied by the signer
   * @param _expiration -> blockheigh which the Delegator must execute the contract by
   * @param _amount -> amount of DAI to be sent
   * @param _recipient -> recipient of the DAI
   * @param _feeRecipient -> reciever of the fee
  **/
  // in 0x how is the `orderHash` verified? Would like to copy a similar model here so there is no need for massive constructors
  function executeTokenTransfer(
    address _signer,
    bytes32 _hash,
    uint8 _v,
    bytes32 _r,
    bytes32 _s,
    uint256 _fee,
    uint256 _gasLimit,
    uint256 _expiration,
    uint256 _amount,
    address _recipient,
    address _feeRecipient,
    uint256 _nonce
  ) public returns (bool) {
    require(verifySignature(_signer, _hash, _v, _r, _s));
    require(verifyTokenTransferPayload(_hash, _fee, _gasLimit, _expiration, _amount, _recipient, _nonce));
    require(block.number < _expiration);
    require(verifyFunds(_signer, _fee + _amount));

    // Add more error checking etc here
    require(wtoken.withdrawTo(_signer, DelegateBank, _fee + _amount)); // Tranfer all the tokens to bank
    require(DelegateBank.call(bytes4(keccak256("send(address, uint256)")), _recipient, _amount)); // Transfers tokens to final recipient
    require(DelegateBank.call(bytes4(keccak256("deposit(uint256, address)")), _fee, _feeRecipient)); // report fee deposit

    signatures[_hash] = true;

    emit TransactionDelegationComplete(_feeRecipient, _fee);
    return true;
  }
}
