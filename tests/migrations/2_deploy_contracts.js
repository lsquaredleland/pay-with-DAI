const DelegateBank = artifacts.require("./DelegateBank")
const TestToken = artifacts.require("./TestToken.sol")
const wToken = artifacts.require("./wToken.sol")
const PayWithToken = artifacts.require("./PayWithToken.sol")

module.exports = function(deployer) {
	var PayWithTokenInstance, DelegateBankInstance;

	deployer
		.deploy(TestToken)
		.then(() => {
		  return DelegateBank.new(TestToken.address);
		})
		.then((instance) => {
			DelegateBankInstance = instance;
		  return wToken.new(TestToken.address, DelegateBank.address);
		})
		.then(() => {
			return PayWithToken.new(TestToken.address, wToken.address, DelegateBank.address);
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
