// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interface/ComptrollerInterface.sol";
import "./interface/ISlidingWindow.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AurumPriceOracle is PriceOracle {
    //
    // This version we reference price to Tether USDT, if the USDT is off pegged the price may go wrong.
    //

    address public admin;
    
    address public tether; // Tether used in reference price to the wanted TOKENs price
    address public wrei; // Wrapped REI address
    address public arm; // Governance token of AURUM DeFi

    uint public goldPrice;
    mapping(address => uint) prices;  //Manual set price, use in emergency case

    ISlidingWindow public slidingWindow;
    ComptrollerStorageInterface public compStorage;

    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);
    event GoldPricePosted(uint previousGoldPriceMantissa, uint requestedGoldPriceMantissa, uint newGoldPriceMantissa);
    event NewAdmin(address oldAdmin, address newAdmin);
    event UpdatePriceSlidingWindow (address tokenA, address tokenB);


    constructor(address compStorage_, address slidingWindow_,address tether_, address wrei_, address arm_) {
        admin = msg.sender;
        arm = arm_;
        wrei = wrei_;
        tether = tether_; // reference USDT as a mean of exchange
        prices[tether_] = 1e18; //Everything refer to usdt price
        slidingWindow = ISlidingWindow(slidingWindow_);
        compStorage = ComptrollerStorageInterface(compStorage_);
    }
    function isPriceOracle() external pure returns(bool) {
        return true;
    }

    function getUnderlyingPrice(LendTokenInterface lendToken) external view returns (uint) {

        address usdt  = tether;
        uint256 price;
        address token;

        //LendREI doesn't have underlying variable.
        if (compareStrings(lendToken.symbol(), "lendREI")) {
            token = wrei;
        }else {
            if(compareStrings(lendToken.symbol(), "lendUSDT")){
                return 1e18; // return price = 1 USDT: 1 USDT
            } else {
                token = lendToken.underlying();
            }
        }

        if(prices[token] != 0) {
            // Manual feed by admin
            price = prices[token];
        } else {
            // TWAP Uniswap v2 called
            price = slidingWindow.consult(token,1e18,usdt);

        }

        uint256 defaultDecimal = 18;
        uint256 tokenDecimal = uint256(ERC20(token).decimals());

        if(defaultDecimal == tokenDecimal) {
            return price;
        } else if(defaultDecimal > tokenDecimal) {
            return price * (10**(defaultDecimal-tokenDecimal));
        } else {
            return price / (10**(tokenDecimal-defaultDecimal));
        }
    }

    function updateAllSlidingWindow() external {
        LendTokenInterface[] memory lendToken = compStorage.getAllMarkets();
        ISlidingWindow uniswapOracle = slidingWindow;
        address usdt = tether;
        address underlying;
        uint i;
        for(i=0;i<lendToken.length;i++){
            //We compare each underlying to Tether USDT
            //We need bot to update the price of each pair
            if (compareStrings(lendToken[i].symbol(), "lendREI")) {
                underlying = wrei;
            } else {
                if (!compareStrings(lendToken[i].symbol(), "lendUSDT")) {
                    underlying = lendToken[i].underlying();
                }
            }
            //USDT is set to 1
            if (!compareStrings(lendToken[i].symbol(), "lendUSDT")) {    
                uniswapOracle.update(underlying, usdt);
                emit UpdatePriceSlidingWindow(underlying, usdt);
            }
        }
        uniswapOracle.update(arm, usdt);
        emit UpdatePriceSlidingWindow(arm, usdt);
    }

    function setUnderlyingPrice(LendTokenInterface lendToken, uint underlyingPriceMantissa) external {
        require(msg.sender == admin, "only admin can set underlying price");
        address asset = address(LendTokenInterface(address(lendToken)).underlying());
        emit PricePosted(asset, prices[asset], underlyingPriceMantissa, underlyingPriceMantissa);
        prices[asset] = underlyingPriceMantissa;
    }

    function setDirectPrice(address asset, uint price) external {
        require(msg.sender == admin, "only admin can set price");
        emit PricePosted(asset, prices[asset], price, price);
        prices[asset] = price;
    }

    function getGoldPrice() external view returns(uint){
        return goldPrice;
    }
    
    function setGoldPrice(uint underlyingPriceMantissa) external {      //Manually set gold price
        require(msg.sender == admin, "only admin can set new admin");
        goldPrice = underlyingPriceMantissa;
        emit GoldPricePosted(goldPrice, underlyingPriceMantissa, underlyingPriceMantissa);
    }

    function assetPrices(address asset) external view returns (uint) {
        uint price;
        address usdt = tether;
        if(prices[asset] != 0) {
            // Manual feed by admin
            price = prices[asset];
        } else {
            // TWAP Uniswap v2 called
            price = slidingWindow.consult(asset,1e18,usdt);

        }
        return price;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function _setAdmin(address newAdmin) external {
        require(msg.sender == admin, "only admin can set new admin");
        address oldAdmin = admin;
        admin = newAdmin;

        emit NewAdmin(oldAdmin, newAdmin);
    }
}