pragma solidity ^0.4.23;

import "github.com/OpenZeppelin/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract PayWithDAI {
	event ValidSignature(bool validSignature);
	event SufficientFunds(bool sufficientBalance, bool sufficientAllowance);
	event ValidPayload(bool validPayload);

	address private constant DAIAddress = 0xC4375B7De8af5a38a93548eb8453a498222C4fF2;

	mapping (bytes32 => bool) public signatures;

	function verifySignature(address initiator, bytes32 hash, uint8 v, bytes32 r, bytes32 s) private returns(bool) {
        bool validSignature = ecrecover(hash, v, r, s) == initiator;
        emit ValidSignature(validSignature);

        return validSignature;
    }

    function verifyPayload(bytes32 hash, uint256 fee, uint256 gasLimit, address executionAddress, bytes32 executionMessage) private returns(bool) {
        bool validPayload = keccak256(abi.encodePacked(fee, gasLimit, executionAddress, executionMessage)) == hash;
        emit ValidPayload(validPayload);

        return validPayload;
    }

    // Note this function is called after `verifySignature` --> initiator is known be valid
    function verifyFunds(address initiator, address feeRecipient, uint256 fee) private returns(bool) {
        ERC20 dai = ERC20(DAIAddress);
        bool sufficientBalance = dai.balanceOf(initiator) >= fee;

        // Is there a way to avoid checking allowance...ex: signing a special type of message?
        // Could set feeRecipient to a smart contract that delegators can withdraw from later...
        bool sufficientAllowance = dai.allowance(initiator, feeRecipient) >= fee;
        emit SufficientFunds(sufficientBalance, sufficientAllowance);

        return sufficientBalance && sufficientAllowance;
    }

    function executeTransaction(address initiator, bytes32 hash, uint8 v, bytes32 r, bytes32 s, uint256 fee, uint256 gasLimit, address executionAddress, bytes32 executionMessage, address feeRecipient) public constant returns(bool) {
        require(signatures[hash] == false); // no replays allowed
        require(verifySignature(initiator, hash, v, r, s));
        require(verifyPayload(hash, fee, gasLimit, executionAddress, executionMessage));
        require(verifyFunds(initiator, feeRecipient, fee));

        address newAddress = executionAddress;
        bool executed = newAddress.call.gas(gasLimit)(executionMessage);

        if(executed) {
            ERC20 token = ERC20(DAIAddress);
            token.transferFrom(msg.sender, feeRecipient, fee); // transfer the tokens
            signatures[hash] = true;
        }
    }
}

