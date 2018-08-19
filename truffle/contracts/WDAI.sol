pragma solidity ^0.4.23;

import "./ERC20.sol";

/** Goal
 * Create wDAI where the approvals are set to infinite for a predefined address
 * In this case the address would be DelegateBank
 * Modelled after WETH9 - https://etherscan.io/address/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2#code
**/

contract WDAI {
	string public name     = "Wrapped DAI";
	string public symbol   = "WDAI";
	uint8  public decimals = 18;

	event  Approval(address indexed src, address indexed guy, uint wad);
	event  Transfer(address indexed src, address indexed dst, uint wad);
	event  Deposit(address indexed dst, uint wad);
	event  Withdrawal(address indexed src, uint wad);

	address constant public DelegateBank = 0x0;
	ERC20 Token = ERC20(0xC4375B7De8af5a38a93548eb8453a498222C4fF2); // address of DAI on Kovan

	mapping (address => uint)                       public  balanceOf;
	mapping (address => mapping (address => uint))  public  allowance;

	function deposit(uint256 wad) public payable {
		balanceOf[msg.sender] += wad;
		Token.transferFrom(msg.sender, this, wad); // DAI transfered to this contract address
		emit Deposit(msg.sender, msg.value);
	}

	function withdraw(uint wad) public {
		require(balanceOf[msg.sender] >= wad);
		balanceOf[msg.sender] -= wad;
		Token.transferFrom(this, msg.sender, wad); // DAI transfered from this contract address to recipient
		emit Withdrawal(msg.sender, wad);
	}

	// Allows a whitelist contract to withdraw to a particular address
	function withdrawTo(address dst, uint wad) public {
		require(msg.sender == DelegateBank);

		require(balanceOf[dst] >= wad);
		balanceOf[dst] -= wad;
		Token.transferFrom(this, dst, wad); // DAI transfered from this contract address to recipient
		emit Withdrawal(dst, wad);
	}

	function totalSupply() public view returns (uint) {
		return address(this).balance;
	}

	function approve(address guy, uint wad) public returns (bool) {
		allowance[msg.sender][guy] = wad;
		emit Approval(msg.sender, guy, wad);
		return true;
	}

	function transfer(address dst, uint wad) public returns (bool) {
		return transferFrom(msg.sender, dst, wad);
	}

	function transferFrom(address src, address dst, uint wad) public returns (bool) {
		require(balanceOf[src] >= wad);

		// If the src is not DelegateBank, then traditional behaviour
		if (src != DelegateBank) {
			if (src != msg.sender && allowance[src][msg.sender] != uint(-1)) {
				require(allowance[src][msg.sender] >= wad);
				allowance[src][msg.sender] -= wad;
			}
		}

		balanceOf[src] -= wad;
		balanceOf[dst] += wad;

		emit Transfer(src, dst, wad);

		return true;
	}
}
