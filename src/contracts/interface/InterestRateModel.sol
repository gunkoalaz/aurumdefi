// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface InterestRateModel {

    function isInterestRateModel() external view returns(bool);
    function getBorrowRate(uint cash, uint borrows, uint reserves) external view returns (uint);
    
    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) external view returns (uint);

}