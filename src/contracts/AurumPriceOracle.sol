// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./interface/ComptrollerInterface.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract IStdReference {
    struct ReferenceData {
        uint256 rate; // base/quote exchange rate, multiplied by 1e18.
        uint256 lastUpdatedBase; // UNIX epoch of the last time when base price gets updated.
        uint256 lastUpdatedQuote; // UNIX epoch of the last time when quote price gets updated.
    }
    function getReferenceData(string calldata _base, string calldata _quote) virtual external view returns (ReferenceData memory);
    function getReferenceDataBulk(string[] calldata _bases, string[] calldata _quotes) virtual external view returns (ReferenceData[] memory);
}

contract AurumPriceOracle is PriceOracle {
    address public admin;

    uint public goldPrice;
    mapping(address => uint) prices;
    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);
    event GoldPricePosted(uint previousGoldPriceMantissa, uint requestedGoldPriceMantissa, uint newGoldPriceMantissa);
    event NewAdmin(address oldAdmin, address newAdmin);

    IStdReference ref;

    constructor() {
        address bandAddress = 0xDA7a001b254CD22e46d3eAB04d937489c93174C3;   //BAND protocol oracle
        ref = IStdReference(bandAddress);
        admin = msg.sender;
    }
    function isPriceOracle() external pure returns(bool) {
        return true;
    }

    function getUnderlyingPrice(LendTokenInterface lendToken) external view returns (uint) {
        if (compareStrings(lendToken.symbol(), "lendREI")) {
            return 1.5*1e18; //Test
            //IStdReference.ReferenceData memory data = ref.getReferenceData("BNB", "USD");
            //return data.rate;
        }else if (compareStrings(lendToken.symbol(), "ARM")) {
            return prices[address(lendToken)];
        } else {
            uint256 price;
            ERC20 token = ERC20(LendTokenInterface(address(lendToken)).underlying());

            if(prices[address(token)] != 0) {
                price = prices[address(token)];
            } else {
                IStdReference.ReferenceData memory data = ref.getReferenceData(token.symbol(), "USD");
                price = data.rate;
            }

            uint256 defaultDecimal = 18;
            uint256 tokenDecimal = uint256(token.decimals());

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