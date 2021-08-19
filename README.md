# instafarm
This is a yield farming project on Ethereum

This project does the following :
* Creates an ERC20 token that acts as a platform token (IST : InstaFarm Token)
* Creates a pool contract where users can deposit tokens/LPs to get rewards (InstaFarm Contract)
* The platform supports multiple pools (Tokens, LPs)
* Uses SushiSwap MasterChef contract as a reference

How To Use :
There are two nways to use the platform, as a regular user or as a developer

Crypto User :
On InstaFarm you can stake your IST or any supported LP tokens to earn more IST tokens.

Steps :
* Ensure you have metamask chrome extension istalled, if you don't, you can read this article on how to install metamask on Chrome :
* Ensure your metamask is on Ropsten network; See how to change network on metamask here :
Go to the frontend dapp at https://instafarm.netlify.app
Connect your metamask wallet to the site.
* If you already have some tokens / LP staked, you would see the total amount you have staked and the amount of IST you have earned as reward per pool
* You can stake your token or LP on any of the pool listed by clicking on the stake button, enter the amount to stake, approve the platform over your token or LP, sign the transaction via metamask and stake!
* You can withdraw any or all amount of your stake out of the platform, by clicking on UnStake, enter the amount you want to unstaked, sign the transaction via metamask and UnStake!
* You can claim your IST reward earned on your stake, by clicking on the Claim Reward button and sign the transaction via metamask

Note :
The platform currently only supports the platform token staking (IST) and ETH-DIA LP Token on Ropsten

Developer User :
As a developer, you can extend the InstaFarm functionality, build on top of it or help us make it better by creating identifying bugs and creating issues on this repo

Steps :
* Ensure you have NodeJs, truffle and Ganache-cli installed
* Clone the repo locally
* Run the test, by running the truffle test command `truffle test`
* See how it works and interact with it via truffle console by running 'truffle migrate' and `truffle console` from the truffle console you can interact with the deployed instance of thw contract
* See the truffle commands here :  for more ways to interact with the contract via truffle
* Enjoy!

Deployment :
The contract is currently deployed on Ethereum Testnet ~ Ropsten
Contract address : 