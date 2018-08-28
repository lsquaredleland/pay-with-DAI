pragma solidity ^0.4.23;

import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

// The interface
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
  WDAI wtoken = WDAI(0x0); // wDAI address

  mapping (bytes32 => bool) public signatures; // Prevent transaction replays

  function verifySignature(address _signer, bytes32 _hash, uint8 _v, bytes32 _r, bytes32 _s) private returns(bool) {
    require(signatures[_hash] == false);

    bytes memory prefix = "\x19Ethereum Signed Message:\n32";
    bytes32 prefixedHash = keccak256(prefix, _hash);
    bool validSignature = ecrecover(prefixedHash, _v, _r, _s) == _signer;
    emit ValidSignature(validSignature);

    return validSignature;
  }

  function verifyPayload(bytes32 _hash, uint256 _fee, uint256 _gasLimit, uint256 _expiration, uint256 _value, address _executionAddress, bytes32 _executionMessage, uint256 _nonce) private returns(bool) {
    bool validPayload = keccak256(abi.encode(_fee, _gasLimit, _expiration, _value, _executionAddress, _executionMessage, _nonce)) == hash;
    emit ValidPayload(validPayload);

    return validPayload;
  }

  function verifyTokenTransferPayload(bytes32 _hash, uint256 _fee, uint256 _gasLimit, uint256 _expiration, uint256 _amount, address _recipient, uint256 _nonce) private returns(bool) {
    bool validPayload = keccak256(abi.encodePacked(_fee, _gasLimit, _expiration, _amount, _recipient, _nonce)) == hash;
    emit ValidPayload(validPayload);

    return validPayload;
  }

  // Note this function is called after `verifySignature` --> signer is known be valid
  function verifyFunds(address _signer, address _feeRecipient, uint256 _fee) private returns(bool) {
    bool sufficientBalance = wtoken.balanceOf(_signer) >= _fee;
    bool sufficientAllowance = wtoken.allowance(_signer, _feeRecipient) >= _fee;
    emit SufficientFunds(sufficientBalance, sufficientAllowance);

    return sufficientBalance && sufficientAllowance;
  }

  /**
   * @notice Submit a presigned smart contract transaction to execute
   * @param signer -> Address who's private key signed the hash
   * @param hash -> hash of `fee`, `gasLimit`, `expiration`, `amount`, `recipient`
   * @param v ->
   * @param r ->
   * @param s ->
   * @param fee -> fee paid to Delegator
   * @param gasLimit -> gasLimit definied by the signer
   * @param expiration -> blockheigh which the Delegator must execute the contract by
   * @param value -> value to be sent to the smart contract (payed by delegator)
   * @param executionAddress -> address of smart contract to call
   * @param executionMessage -> message to be passed to the smart contract
   * @param feeRecipient -> reciever of the fee
  **/
  function executeTransaction(address _signer, bytes32 _hash, uint8 _v, bytes32 _r, bytes32 _s, uint256 _fee, uint256 _gasLimit, uint256 _expiration, uint256 _value, address _executionAddress, bytes32 _executionMessage, address _feeRecipient, uint256 _nonce) public returns(bool) {
    require(verifySignature(_signer, _hash, _v, _r, _s));
    require(verifyPayload(_hash, _fee, _gasLimit, _expiration, _value, _executionAddress, _executionMessage, _nonce));
    require(block.number < _expiration); // After payload _verification, know expiration value is correct
    require(verifyFunds(_signer, _DelegateBank, _fee));

    // Note test to see if can send value(0) to non payable functions
    bool executed = executionAddress.call.value(_value).gas(_gasLimit)(_executionMessage);

    // What is the difference between putting this into an `if` statement vs `require`
    if(executed) {
      require(wtoken.withdrawTo(_signer, _DelegateBank, _fee));
      require(DelegateBank.call(bytes4(keccak256("deposit(uint256, address)")), _fee, _feeRecipient)); // log the deposit into DelegateBank
      signatures[_hash] = true;

      emit TransactionDelegationComplete(_feeRecipient, _fee);
    }
  }

  /**
   * @notice Submit a presigned ERC20 transfer
   * @param signer -> Address who signed the hash
   * @param hash -> hash of `fee`, `gasLimit`, `expiration`, `amount`, `recipient`
   * @param v ->
   * @param r ->
   * @param s ->
   * @param fee -> fee paid to Delegator
   * @param gasLimit -> gasLimit definied by the signer
   * @param expiration -> blockheigh which the Delegator must execute the contract by
   * @param amount -> amount of DAI to be sent
   * @param recipient -> recipient of the DAI
   * @param feeRecipient -> reciever of the fee
  **/
  // in 0x how is the `orderHash` verified? Would like to copy a similar model here so there is no need for massive constructors
  function executeTokenTransfer(address _signer, bytes32 _hash, uint8 _v, bytes32 _r, bytes32 _s, uint256 _fee, uint256 _gasLimit, uint256 _expiration, uint256 _amount, address _recipient, address _feeRecipient, uint256 _nonce) public returns(bool) {
    require(verifySignature(_signer, _hash, _v, _r, _s));
    require(verifyTokenTransferPayload(fee, _gasLimit, _expiration, _amount, _recipient, _nonce));
    require(block.number < _expiration);
    require(verifyFunds(_signer, _DelegateBank, _fee + _amount));

    // Add more error checking etc here
    require(wtoken.withdrawTo(_signer, _DelegateBank, _fee + _amount)); // Tranfer all the tokens to bank
    require(DelegateBank.call(bytes4(keccak256("send(address, uint256)")), _recipient, _amount)); // Transfers tokens to final recipient
    require(DelegateBank.call(bytes4(keccak256("deposit(uint256, address)")), _fee, _feeRecipient)); // report fee deposit

    signatures[_hash] = true;
  }
}
