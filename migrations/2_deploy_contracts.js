const DelegateBank = artifacts.require("./DelegateBank")
const TestToken = artifacts.require("./TestToken.sol")
const wToken = artifacts.require("./wToken.sol")
const PayWithToken = artifacts.require("./PayWithToken.sol")

module.exports = function(deployer) {
	var PayWithTokenInstance, DelegateBankInstance;

	deployer
		.deploy(TestToken)
		.then(() => {
		  return deployer.deploy(DelegateBank, TestToken.address);
		})
		.then((instance) => {
			DelegateBankInstance = instance;
		  return deployer.deploy(wToken, TestToken.address, DelegateBank.address);
		})
		.then(() => {
			return deployer.deploy(PayWithToken, TestToken.address, wToken.address, DelegateBank.address);
		})
		.then((instance) => {
			PayWithTokenInstance = instance;
			return DelegateBankInstance.setParent(PayWithTokenInstance.address);
		})

	// deployer.deploy([
	//   [TestToken],
	//   [DelegateBank, TestToken.address],
	//   [wToken, TestToken.address, DelegateBank.address],
	//   [PayWithToken, TestToken.address, wToken.address, DelegateBank.address]
	// ]);
};
