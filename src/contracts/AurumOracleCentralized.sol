// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './interface/ComptrollerInterface.sol';

contract AurumOracleCentralized is PriceOracle {
    //Using TWAP model, using index for looping and re-write the price storage
    address admin;
    struct PriceList {
        uint128[24] avgPrice;
        uint128[24] timestamp;
        uint8 currentIndex;
    }
    
    mapping (address => PriceList) asset;
    PriceList goldPrice; // gold price TWAP

    function isPriceOracle() external pure returns (bool) {return true;}


    address WREI; // Wrapped REI address


    constructor (address WREI_) {
        admin = msg.sender;
        WREI = WREI_;  // WREI will prevent crash when query the 'lendREI' token
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "Only admin");
        _;
    }

    event Initialized_Asset(address token, uint128 price, uint128 timestamp);
    event Initialized_Gold(uint128 price, uint128 timestamp);

    // Initialized Asset before updateAssetPrice, make sure that lastPrice not equal to 0, and Timestamp not equal to 0.
    function initializedAsset(address token, uint128 price) external onlyAdmin{
        uint8 i;
        uint128 currentTime = uint128(block.timestamp);
        for(i=0;i<24;i++){
            asset[token].avgPrice[i] = price;
            asset[token].timestamp[i] = currentTime;
        }
        asset[token].currentIndex = 0;
        emit Initialized_Asset(token, price, currentTime);
    }
    function initializedGold(uint128 price) external onlyAdmin{
        uint8 i;
        uint128 currentTime = uint128(block.timestamp);
        for(i=0;i<24;i++){
            goldPrice.avgPrice[i] = price;
            goldPrice.timestamp[i] = currentTime;
        }
        goldPrice.currentIndex = 0;
        emit Initialized_Gold(price, currentTime);
    }


    // Update price with the TWAP model.
    function updateAssetPrice(address token, uint128 price) external onlyAdmin{
        uint8 index = asset[token].currentIndex;
        uint8 lastIndex;
        uint8 nextIndex;
        if(index == 0){
            lastIndex = 23;
        } else {
            lastIndex = index-1;
        }
        uint lastPrice = asset[token].avgPrice[lastIndex];

        if(index == 23){
            nextIndex = 0;
        } else {
            nextIndex = index+1;
        }
        //oldDeltaTime is the time 0 - time K
        //newDeltaTime is the time n - time K
        uint oldDeltaTime = asset[token].timestamp[nextIndex]-asset[token].timestamp[lastIndex]; // This need to be initialized prevent underflow
        uint newDeltaTime = block.timestamp - asset[token].timestamp[lastIndex];

        //new AvgPrice is ( price*tk  +  price*tn  ) / tk+tn
        uint newAvgPrice = ((oldDeltaTime*lastPrice) + (newDeltaTime*price)) / (newDeltaTime+oldDeltaTime);

        if(newAvgPrice > type(uint128).max){
            revert("Overflow");
        }
        asset[token].avgPrice[index] = uint128(newAvgPrice);
        asset[token].timestamp[index];

        //Set new index to the next;
        asset[token].currentIndex = nextIndex;
    }

    function updateGoldPrice(uint128 price) external onlyAdmin {
        uint8 index = goldPrice.currentIndex;
        uint8 lastIndex;
        uint8 nextIndex;
        if(index == 0){
            lastIndex = 23;
        } else {
            lastIndex = index-1;
        }
        uint lastPrice = goldPrice.avgPrice[lastIndex];

        if(index == 23){
            nextIndex = 0;
        } else {
            nextIndex = index+1;
        }
        //oldDeltaTime is the time 0 - time K
        //newDeltaTime is the time n - time K
        uint oldDeltaTime = goldPrice.timestamp[nextIndex]-goldPrice.timestamp[lastIndex]; // This need to be initialized prevent underflow
        uint newDeltaTime = block.timestamp - goldPrice.timestamp[lastIndex];

        //new AvgPrice is ( price*tk  +  price*tn  ) / tk+tn
        uint newAvgPrice = ((oldDeltaTime*lastPrice) + (newDeltaTime*price)) / (newDeltaTime+oldDeltaTime);

        if(newAvgPrice > type(uint128).max){
            revert("Overflow");
        }
        goldPrice.avgPrice[index] = uint128(newAvgPrice);
        goldPrice.timestamp[index];

        //Set new index to the next;
        goldPrice.currentIndex = nextIndex;
    }

    function getGoldPrice() external view returns (uint){
        uint8 index = goldPrice.currentIndex;
        uint8 lastIndex;
        if(index == 0){
            lastIndex = 23;
        } else {
            lastIndex = index-1;
        }
        return uint(goldPrice.avgPrice[lastIndex]);
    }
    function getUnderlyingPrice(LendTokenInterface lendToken) external view returns (uint){
        address underlying;
        if(compareStrings(lendToken.symbol(), "lendREI")){
            underlying = WREI;
        } else {
            underlying = lendToken.underlying();
        }

        //same as  assetPrices function
        uint8 index = asset[underlying].currentIndex;
        uint8 lastIndex;
        if(index == 0){
            lastIndex = 23;
        } else {
            lastIndex = index-1;
        }
        return uint(asset[underlying].avgPrice[lastIndex]);
    }
    //The latest price is where the lastIndex is.
    function assetPrices(address token) external view returns (uint){
        uint8 index = asset[token].currentIndex;
        uint8 lastIndex;
        if(index == 0){
            lastIndex = 23;
        } else {
            lastIndex = index-1;
        }
        return uint(asset[token].avgPrice[lastIndex]);
    }
    
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

}