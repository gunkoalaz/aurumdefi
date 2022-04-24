// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './interface/ComptrollerInterface.sol';
import './interface/UniswapInterface.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TreasuryWallet {
    address public admin;
    
    address public busd; // kBUSD address, this will reference stable coin to be switch to and send them to Vault to distribute to share hodlers.

    address public compStorage;
    address public uniswapRouters; // This refer to uniswap v2 router
    address public armVault; // The reward distributing vault (Distribute kBUSD), only send kBUSD to this address, the contract will automatic adjust reward spending.

    bool locked;

    uint8 public reinvestRatio; // 0 = 0%, 100 = 100%

    constructor (address busd_, uint8 reinvestRatio_) {
        admin = msg.sender;
        busd = busd_;

        reinvestRatio = reinvestRatio_;
        locked = false;
    }


    event SendBUSDToVault(uint amount);
    event Swap(address tokenIn, address tokenOut, uint amount);
    event Reinvest(address lendToken, uint amount);
    event Withdraw(address lendToken, uint amount);
    event DistributeToken(address token, uint reinvestAmount, uint distributeAmount);
    event TransferREI(address to, uint amount);

    event SetAdmin(address oldAdmin, address newAdmin);
    event SetComptrollerStorage(address oldComptrollerStorage, address newComptrollerStorage);
    event SetUniswapRouters(address oldUniswapRouters, address newUniswapRouters);
    event SetARMVault(address oldARMVault, address newARMVault);
    event SetReinvestRatio(uint8 oldRatio, uint8 newRatio);

    modifier onlyAdmin {
        require(msg.sender == admin, "OnlyAdmin");
        _;
    }

    modifier noReentrance {
        require(!locked, "no reentrance");
        locked = true;
        _;
        locked = false;
    }



    // This function will send BUSD to armVault
    function sendToVault(uint amount) internal {
        IERC20 kBUSD = IERC20(busd);
        address vault = armVault;
        require(kBUSD.balanceOf(address(this)) >= amount, "Not enough BUSD");
        require(amount > 0, "BAD_INPUT");
        
        bool success = kBUSD.transfer(vault, amount);
        require(success,"Transfer failed");

        emit SendBUSDToVault(amount);
    }

    // Call swap function of Uniswap V2
    function swap(address tokenA, address tokenB, uint amountIn) internal returns(uint) {
        if(tokenA == tokenB){
            return amountIn; //no need for swap
        }
        address varRouter = uniswapRouters;
        IUniswapV2Router routerContract = IUniswapV2Router(varRouter);
        IERC20 tokenIn = IERC20(tokenA);

        require(tokenIn.balanceOf(address(this))>=amountIn, "Not enough balance");
        require(amountIn > 0, "BAD_INPUT");

        //Approve the tokenA
        tokenIn.approve(varRouter, amountIn);

        //Setting path
        address[] memory path;
        path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        //Swap A to B
        (uint[] memory amount) = routerContract.swapExactTokensForTokens(amountIn, 1, path, address(this), block.timestamp);

        return amount[1]; // return amountOut;
    }

    /* Reinvest and Withdraw function
     * These function interact with LendToken contract to Deposit OR Withdraw underlying tokens
     */
    function reinvest(LendTokenInterface lendToken, uint amount) internal {
        IERC20 underlying = IERC20(lendToken.underlying());
        require(underlying.balanceOf(address(this)) >= amount,"Not enough balance");
        require(amount > 0, "BAD_INPUT");

        //Approve underlying
        underlying.approve(address(lendToken), amount); // Deposit underlying to lendToken contract

        //Deposit
        lendToken.mint(amount);
        emit Reinvest(address(lendToken), amount);
    }

    function withdraw(LendTokenInterface lendToken, uint amount) external onlyAdmin {
        require(lendToken.balanceOf(address(this)) >= amount);
        require(amount > 0, "BAD_INPUT");

        //Withdraw
        lendToken.redeem(amount); // redeem amount using lendToken amount
        emit Withdraw(address(lendToken), amount);
    }

    //ALL-IN-ONE switch will do following functions
    //  Divided each tokens to 2 part
    //  First part is reinvest
    //  Second part is swap to kBUSD and transfer to armVault
    //--Anyone can trigger this button !!
    function distributionSwitch() external noReentrance {
        ComptrollerStorageInterface comptrollerStorage = ComptrollerStorageInterface(compStorage);
        LendTokenInterface[] memory markets = comptrollerStorage.getAllMarkets();
        uint16 i;
        uint16 len = uint16(markets.length);
        for(i=0; i<len; i++){
            distributeEachTokens(markets[i]);
        }

    }

    function distributeEachTokens(LendTokenInterface lendToken) internal {
        //Rule out the lendREI first
        if(compareStrings(lendToken.symbol(), "lendREI")){
            return; // lendREI not use for calculation, Admin can withdraw all REI using withdrawREI function
        }

        IERC20 underlying = IERC20(lendToken.underlying());

        //Check balance
        uint balance = underlying.balanceOf(address(this));
        if(balance == 0){
            return; //Short circuit out
        }

        //Divided to 2 part
        uint8 varsReinvest = reinvestRatio;
        
        uint reinvestAmount = balance * varsReinvest / 100;
        uint distributeAmount = balance - reinvestAmount;

        //Reinvestment
        if(reinvestAmount > 0){
            reinvest(lendToken, reinvestAmount); //Deposit to the LendToken contract.
        }

        //Distribute -- Swap and transfer that amount
        if(distributeAmount > 0){
            uint actualBUSDget = swap(address(underlying), busd, distributeAmount);
            sendToVault(actualBUSDget);
        }
        emit DistributeToken(address(underlying), reinvestAmount, distributeAmount);
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function withdrawREI(address payable to, uint amount) external onlyAdmin {
        to.transfer(amount);
        emit TransferREI(to, amount);
    }

    // ==================================
    //  Admin function
    // ==================================
    function _setAdmin (address newAdmin) external onlyAdmin {
        require(newAdmin != address(0));
        address oldAdmin = admin;
        admin = newAdmin;

        emit SetAdmin(oldAdmin, newAdmin);
    }

    function _setComptrollerStorage (address newComptrollerStorage) external onlyAdmin {
        require(newComptrollerStorage != address(0));
        address oldComptrollerStorage = compStorage;
        compStorage = newComptrollerStorage;

        emit SetComptrollerStorage(oldComptrollerStorage, newComptrollerStorage);
    }

    function _setUniswapRouters(address newUniswapRouters) external onlyAdmin {
        require(newUniswapRouters != address(0));
        address oldUniswapRouters = uniswapRouters;
        uniswapRouters = newUniswapRouters;

        emit SetUniswapRouters(oldUniswapRouters, newUniswapRouters);
    }

    function _setARMVault(address newARMVault) external onlyAdmin {
        require(newARMVault != address(0));
        address oldARMVault = armVault;
        armVault = newARMVault;

        emit SetARMVault(oldARMVault, newARMVault);
    }

    function _setReinvestRatio(uint8 newRatio) external onlyAdmin {
        require(newRatio>=0 && newRatio<=100, "BAD_INPUT");
        uint8 oldRatio = reinvestRatio;
        reinvestRatio = newRatio;

        emit SetReinvestRatio(oldRatio, newRatio);
    }
}