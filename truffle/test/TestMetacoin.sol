pragma solidity ^0.4.2;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/DelegateBank.sol";

contract TestMetacoin {
  address account1 = 0xc08f2b1045d67ad5234b222153c121f4fd146423;
  function testInitialBalanceWithNewMetaCoin() public {
    DelegateBank meta = new DelegateBank();

    uint expected = 0;

    Assert.equal(meta.getBalance(tx.origin), expected, "Owner should have 0 token initially");
  }

  function testDeposit() public {
    DelegateBank bank = new DelegateBank();
    bank.deposit(1000, account1);
    uint expected = 1000;
    Assert.equal(bank.getBalance(account1), expected, "Owner should have 1000 Token after deposit");
  }

  function testDepositAndWithdraw() public {
    DelegateBank bank = new DelegateBank();
    bank.deposit(1000, account1);
    bank.withdraw(300, account1);
    uint expected = 700;
    Assert.equal(bank.getBalance(account1), expected, "Owner should have 700 Token after withdraw");
  }

  function testSend() public {
    DelegateBank bank = new DelegateBank();
    bank.deposit(1000, account1);
    bank.send(account1, 200);
  }

}
