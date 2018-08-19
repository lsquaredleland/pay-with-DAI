pragma solidity ^0.4.23;

import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract DelegateBank {

	ERC20 token = ERC20(0xC4375B7De8af5a38a93548eb8453a498222C4fF2); // DAI address on Kovan
	address PayWithDAI;
	address owner;
	bool setable;

	mapping (address => uint256) public balances; // Sum of balances == token.balance[this]

	constructor() public {
    owner = msg.sender;
  }

  function setParent(address parent) public returns(bool) {
  	require(msg.sender == owner);
  	PayWithDAI = parent;
  }

	// Withdraw is called by Delegators
	function withdraw(uint256 amount, address feeRecipient) public returns(bool) {
		require(balances[msg.sender] >= amount);
		balances[feeRecipient] -= amount;
    token.transferFrom(this, feeRecipient, amount);
    return true;
	}

	// A deposit function is required as the smart contract is unable to determine which address deposited tokens (DAI) into it.
	function deposit(uint256 amount, address feeRecipient) public returns(bool) {
		balances[feeRecipient] += amount;
		return true;
	}

	// Only `PayWithDAI` contract can call this function
	function send(address recipient, uint256 amount) public returns(bool) {
		require(msg.sender == PayWithDAI);
		token.transferFrom(this, recipient, amount);
		return true;
	}
}
