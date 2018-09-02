pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

/** Goal
 * Create wToken where the approvals are set to infinite for a predefined address
 * In this case the address would be DelegateBank
 * Modelled after WETH9 - https://etherscan.io/address/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2#code
**/

contract wToken {
	string public name     = "Wrapped Token";
	string public symbol   = "wToken";
	uint8  public decimals = 18;

	event  Approval(address indexed src, address indexed guy, uint wad);
	event  Transfer(address indexed src, address indexed dst, uint wad);
	event  Deposit(address indexed dst, uint wad);
	event  Withdrawal(address indexed src, uint wad);

	address public DelegateBank; // Is there a better pattern for whitelists?
	address public owner;

	ERC20 public Token;

	mapping (address => uint)                       public  balanceOf;
	mapping (address => mapping (address => uint))  public  allowance;

	constructor(address _token, address _DelegateBank) public {
    owner = msg.sender;
    Token = ERC20(_token);
    DelegateBank = _DelegateBank;
  }

	// Anyone can create wToken, but it the only usecase if for auto-whitelisting DelegateBank
	function deposit(uint256 _wad) public {
		require(Token.balanceOf(msg.sender) >= _wad);
		require(Token.transferFrom(msg.sender, this, _wad)); // DAI transfered to this contract address
		balanceOf[msg.sender] += _wad;
		emit Deposit(msg.sender, _wad);
	}

	function withdraw(uint _wad) public {
		require(balanceOf[msg.sender] >= _wad);
		require(Token.transferFrom(this, msg.sender, _wad)); // DAI transfered from this contract address to recipient
		balanceOf[msg.sender] -= _wad;
		emit Withdrawal(msg.sender, _wad);
	}

	// Allows a whitelist contract to withdraw to a particular address
	function withdrawTo(address _src, address _dst, uint _wad) public returns (bool) {
		require(msg.sender == DelegateBank);

		require(balanceOf[_src] >= _wad);
		balanceOf[_src] -= _wad;
		require(Token.transferFrom(this, _dst, _wad)); // DAI transfered from this contract address to recipient
		emit Withdrawal(_src, _wad);
		return true;
	}

	function totalSupply() public view returns (uint) {
		return Token.balanceOf(this);
	}

	function approve(address guy, uint _wad) public returns (bool) {
		allowance[msg.sender][guy] = _wad;
		emit Approval(msg.sender, guy, _wad);
		return true;
	}

	function transfer(address _dst, uint _wad) public returns (bool) {
		return transferFrom(msg.sender, _dst, _wad);
	}

	function transferFrom(address _src, address _dst, uint _wad) public returns (bool) {
		require(balanceOf[_src] >= _wad);

		// If the _src is not DelegateBank, then traditional behaviour
		if (_src != DelegateBank) {
			if (_src != msg.sender && allowance[_src][msg.sender] != uint(-1)) {
				require(allowance[_src][msg.sender] >= _wad);
				allowance[_src][msg.sender] -= _wad;
			}
		}

		balanceOf[_src] -= _wad;
		balanceOf[_dst] += _wad;

		emit Transfer(_src, _dst, _wad);

		return true;
	}
}
