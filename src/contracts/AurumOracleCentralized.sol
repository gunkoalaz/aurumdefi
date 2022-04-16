// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './interface/IAurumOracleCentralized.sol';

contract AurumOracleCentralized is IAurumOracleCentralized {
    //Using TWAP model, using index for looping and re-write the price storage

    address public admin; // Admin can initiate price and set manager (reducing risk of privatekey leak)   Admin private key store in Hardware wallet.
    address public manager; // Manager can update the price, using Multi-signature wallet address to reduce risk of single key leak.
    
    address busd; //Reference stable coin price.

    struct PriceList {
        uint128[6] avgPrice;
        uint128[6] timestamp;
        uint8 currentIndex;
    }
    
    mapping (address => PriceList) asset;
    PriceList goldPrice; // gold price TWAP

    ISlidingWindow public slidingWindow;

    // Period range will trigger the alarm when someone got the admin private key and try to manipulate prices
    // 
    uint public periodRange = 60*50; // 50 minutes

    function isPriceOracle() external pure returns (bool) {return true;}


    address WREI; // Wrapped REI address


    constructor (address WREI_, address busd_) {
        admin = msg.sender;
        busd = busd_;
        WREI = WREI_;  // WREI will prevent crash when query the 'lendREI' token
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "Only admin");
        _;
    }
    modifier onlyManager {
        require(msg.sender == manager, "Only manager");
        _;
    }

    event Initialized_Asset(address token, uint128 price, uint128 timestamp);
    event Initialized_Gold(uint128 price, uint128 timestamp);
    event SetNewAdmin(address oldAdmin, address newAdmin);
    event SetNewManager(address oldManager, address newManager);
    event SetNewSlidingWindow(address oldSlidingWindow, address newSlidingWindow);

    // Initialized Asset before updateAssetPrice, make sure that lastPrice not equal to 0, and Timestamp not equal to 0.
    function initializedAsset(address token, uint128 price) external onlyAdmin{
        uint8 i;
        uint128 currentTime = uint128(block.timestamp);
        for(i=0;i<6;i++){
            asset[token].avgPrice[i] = price;
            asset[token].timestamp[i] = currentTime;
        }
        asset[token].currentIndex = 0;
        emit Initialized_Asset(token, price, currentTime);
    }
    function initializedGold(uint128 price) external onlyAdmin{
        uint8 i;
        uint128 currentTime = uint128(block.timestamp);
        for(i=0;i<6;i++){
            goldPrice.avgPrice[i] = price;
            goldPrice.timestamp[i] = currentTime;
        }
        goldPrice.currentIndex = 0;
        emit Initialized_Gold(price, currentTime);
    }


    // Update price with the TWAP model.
    function updateAssetPrice(address token, uint128 price) external onlyManager{
        uint8 index = asset[token].currentIndex;
        uint8 lastIndex;
        uint8 nextIndex;
        if(index == 0){
            lastIndex = 5;
        } else {
            lastIndex = index-1;
        }
        uint lastPrice = asset[token].avgPrice[lastIndex];

        if(index == 5){
            nextIndex = 0;
        } else {
            nextIndex = index+1;
        }
        //newDeltaTime is the time n - time K  // it must more than period time
        //oldDeltaTime is the time K - time 0
        uint newDeltaTime = block.timestamp - asset[token].timestamp[lastIndex];
        require(newDeltaTime >= periodRange, "update too early");   //If update oracle bot catch this means the privatekey got hacked OR the bot error.
        uint oldDeltaTime = asset[token].timestamp[lastIndex]-asset[token].timestamp[nextIndex]; // This need to be initialized

        //new AvgPrice is ( price*tk  +  price*tn  ) / tk+tn
        uint newAvgPrice = ((oldDeltaTime*lastPrice) + (newDeltaTime*price)) / (newDeltaTime+oldDeltaTime);

        if(newAvgPrice > type(uint128).max){
            revert("Overflow");
        }
        asset[token].avgPrice[index] = uint128(newAvgPrice);
        asset[token].timestamp[index] = uint128(block.timestamp);

        //Set new index to the next;
        asset[token].currentIndex = nextIndex;
    }

    // This using sliding window oracle of Uniswap V2 data to update this oracle.
    function updateAssetPriceFromWindow(address token) external onlyManager{
        uint8 index = asset[token].currentIndex;
        uint8 lastIndex;
        uint8 nextIndex;
        ISlidingWindow uniswapOracle = ISlidingWindow(slidingWindow);
        if(index == 0){
            lastIndex = 5;
        } else {
            lastIndex = index-1;
        }

        if(index == 5){
            nextIndex = 0;
        } else {
            nextIndex = index+1;
        }
        // So.. We helping sliding Window update each time we read parameter.
        uniswapOracle.update(token,busd);

        uint newDeltaTime = block.timestamp - asset[token].timestamp[lastIndex];
        require(newDeltaTime >= periodRange, "update too early");   //If update oracle bot catch this means the privatekey got hacked OR the bot error.

        // The price we got already time-weight average price.
        uint newAvgPrice = uniswapOracle.consult(token,1e18,busd);

        if(newAvgPrice > type(uint128).max){
            revert("Overflow");
        }
        asset[token].avgPrice[index] = uint128(newAvgPrice);
        asset[token].timestamp[index] = uint128(block.timestamp);

        //Set new index to the next;
        asset[token].currentIndex = nextIndex;
    }



    function updateGoldPrice(uint128 price) external onlyManager {
        uint8 index = goldPrice.currentIndex;
        uint8 lastIndex;
        uint8 nextIndex;
        if(index == 0){
            lastIndex = 5;
        } else {
            lastIndex = index-1;
        }
        uint lastPrice = goldPrice.avgPrice[lastIndex];

        if(index == 5){
            nextIndex = 0;
        } else {
            nextIndex = index+1;
        }
        //newDeltaTime is the time n - time K
        //oldDeltaTime is the time K - time 0
        uint newDeltaTime = block.timestamp - goldPrice.timestamp[lastIndex];
        require(newDeltaTime >= periodRange, "update too early");   //If update oracle bot catch this means the privatekey got hacked OR the bot error.
        uint oldDeltaTime = goldPrice.timestamp[lastIndex]-goldPrice.timestamp[nextIndex]; // This need to be initialized

        //new AvgPrice is ( price*tk  +  price*tn  ) / tk+tn
        uint newAvgPrice = ((oldDeltaTime*lastPrice) + (newDeltaTime*price)) / (newDeltaTime+oldDeltaTime);

        if(newAvgPrice > type(uint128).max){
            revert("Overflow");
        }

        //Prevent overvalue / undervalue algorithm, Max change = 10%
        if(lastPrice > newAvgPrice) {
            //new price is less than previous price
            uint dif = lastPrice - newAvgPrice;
            if(dif > lastPrice/10){
                newAvgPrice = lastPrice * 9 / 10;
            }
        } else {
            //new price is greater than previous price
            uint dif = newAvgPrice - lastPrice;
            if(dif > lastPrice/10){
                newAvgPrice = lastPrice * 11 / 10;
            }
        }

        goldPrice.avgPrice[index] = uint128(newAvgPrice);
        goldPrice.timestamp[index] = uint128(block.timestamp);

        //Set new index to the next;
        goldPrice.currentIndex = nextIndex;
    }

    function getGoldPrice() external view returns (uint){
        uint8 index = goldPrice.currentIndex;
        uint8 lastIndex;
        if(index == 0){
            lastIndex = 5;
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
            lastIndex = 5;
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
            lastIndex = 5;
        } else {
            lastIndex = index-1;
        }

        
        return uint(asset[token].avgPrice[lastIndex]);
    }
    
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function _setAdmin (address newAdmin) external onlyAdmin {
        address oldAdmin = admin;
        admin = newAdmin;

        emit SetNewAdmin (oldAdmin, newAdmin);
    }

    function _setManager (address newManager) external onlyAdmin {
        address oldManager = manager;
        manager = newManager;

        emit SetNewManager(oldManager, newManager);
    }

    function _setSlidingWindow (address newSlidingWindow) external onlyAdmin {
        address oldSlidingWindow = address(slidingWindow);
        slidingWindow = ISlidingWindow(newSlidingWindow);

        emit SetNewSlidingWindow(oldSlidingWindow, newSlidingWindow);
    }
}