pragma solidity ^0.4.23;

import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

// An ERC20 Bank
contract DelegateBank {

	ERC20 token = ERC20(0xC4375B7De8af5a38a93548eb8453a498222C4fF2); // DAI address on Kovan
	address public PayWithDAI;
	address public owner;

	mapping (address => uint256) public balances; // Sum of balances == token.balance[this]

	constructor() public {
    owner = msg.sender;
  }

  function setParent(address _parent) public returns(bool) {
  	require(msg.sender == owner);
  	PayWithDAI = _parent;
  }

	// Withdraw is called by Delegators
	function withdraw(uint256 _amount, address _feeRecipient) public returns(bool) {
		require(balances[msg.sender] >= _amount);
		balances[_feeRecipient] -= _amount;
    token.transferFrom(this, _feeRecipient, _amount);
    return true;
	}

	// A deposit function is required as the smart contract is unable to determine which address deposited tokens (DAI) into it.
	function deposit(uint256 _amount, address _feeRecipient) public returns(bool) {
		require(msg.sender == PayWithDAI); // Don't want random contracts to deposit tokens here
		balances[_feeRecipient] += _amount;
		return true;
	}

	// Only `PayWithDAI` contract can call this function
	function send(address recipient, uint256 _amount) public returns(bool) {
		require(msg.sender == PayWithDAI);
		token.transferFrom(this, recipient, _amount);
		return true;
	}
}
