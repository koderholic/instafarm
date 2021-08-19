const InstaFarm = artifacts.require("InstaFarm.sol");
const ISTToken = artifacts.require("ISTToken.sol");

contract("InstaFarm", async accounts => {

    it("Should increase user pool amount on deposit", async function () {
        let account1 = accounts[0]
        let account2 = accounts[1]
        
        const ISTTokenContract = await ISTToken.deployed()
        const InstaFarmContract = await InstaFarm.deployed()

        let _lp = ISTTokenContract.address
        let _poolRewardFactor = 10
        let _poolType = 0
        
        await InstaFarmContract.createPool(_lp, _poolRewardFactor, _poolType, {from : account1 })
        let allPools = await InstaFarmContract.getAllPools.call({from : account1 })
        let PID = allPools.length


        let initialAmount = await InstaFarmContract.getFarmerInfoPerPoolID.call(PID, account2, {from : account1 })

        // Approve IST contract over user
        let totalSupply = await ISTTokenContract.mint(account2, 2000000000, {from : account1 })
        await ISTTokenContract.approve(InstaFarmContract.address, 1000000000, {from : account2 })

        // Deposit
        await InstaFarmContract.deposit(PID, 20, {from : account2 })


        let stakeAmount = await InstaFarmContract.getFarmerInfoPerPoolID.call(PID, account2, {from : account1 })

        assert.isTrue(stakeAmount.amount > initialAmount.amount, "Deposit was not successful")
        
    });

});
