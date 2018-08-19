pragma solidity ^0.4.23;

import "./ERC20.sol";

contract DelegateBank {

	ERC20 token = ERC20(0xC4375B7De8af5a38a93548eb8453a498222C4fF2);

	mapping (address => uint256) public balances;

	function withdraw(uint256 amount) public returns(bool) {
		require(balances[msg.sender] >= amount);
		balances[msg.sender] -= amount;
    token.transferFrom(this, msg.sender, amount);
    return true;
	}

	// A deposit function is required as the smart contract is unable to determine
	// which address deposited tokens (DAI) into it.
	function deposit(uint256 amount) public returns(bool) {
		balances[msg.sender] += amount;
		return true;
	}

	function send(address recipient, uint256 amount) public returns(bool) {
		token.transferFrom(this, recipient, amount);
		return true;
	}
}
