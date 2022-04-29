// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import './ComptrollerInterface.sol';
import "./ISlidingWindow.sol";

interface IAurumOracleCentralized is PriceOracle {
    
    function isPriceOracle() external pure returns (bool);

    function initializedAsset(address token, uint128 price) external;
    function initializedGold(uint128 price) external;
    function updateAssetPrice(address token, uint128 price) external;
    function updateAssetPriceFromWindow(address token) external;
    function updateGoldPrice(uint128 price) external;
    function getGoldPrice() external view returns (uint);
    function getUnderlyingPrice(LendTokenInterface lendToken) external view returns (uint);
    function assetPrices(address token) external view returns (uint);

}