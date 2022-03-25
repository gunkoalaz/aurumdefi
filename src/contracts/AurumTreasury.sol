// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './Comptroller.sol';
import './interface/UniswapInterface.sol';

contract AurumTreasury {
    // This is the treasury of Aurum DeFi
    // This contract will receive tokens fee 'when users withdraw tokens' => receive those tokens, 'minting AURUM' => receive those AURUM

    Comptroller public comptroller;
    address public uniswapV2Router;  //SET the DEX to use SwapExactTokensForTokens function

    address public admin;
    // address[] allMarkets;   //All the markets use function get allMarkets instead

    uint public redistributionRatio; // store in % e18
    uint public vaultRatio;

    bool locked;

    constructor(address comptroller_) {
        admin = msg.sender;
        redistributionRatio = 0.5e18;   // default 50%
        vaultRatio = 0.5e18;            // default 50%
        comptroller = Comptroller(comptroller_); // can get the verified markets by using comptroller getAllMarkets
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "OnlyAdmin");
        _;
    }
    modifier noReentrance {
        require(!locked,"No reentrance");
        locked = true;
        _;
        locked = false;

    }

    event SetDistributionRatio(uint oldDistributionRatio, uint newDistributionRatio);
    event SetDecentralizedExchange(address oldDEXAddress, address newDEXAddress);

    function getAllMarkets() internal view returns (LendTokenInterface[] memory){
        return comptroller.compStorage().getAllMarkets();
    }

    //This function will set allowance of the 'contract' to 'lendToken contract' max UINT
    // When function 'mint' of LendToken is activate, the transferFrom() function will be able to run
    // LendREI no need for approve
    function approveDeposit(LendTokenInterface lendToken) internal {
        lendToken.approve(address(lendToken), type(uint).max);
    }

    //staking Asset will deposit the tokens in treasury to the vault to increase self liquidity
    function stakingAsset(LendTokenInterface lendToken, uint amount) internal {
        uint allowance = lendToken.allowance(address(this), address(lendToken));
        if(allowance < amount){
            approveDeposit(lendToken);
        }
    }

    function swapTokens(ERC20 tokenA, ERC20 tokenB, uint amountIn) internal{
        IUniswapV2Router uniswapRouter = IUniswapV2Router(uniswapV2Router);
        PriceOracle oracle = PriceOracle(comptroller.getComptrollerOracleAddress());
        // A * priceA  = B * priceB
        // Using price oracle to prevent sandwich attack
        uint priceA = oracle.assetPrices(address(tokenA));
        uint priceB = oracle.assetPrices(address(tokenB));
    }

    function swapETHtoTokens(ERC20 token, uint amountIn) internal {

    }
    //This function will compare string a and b, return TRUE if both are the same.
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    // this is the core function for get everyfunction running
    // this function let anyone to activate distribution of reward
    // the distributionRatio only admin can set
    function distribute() external {
        LendTokenInterface[] memory allMarkets = getAllMarkets();
        uint i;
        uint balance;
        uint localRedistributionRatio = redistributionRatio;
        uint localVaultRatio = vaultRatio;
        require((localRedistributionRatio + localVaultRatio) == 1e18, "Distribution Ratio mismatch");

        for (i=0; i< allMarkets.length; i++) {
            if(compareStrings(allMarkets[i].symbol(), "lendRei")) {
                // LendREI token  underlying = REI
                balance = payable(address(this)).balance;
            } else {
                ERC20 underlying = ERC20(allMarkets[i].underlying());
                balance = underlying.balanceOf(address(this));
            }
        }
    }

    function _setDistributionRatio(uint newDistributionRatio) external onlyAdmin{
        uint oldDistributionRatio = redistributionRatio;
        redistributionRatio = newDistributionRatio;

        emit SetDistributionRatio(oldDistributionRatio, newDistributionRatio);
    }

    function _setDEXRouterAddress(address newDEXAddress) external onlyAdmin{
        address oldDEXAddress = uniswapV2Router;
        uniswapV2Router = newDEXAddress;

        emit SetDecentralizedExchange(oldDEXAddress, newDEXAddress);
    }
}