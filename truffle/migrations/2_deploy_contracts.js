var DelegateBank = artifacts.require("./DelegateBank.sol");
var PayWithDAI= artifacts.require("./PayWithDAI.sol");

module.exports = function(deployer) {
  deployer.deploy(DelegateBank);
  deployer.link(DelegateBank, PayWithDAI);
  deployer.deploy(PayWithDAI);
};
