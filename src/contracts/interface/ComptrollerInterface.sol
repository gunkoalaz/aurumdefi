// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './interestRateModel.sol';

interface ComptrollerInterface {
    function isComptroller() external pure returns(bool);
    function isProtocolPaused() external view returns(bool);
    function getMintedGOLDs(address) external view returns(uint);
    function getComptrollerOracleAddress() external view returns(address);
    function getGoldMintRate() external view returns (uint);
    /*** Assets You Are In ***/

    function getAssetsIn(address) external view returns(LendTokenInterface[] memory);
    function exitMarket(address lendToken) external;

    /*** Policy Hooks ***/

    function mintAllowed(address lendToken, address minter) external;
    function redeemAllowed(address lendToken, address redeemer, uint redeemTokens) external;
    function borrowAllowed(address lendToken, address borrower, uint borrowAmount) external;
    function repayBorrowAllowed(address lendToken, address borrower) external;
    function liquidateBorrowAllowed(address lendTokenBorrowed, address lendTokenCollateral, address borrower, uint repayAmount) external;
    function seizeAllowed(address lendTokenCollateral, address lendTokenBorrowed, address liquidator, address borrower) external;
    function transferAllowed(address lendToken, address src, address dst, uint transferTokens) external;

    /*** Liquidity/Liquidation Calculations ***/

    function liquidateCalculateSeizeTokens(
        address lendTokenBorrowed,
        address lendTokenCollateral,
        uint repayAmount) external view returns (uint);
    function setMintedGOLDOf(address owner, uint amount) external;


    function liquidateGOLDCalculateSeizeTokens(
        address lendTokenCollateral,
        uint repayAmount) external view returns (uint);
}

interface IComptroller {
    function liquidationIncentiveMantissa() external view returns (uint);
    /*** Treasury Data ***/
    function treasuryAddress() external view returns (address);
    function treasuryPercent() external view returns (uint);
}

interface LendTokenInterface{

    function comptroller() external view returns(ComptrollerInterface);
    function totalSupply() external view returns(uint);
    function totalBorrows() external view returns(uint);
    function borrowIndex() external view returns(uint);
    function symbol() external view returns(string memory);
    function underlying() external view returns(address);
    function isLendToken() external pure returns(bool);
    function accrualTimestamp() external view returns(uint);
    
    function getAccountBorrows(address user) external view returns(uint, uint);
    function getBorrowAddress() external view returns(address[] memory);
    
    function transfer(address dst, uint256 amount) external;
    function transferFrom(address src, address dst, uint256 amount) external;
    function approve(address spender, uint256 amount) external;
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256); 
    function balanceOfUnderlying(address owner) external returns (uint);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint); 
    function borrowBalanceStored(address account) external view returns (uint);
    function exchangeRateStored() external view returns (uint);
    function getCash() external view returns (uint);
    function accrueInterest() external;
    function borrowRatePerSeconds() external view returns (uint);
    function supplyRatePerSeconds() external view returns (uint); 
    function exchangeRateCurrent() external returns (uint);


    function mint(uint mintAmount) external returns(uint);
    function redeem(uint redeemTokens) external;
    function redeemUnderlying(uint redeemAmount) external;
    function borrow(uint borrowAmount) external;
    function repayBorrow(uint repayAmount) external returns (uint);
    function liquidateBorrow(address borrower, uint repayAmount, LendTokenInterface lendTokenCollateral) external returns (uint);
    function seize(address liquidator, address borrower, uint seizeTokens) external;

    /*** Admin Functions ***/

}

interface PriceOracle {
    function isPriceOracle() external view returns (bool);
    function getGoldPrice() external view returns (uint);
    function getUnderlyingPrice(LendTokenInterface lendToken) external view returns (uint);
    function assetPrices(address asset) external view returns (uint);
}

interface AurumControllerInterface {

    function getGoldMinter() external view returns(address[] memory);
    function mintGOLD(uint mintGOLDAmount) external;
    function repayGOLD(uint repayGOLDAmount) external returns(uint);
    function liquidateGOLD(address borrower, uint repayAmount, LendTokenInterface lendTokenCollateral) external returns(uint);
    function getMintableGOLD(address minter) external view returns (uint);

}