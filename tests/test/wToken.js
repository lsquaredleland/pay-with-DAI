require('truffle-test-utils').init();

var wTokenArtifact = artifacts.require("wToken");
var TestTokenArtifact = artifacts.require("TestToken");

var MockArtifact = artifacts.require("Mock");
var Utils = require('./Utils')(wTokenArtifact);

contract('wToken', async (accounts) => {

    it("should have a name and ticker that are proper", async () => {
        let instance = await wTokenArtifact.deployed();
        let retName = await instance.name();
        assert.equal(retName, "Wrapped Token", "Name on contract does not match expected value");
        let retSymbol = await instance.symbol();
        assert.equal(retSymbol, "wToken", "Symbol on contract does not match expected value");
    });

    it("should be able to deposit tokens", async () => {
        let instanceTestToken = await TestTokenArtifact.deployed();
        let supplyTestToken = await instanceTestToken.balanceOf(accounts[0])
        assert.equal(supplyTestToken.toString(), "12000", "Have TestTokens");


        let instance = await wTokenArtifact.new(instanceTestToken.address, "0x0");

        // Why is the below an address when it should be a function?
        let a = await instance.Token();

        let tokenSupply = await instance.Token.balanceOf(accounts[0]);
        assert.equal(tokenSupply.toString(), "12000", "Token supply should match actual")

        // let supply = await instance.totalSupply();
        // console.log("supply", supply.toString());
        // let wTokenBalance = await instance.balanceOf(accounts[0])
        // let tokenDeposit = await instance.deposit(10);

        // supply = await instance.totalSupply();
        // assert.equal(supply.toString(), "10", "Deposit should increase supply");
        // assert.equal(supply.toString(), "100", "Deposit should increase supply");

        // assert.web3Event(tokenDeposit, {
        //     'event': 'Deposit',
        //     'args': {
        //         'dst': accounts[1],
        //         'wad': 10,
        //     }
        // });
    })

});
