// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './interface/InterestRateModel.sol';

contract AurumInterestRateModel is InterestRateModel{
    function isInterestRateModel() external pure returns(bool) {
        return true;
    }
    uint baseRate;
    uint plateauRange;
    uint maxRate;
    uint trigger;
    uint peakMax;
    constructor (uint _baseRate, uint _maxRate, uint _trigger, uint _peakMax){
        baseRate = _baseRate;
        maxRate = _maxRate;
        trigger = _trigger;
        peakMax = _peakMax;
    }
    function utility(uint cash, uint borrows, uint reserves) external pure returns (uint) {
        if (cash + borrows - reserves == 0){
            return 0;
        }
        //total investor deposit = remaining cash - reserves + borrowed amount
        uint util = borrows * 1e18 / (cash + borrows - reserves);
        return util;
    }

    function getBorrowRate(uint cash, uint borrows, uint reserves) external view returns (uint){
        uint util = this.utility(cash,borrows,reserves);
        uint borrowRatePerYear;
        if (util > trigger) {
            //Rate beyond maxRate
            borrowRatePerYear = maxRate + ((util - trigger) * (peakMax - maxRate) / (1e18 - trigger)); //e18
        } else {
            borrowRatePerYear = baseRate + ((maxRate - baseRate) * util / trigger);  //e18
        }
        return borrowRatePerYear / 365 / 60 / 60 / 24; //borrowRatePerSeconds
    }
    
    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) external view returns (uint){
        uint borrowRate = this.getBorrowRate(cash, borrows, reserves);
        //supplyRate = profit / total investor deposit * feeMultiplier
        uint totalProfit = borrowRate * borrows / 1e18; // e18
        uint totalInvestorDeposit = cash + borrows - reserves;  //e18
        uint reducedFeeMultiplier = 1e18 - reserveFactorMantissa; //e18

        if(totalInvestorDeposit != 0) {
            return totalProfit * reducedFeeMultiplier / totalInvestorDeposit;
        }
        else {
            return 0;
        }
    }
}