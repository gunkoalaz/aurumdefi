// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interface/ComptrollerInterface.sol";
import "./interface/ISlidingWindow.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AurumPriceOracle is PriceOracle {
    address public admin;
    
    address public tether; // Tether used in reference price to the wanted TOKENs price
    address public wrei; // Wrapped REI address

    uint public goldPrice;
    mapping(address => uint) prices;  //Manual set price, use in emergency case

    ISlidingWindow slidingWindow;

    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);
    event GoldPricePosted(uint previousGoldPriceMantissa, uint requestedGoldPriceMantissa, uint newGoldPriceMantissa);
    event NewAdmin(address oldAdmin, address newAdmin);


    constructor(address slidingWindow_,address tether_, address wrei_) {
        admin = msg.sender;
        wrei = wrei_;
        tether = tether_; // reference USDT as a mean of exchange
        slidingWindow = ISlidingWindow(slidingWindow_);
    }
    function isPriceOracle() external pure returns(bool) {
        return true;
    }

    function getUnderlyingPrice(LendTokenInterface lendToken) external view returns (uint) {

        address usdt  = tether;
        uint256 price;

        //LendREI doesn't have underlying variable.
        if (compareStrings(lendToken.symbol(), "lendREI")) {
            price = slidingWindow.consult(wrei,1e18,usdt);
            return price;
        }else {
            address token = lendToken.underlying();

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
        return prices[asset];
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function setAdmin(address newAdmin) external {
        require(msg.sender == admin, "only admin can set new admin");
        address oldAdmin = admin;
        admin = newAdmin;

        emit NewAdmin(oldAdmin, newAdmin);
    }
}