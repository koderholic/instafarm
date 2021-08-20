// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ISTToken.sol";

contract InstaFarm is Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Start block
    uint256 public startBlock;
    ISTToken public platformToken;
    address public rewardVault;

    // Total token to be distributed across pools per block
    uint256 public totalDistRewardPerBlock;
    // Total rewardFactor across pools
    uint256 public totalRewardFactorPerBlock = 0;

    enum PoolType { LP, Token}
    PoolType PoolTypes;

    // Pool user details
    struct Farmer {
        uint256 amount;     // How many LP tokens or just tokens the user has provided.
        uint256 rewardDue; // Reward yet to be claimed by user
        uint256 rewardEarned; // Total reward earned by user so far in a pool
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 rewardFactor;       // How many allocation points assigned to this pool. ISTs to distribute per block.
        uint256 poolRewardPerUnitStake;
        uint256 totalRewardEarned;
        uint256 lastRewardBlock;  // Last block number that IST distribution occurs.
        PoolType poolType;
    }

    // pool id to address to user info
    mapping(uint256 => mapping(address => Farmer)) poolToFarmers;
    // Pool lp to pool id
    mapping(address => uint256) internal poolID;

    PoolInfo[] internal allPools;


    // Events
    event NewPool(uint256 indexed __pid, address __poolOwner, PoolType indexed __poolType);
    event PoolUpdate(uint256 indexed __pid, address indexed __poolOwner, uint256 __prevPoolFactor, uint256 __newPoolFactor);
    event PoolDeposit(uint256 indexed __pid, address indexed __farmer, uint256 __amount, uint256 __newTotal);
    event PoolWithdrawal(uint256 indexed __pid, address indexed __farmer, uint256 __amount, uint256 __newTotal);
    event ClaimReward(uint256 indexed __pid, address indexed __farmer, uint256 __amount);

    constructor (uint256 _rewardPerBlock, address _rewardTreasury, address _istToken ) {
        startBlock  = block.number;
        platformToken = ISTToken(_istToken);
        totalDistRewardPerBlock = _rewardPerBlock;
        rewardVault = _rewardTreasury;
    }

    // Create new poolID
    // Only owner can create a new pool
    // Ensures pool does not already exist
    function createPool(address _lp, uint256 _poolRewardFactor, PoolType _poolType ) public onlyOwner {
        require(poolID[_lp] == 0, "InstaFarm : Pool already exist");

        uint256 lastRewardBlock = (startBlock > block.number)? startBlock : block.number;
        allPools.push(
            PoolInfo({
        lpToken: ERC20(_lp),
        rewardFactor: _poolRewardFactor,
        poolType: _poolType,
        lastRewardBlock : lastRewardBlock,
        poolRewardPerUnitStake : 0,
        totalRewardEarned : 0
        })
        );
        uint PID = allPools.length;
        poolID[_lp] = PID;
        totalRewardFactorPerBlock = totalRewardFactorPerBlock.add(_poolRewardFactor);
        // Emit pool creation
        emit NewPool(poolID[_lp], msg.sender, _poolType);
    }

    // Update pool
    // Only onwner can update a pool
    // Ensure pool exist
    // Only pool's rewardFactor can be updated
    function updatePool(uint256 _PID, uint256 _poolRewardFactor) public onlyOwner {
        _PID = _PID.sub(1);
        PoolInfo storage pool = allPools[_PID];

        require(address(pool.lpToken) != address(0), "InstaFarm : Pool does not exist");

        uint256 __prevPoolFactor = pool.rewardFactor;
        totalRewardFactorPerBlock = totalRewardFactorPerBlock.sub(pool.rewardFactor).add(_poolRewardFactor);

        pool.rewardFactor = _poolRewardFactor;
        // Emit pool update
        emit PoolUpdate(_PID, msg.sender,__prevPoolFactor, _poolRewardFactor);
    }

    // Deposit to pool
    // Ensure pool exist
    // If it's the first time user is depositing, create farmer account , else update it
    // When user deposit to pool, update pool and user details
    function deposit(uint256 _PID, uint256 _amount) public {
        if (_amount <= 0) {
            return;
        }
        _PID = _PID.sub(1);
        PoolInfo storage pool = allPools[_PID];
        require(address(pool.lpToken) != address(0), "Pool not found, ensure pool exist!");

        Farmer storage farmer = poolToFarmers[_PID][msg.sender];

        pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
        __computePoolReward(_PID);

        //increase user and pool staking
        farmer.amount = farmer.amount.add(_amount);
        farmer.rewardEarned = farmer.rewardEarned.add(farmer.amount.mul(pool.poolRewardPerUnitStake));
        farmer.rewardDue = farmer.rewardDue.add(farmer.amount.mul(pool.poolRewardPerUnitStake));

        // Emit pool Deposit
        emit PoolDeposit(_PID, msg.sender, _amount, farmer.amount);
    }


    function __computePoolReward(uint256 _PID) internal {
        PoolInfo storage pool = allPools[_PID];

        if (pool.lastRewardBlock >= block.number) {
            return;
        }

        uint256 pendingBlockReward = block.number.sub(pool.lastRewardBlock);

        uint256 poolRewardForDist = totalDistRewardPerBlock.mul(pendingBlockReward).mul(pool.rewardFactor).div(totalRewardFactorPerBlock);
        uint256 totalStakedInPool = pool.lpToken.balanceOf(address(this));
        uint256 poolRewardPerUnitStake = poolRewardForDist.div(totalStakedInPool);

        pool.lastRewardBlock = block.number;
        pool.poolRewardPerUnitStake = pool.poolRewardPerUnitStake.add(poolRewardPerUnitStake);
        pool.totalRewardEarned = pool.totalRewardEarned.add(poolRewardForDist);
    }


    // Withdraw from pool
    // Ensure farmer has balance above withdrawal amount
    function withdraw(uint256 _PID, uint256 _amount) public {
        if (_amount <= 0) {
            return;
        }

        _PID = _PID.sub(1);
        PoolInfo storage pool = allPools[_PID];
        require(address(pool.lpToken) != address(0), "Pool not found, ensure pool exist!");

        Farmer storage farmer = poolToFarmers[_PID][msg.sender];
        if (farmer.amount < _amount) {
            return;
        }

        // Calculate pool and user reward up until current block; inclusing user pending reward or rewarddue
        __computePoolReward(_PID);
        farmer.rewardEarned = farmer.rewardEarned.add(farmer.amount.mul(pool.poolRewardPerUnitStake));
        farmer.rewardDue = farmer.rewardDue.add(farmer.amount.mul(pool.poolRewardPerUnitStake));

        // reduce user and pool staking
        farmer.amount = farmer.amount.sub(_amount);
        pool.lpToken.safeTransfer(msg.sender, _amount);

        if (farmer.amount <= 0 ) {
            platformToken.transferFrom(rewardVault, msg.sender, farmer.rewardDue);
            farmer.rewardDue = 0;
            farmer.rewardEarned = 0;
        }

        // Emit pool update
        emit PoolWithdrawal(_PID, msg.sender, _amount, farmer.amount);
    }


    // Claim reward
    function claimReward(uint256 _PID) public {
        _PID = _PID.sub(1);
        PoolInfo storage pool = allPools[_PID];
        require(address(pool.lpToken) != address(0), "Pool not found, ensure pool exist!");

        Farmer storage farmer = poolToFarmers[_PID][msg.sender];

        __computePoolReward(_PID);

        //reduce user and pool staking
        farmer.rewardEarned = farmer.rewardEarned.add(farmer.amount.mul(pool.poolRewardPerUnitStake));
        farmer.rewardDue = farmer.rewardDue.add(farmer.amount.mul(pool.poolRewardPerUnitStake));

        platformToken.transferFrom(address(rewardVault), msg.sender, farmer.rewardDue);
        farmer.rewardDue = 0;

        // Emit claim reward
        emit ClaimReward(_PID, msg.sender, farmer.rewardDue);
    }

    function updateTotalDistReward(uint256 _amount) public onlyOwner {
        totalDistRewardPerBlock = _amount;
    }

    // Get poolID
    function getPoolID(address _poolLP) public view returns(uint256) {
        return poolID[_poolLP];
    }

    function getPoolInfo(uint256 _PID) public view returns(PoolInfo memory) {
        _PID = _PID.sub(1);
        return allPools[_PID];
        // return pool.lpToken, pool.rewardFactor, pool.poolRewardPerUnitStake, pool.totalRewardEarned, pool.lastRewardBlock, pool.poolType;
    }


    function getFarmerInfoPerPoolID(uint256 _PID, address _farmer) public view returns(Farmer memory) {
        _PID = _PID.sub(1);
        Farmer memory farmerInfo = poolToFarmers[_PID][_farmer];

        PoolInfo storage pool = allPools[_PID];
        if (pool.lastRewardBlock >= block.number) {
            return farmerInfo;
        }

        uint256 pendingBlockReward = block.number.sub(pool.lastRewardBlock);

        uint256 poolRewardForDist = totalDistRewardPerBlock.mul(pendingBlockReward).mul(pool.rewardFactor).div(totalRewardFactorPerBlock);
        uint256 totalStakedInPool = pool.lpToken.balanceOf(address(this));
        uint256 poolRewardPerUnitStake = poolRewardForDist.div(totalStakedInPool);

        farmerInfo.rewardEarned = farmerInfo.rewardEarned.add(farmerInfo.amount.mul(poolRewardPerUnitStake));
        farmerInfo.rewardDue = farmerInfo.rewardDue.add(farmerInfo.amount.mul(poolRewardPerUnitStake));

        return farmerInfo;
    }


    // Get pool number
    function getTotalPoolSize() public view returns(uint256) {
        return allPools.length;
    }


    // Get all pools
    function getAllPools() public view returns(PoolInfo[] memory) {
        return allPools;
    }

    // Get total staked in pool
    function totalPoolStake(uint256 _PID) public view returns(uint256) {
        _PID = _PID.sub(1);
        PoolInfo storage pool = allPools[_PID];
        return pool.lpToken.balanceOf(address(this));
    }

}
