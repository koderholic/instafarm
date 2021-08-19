const InstaFarm = artifacts.require("InstaFarm.sol");
const ISTToken = artifacts.require("ISTToken.sol");

module.exports = async function (deployer) {
    await deployer.deploy(ISTToken);
    let ISTTokenInstance = await ISTToken.deployed()

    // Constructor params for InstaFarm contract
    const _rewardPerBlock = 100
    const _rewardTreasury = "0xeD99DB41eA5d5bEc188a1c76b44D672e521279Fb"
    const _istToken = ISTTokenInstance.address

    await deployer.deploy(InstaFarm, _rewardPerBlock, _rewardTreasury, _istToken);
};
