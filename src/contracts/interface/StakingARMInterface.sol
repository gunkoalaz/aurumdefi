// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface StakingARMInterface {

    function manualGetStakingBalance(address _staker) view external returns(uint256);
    function manualGetRewardBalance(address _staker) view external returns(uint256);
    function getOwner() view external returns(address);
    function getAccRewardPerShare() view external returns(uint);
    function getLastRewardTimestamp() view external returns(uint);
    function getStakingBalance(address user) view external returns(uint);
    function getVaultBalance() external view returns(uint256);
    function getTotalStakedARM() external view returns(uint256);
    function getRewardRemaining() external view returns(uint256);
    function getRewardSpendingDuration() external view returns(uint256);
    function getRewardBalanceOf(address user) external view returns(uint256);

    //-------------------------------------------------
    //--------------Action function--------------------
    //-------------------------------------------------

    function manualUpdateRewardBlock() external;
    function stakeARM(uint _amount) external;
    function manualClaimReward() external;
    function unstakeARM(uint _amount) external;

    function emergencyWithdraw() external;
}