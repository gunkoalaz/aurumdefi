// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "./interface/StakingARMInterface.sol";

contract StakingARM is StakingARMInterface{

    //Owner address
    address owner;    

    //User variables
    mapping(address => uint256) stakingBalance;   //User's staked ARM token
    mapping(address => uint256) rewardBalanceOf;  //User's distributed reward from vault which 'NOT YET' claim
    mapping(address => bool) hasStaked; //this variable check if the user used to stake in the vault to prevent duplication of 'stakers[]'.
    mapping(address => bool) isStaking; //Staking status of individual address, FALSE if balance = 0
    address[] stakers; //Address of stakers for rewarding reason
    
    //Vault variables manipulation
    uint256 accRewardPerShare; // spending reward RATE per share :: calculate from TotalRewardRemaining / TotalStakingToken / rewardSpendingDuration
    uint256 rewardSpendingDuration; // Duration in days that the reward will be distributed
    // RewardSpendingDuration is the CONSTANT that indicate the RATE of the current reward will be distributed if no-one is updating the vault
    // Everytime that users stake/unstake/claimReward, the spending rate (accRewardPerShare) will be re-calculated
    uint256 lastRewardTimestamp; //Index of current updated rewardblock (blocktime)

    //This code is modified from Masterchef contract
        // Whenever a user stake or unstake to the vault.
        //   1. The 'rewardBalance' (and `lastRewardTimestamp`) gets updated.
        //   2. User receives the 'rewardBalanceOf' sent to his/her address. (rewardBalanceOf then set to 0)
        //   3. User's `stakingBalance` gets updated.
        //   4. User's `rewardBalanceOf` gets updated.


    IERC20 public armToken;     // ARM token  OR  LP-token to be staked
    IERC20 public rewardToken;  // BUSD token



    //Set object of ARM to armToken and object of BUSD to rewardToken when the contract is deployed.
    constructor(IERC20 importARMToken, IERC20 importRewardToken){
        armToken = importARMToken; // This can be LP token when deploying contract
        rewardToken = importRewardToken;
        owner = msg.sender;
        rewardSpendingDuration = 30 days; // set default is 30 days
        lastRewardTimestamp = block.timestamp;
        locked = false;
    }

    error TransferFail();

    event Stake(address _staker, uint _amount);
    event Unstake(address _unstaker, uint _amount);
    event ClaimReward(address _claimer, uint _amount);
    event EmergencyWithdraw(address _withdrawer, uint _amount);
    event SetRewardSpendingDuration(uint OldDuration, uint NewDuration);
    event SetNewOwner(address OldOwner, address NewOwner);

    modifier onlyOwner {
      require(msg.sender == owner);
      _;
    }

    bool internal locked;
    modifier reentrancyGuard {
        require(!locked);
        locked = true; // lock the re-entrancy before contract execution
        _;
        locked = false; // unlock when finish
    }

    //--------------------------------------
    //------Reading parameters function-----
    //--------------------------------------

    //Get the ARM staking for each requested address
    function manualGetStakingBalance(address _staker) view public returns(uint256) {
        return stakingBalance[_staker];
    }

    //Get the reward balance of each requested address (this included the pending update reward)
    function manualGetRewardBalance(address _staker) view public returns(uint256) {
      uint256 deltaTime = block.timestamp - lastRewardTimestamp;
        if(deltaTime > rewardSpendingDuration){
          deltaTime = rewardSpendingDuration;
        }
        uint256 pendingReward = deltaTime * accRewardPerShare * stakingBalance[_staker];
        uint256 totalReward = rewardBalanceOf[_staker] + pendingReward;
        return totalReward;
    }

    //Get the owner address
    function getOwner() view public returns(address){
        return owner;
    }
    function getAccRewardPerShare() view public returns(uint) {
        return accRewardPerShare;
    }
    function getLastRewardTimestamp() view public returns(uint){
        return lastRewardTimestamp;
    }
    function getStakingBalance(address user) view public returns(uint){
        return stakingBalance[user];
    }
    //Get the BUSD balance in vault
    function getVaultBalance() public view returns(uint256){
        return rewardToken.balanceOf(address(this));
    }
    //Get the ARM balance in vault
    function getTotalStakedARM() public view returns(uint256){
        return armToken.balanceOf(address(this));
    }
    //Get Total reward pending to be claim
    function getTotalRewardPending() internal view returns(uint256){
        address[] memory varsStaker = stakers;  //get stakers to local memory vars to minimalize gas spend in for loop
        uint256 numberUser = varsStaker.length;
        uint256 totalreward;
        for(uint i = 0; i< numberUser; i++){
          totalreward += rewardBalanceOf[varsStaker[i]];
        }
        return totalreward;
    }
    //Get remaining reward
    function getRewardRemaining() public view returns(uint256)  {
        return (getVaultBalance() - getTotalRewardPending());
    }
    //Reward spending duration return in blocktime
    function getRewardSpendingDuration() public view returns(uint256) {
      return rewardSpendingDuration;
    }

    function getRewardBalanceOf(address user) public view returns(uint256) {
      return rewardBalanceOf[user];
    }
    //-------------------------------------------------
    //--------------Action function--------------------
    //-------------------------------------------------


    function updateRewardBlock() internal{
        //If the lastRewardTimestamp is updated.  No need for update
        if(block.timestamp <= lastRewardTimestamp){
          return;
        }
        uint256 totalStakedARM = getTotalStakedARM(); //The ARM balance in vault contract
        
        //Check if this is the first staker then start the block reward here
        if(totalStakedARM == 0){
          lastRewardTimestamp = block.timestamp;
          return;
        }
        uint256 remainingReward = getRewardRemaining();
        
        //Check if rewardPool is empty
        if(remainingReward == 0){
          return;
        }

        //Check if the reward block not update for long time (more than the rewardSpendingDuration)
        //then deltaTime to be calculate should be equal to MAX (rewardSpendingDuration)
        uint256 deltaTime = block.timestamp - lastRewardTimestamp;
        if(deltaTime > rewardSpendingDuration){
          deltaTime = rewardSpendingDuration;
        }
        uint i;
        uint gainReward;
        address[] memory varsStaker = stakers;  // gas optimization
        for (i=0 ; i< varsStaker.length ; i++){
          //gainReward is  1e18 :: e18*e18*uint / 1e18
          gainReward = stakingBalance[varsStaker[i]] * accRewardPerShare * deltaTime / 1e18;
          rewardBalanceOf[varsStaker[i]] += gainReward;
        }
        lastRewardTimestamp = block.timestamp;
    }

    function manualUpdateRewardBlock() external reentrancyGuard{
        updateRewardBlock();
    }
    

    function stakeARM(uint _amount) external reentrancyGuard {
        //Check the amount and balance of staker
        require(_amount > 0, "Staking amount must greater than zero");
        require(armToken.balanceOf(msg.sender)>=_amount, "Not enough ARM token to be deposited.");
        //1. update the reward vault to get lastRewardTimestamp
        //2. claim the pending reward
        //3. stake the ARM token
        //4. update accRewardPerShare = totalRemainingBalance / totalStakingBalance / rewardSpendingDuration

        updateRewardBlock();
        bool success;
        if(rewardBalanceOf[msg.sender]>0){
          uint256 toBePaid = rewardBalanceOf[msg.sender];
          rewardBalanceOf[msg.sender]=0;
          success = rewardToken.transfer(msg.sender, toBePaid);
          if(!success){
              revert TransferFail();
          }
          emit ClaimReward(msg.sender, toBePaid);
        }

        //Transfer ARM to contract address then update balance
        success = armToken.transferFrom(msg.sender,address(this),_amount);
        if(!success){
            revert TransferFail();
        }
        stakingBalance[msg.sender] += _amount;

        //add staker address to the arrays for rewarding reasons
        if(!hasStaked[msg.sender]){
            stakers.push(msg.sender);
            hasStaked[msg.sender] = true;
        }
        //Currently staking
        isStaking[msg.sender] = true;

        //Update accRewardPerShare
        uint256 totalRemainingBalance = getRewardRemaining();
        uint256 totalStakingBalance = getTotalStakedARM();
        // newAccRewardPerShare is 1e18 :: e18 * 1e18 / e18 / uint
        uint256 newAccRewardPerShare = (totalRemainingBalance * 1e18 / totalStakingBalance) / rewardSpendingDuration;
        accRewardPerShare = newAccRewardPerShare;

        emit Stake(msg.sender, _amount);
    }




    function manualClaimReward() external reentrancyGuard{
        updateRewardBlock();
        require(getRewardRemaining() >= rewardBalanceOf[msg.sender],"Not enough reward in pool.");
        if(rewardBalanceOf[msg.sender]>0){
          uint256 toBePaid = rewardBalanceOf[msg.sender];
          rewardBalanceOf[msg.sender]=0;    //set balance to 0 before transfer to double prevent reentrancy guard
          bool success = rewardToken.transfer(msg.sender, toBePaid);
          if(!success){
              revert TransferFail();
          }
          emit ClaimReward(msg.sender, toBePaid);
        }
    }




    function unstakeARM(uint _amount) external reentrancyGuard{
        //Check the amount and balancer of unstaker
        require(_amount > 0, "Unstaking amount must greater than zero");
        require(stakingBalance[msg.sender] >= _amount, "Not enough ARM token to be withdrawed.");
        //1. update the reward vault to get lastRewardTimestamp
        //2. claim the pending reward
        //3. unstake the ARM token
        //4. update accRewardPerShare = totalRemainingBalance / totalStakingBalance / rewardSpendingDuration

        updateRewardBlock();
        bool success;
        if(rewardBalanceOf[msg.sender]>0){
          success = rewardToken.transfer(msg.sender, rewardBalanceOf[msg.sender]);
          if(!success){
              revert TransferFail();
          }
          emit ClaimReward(msg.sender, rewardBalanceOf[msg.sender]);
          rewardBalanceOf[msg.sender]=0;
        }

        //Transfer ARM to unstaker
        success = armToken.transfer(msg.sender,_amount);
        //calculate balance after transfer
        stakingBalance[msg.sender] -= _amount;
        if(stakingBalance[msg.sender]==0){
            isStaking[msg.sender] = false;
        }

        //Update accRewardPerShare
        uint256 totalRemainingBalance = getRewardRemaining();
        uint256 totalStakingBalance = getTotalStakedARM();
        //if totalStakiingBalance = 0 --> no ARM in vault = no reward then  accRewardPerShare = 0
        if(totalStakingBalance==0) {
          accRewardPerShare = 0;
        } else {
          // accRewardPerShare is 1e18 :: e18 * 1e18 / e18 / uint
          accRewardPerShare = (totalRemainingBalance * 1e18 /totalStakingBalance) / rewardSpendingDuration;
        }

        emit Unstake(msg.sender,_amount);
    }

    //Set reward duration  only Owner can access
    function _setRewardDurationSpending (uint hour) external onlyOwner {
        updateRewardBlock();  //update distribute reward before
        uint OldDuration = rewardSpendingDuration;
        uint NewDuration = hour * 60 * 60; // Input in 'hour', Stored in Seconds
        rewardSpendingDuration = NewDuration; 

        accRewardPerShare = (getRewardRemaining() * 1e18 / getTotalStakedARM()) / NewDuration; // update the distribution RATE
        emit SetRewardSpendingDuration(OldDuration, NewDuration);
    }

    //Set new admin
    function _transferOwnership (address newOwner) external onlyOwner {
        address oldOwner = owner;
        owner = newOwner;

        emit SetNewOwner(oldOwner, newOwner);
    }


    //Withdraw ARM token without caring reward
    function emergencyWithdraw() external reentrancyGuard {
        armToken.transfer(msg.sender,stakingBalance[msg.sender]);
        emit EmergencyWithdraw(msg.sender, stakingBalance[msg.sender]);
        isStaking[msg.sender] = false;
        rewardBalanceOf[msg.sender] = 0;
        stakingBalance[msg.sender] = 0;
    }
}