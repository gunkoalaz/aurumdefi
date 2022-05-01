// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import './interface/ComptrollerInterface.sol';
import './interface/UniswapInterface.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TreasuryAURUM {
    address public admin;

    address public busd;    //kBUSD contract
    address public aurum;   //AURUM contract

    address public uniswapRouters;      //Using Add/Remove liquidity
    address public uniswapFactory;      //Used for get AURUM/kBUSD LP address
    uint public swapfee;                //Uniswap swap fee

    uint public period;     //Interval that arbitrage function can be used
    uint public lastUpdate; //Recorded last arbitrage activate time.

    PriceOracle public oracle;  //getGoldPrice

    bool locked;    //Reentrance

    error ApproveFail();
    error TransferFail();

    event SetAdmin(address oldAdmin, address newAdmin);
    event SetFee(uint oldFee, uint newFee);
    event SetUniswapRouters(address oldUniswapRouters, address newUniswapRouters);
    event SetUniswapFactory(address oldUniswapFactory, address newUniswapFactory);
    event SetPriceOracle(address oldPriceOracle, address newPriceOracle);
    event Migrate(address to, uint BUSD, uint AURUM, uint LPToken);

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

    constructor(address busd_, address aurum_) {
        admin = msg.sender;
        locked = false;

        busd = busd_;
        aurum = aurum_;

        period = 3600;   // 1 hr
    }

    function addLiquidity(address tokenA, address tokenB, uint amountInA, uint amountInB) internal returns(uint amountA, uint amountB, uint liquidity) {
        if(amountInA == 0 || amountInB == 0){
            return (0,0,0);
        }
        IERC20 tokenA_ = IERC20(tokenA);
        IERC20 tokenB_ = IERC20(tokenB);
        
        address varRouter = uniswapRouters;
        IUniswapV2Router routerContract = IUniswapV2Router(varRouter);

        // Approve
        bool success;
        success = tokenA_.approve(varRouter, amountInA);
        if(!success){
            revert ApproveFail();
        }        
        success = tokenB_.approve(varRouter, amountInB);
        if(!success){
            revert ApproveFail();
        }        

        (amountA, amountB, liquidity) = routerContract.addLiquidity(
            tokenA,
            tokenB,
            amountInA,
            amountInB,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    function removeLiquidity(address tokenA, address tokenB, uint amount) internal returns(uint amountOutA, uint amountOutB){
        require (tokenA != address(0) && tokenB != address(0), "BAD_INPUT");
        if(amount == 0){
            return (0,0);
        }
        address varRouter = uniswapRouters;
        IUniswapV2Router routerContract = IUniswapV2Router(varRouter);

        IUniswapV2Factory factory = IUniswapV2Factory(uniswapFactory);
        IERC20 LPToken = IERC20(factory.getPair(address(tokenA), address(tokenB)));

        //Approve
        bool success = LPToken.approve(varRouter, amount);
        if(!success){
            revert ApproveFail();
        }        

        (amountOutA, amountOutB) = routerContract.removeLiquidity(
            tokenA,
            tokenB,
            amount,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

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
        bool success = tokenIn.approve(varRouter, amountIn);
        if(!success){
            revert ApproveFail();
        }        

        //Setting path
        address[] memory path;
        path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;

        //Swap A to B
        (uint[] memory amount) = routerContract.swapExactTokensForTokens(amountIn, 1, path, address(this), block.timestamp);

        return amount[1]; // return amountOut;
    }

    function getDEXAURUMPrice() external view returns(uint price){
        IERC20 busd_ = IERC20(busd);
        IERC20 aurum_ = IERC20(aurum);

        IUniswapV2Factory factory = IUniswapV2Factory(uniswapFactory);
        address LPToken = factory.getPair(address(busd_), address(aurum_));

        uint busdAmount = busd_.balanceOf(LPToken);
        uint aurumAmount = aurum_.balanceOf(LPToken);

        require(busdAmount != 0 && aurumAmount != 0, "Price can't be calculated");
        price = busdAmount * 1e18 / aurumAmount;

    }

    struct ArbitrageVariable {
        uint goldPrice;
        uint currentPrice;
        uint balanceBUSD;
        uint balanceAURUM;
        uint balanceLPToken;
        uint lpBalanceBUSD;
        uint lpBalanceAURUM;
    }

    function arbitrage() external noReentrance{
        //Check and update Activate time   this function can only use once in a period time.
        uint currentTime = block.timestamp;
        uint lastTime = lastUpdate;
        uint period_ = period;
        if(period_ + lastTime > currentTime){
            revert ("Too Frequent");
        } else {
            lastUpdate = currentTime;
        }

        arbitrageInternal();
    }

    function arbitrageInternal() internal {

        IERC20 busd_ = IERC20(busd);
        IERC20 aurum_ = IERC20(aurum);

        IUniswapV2Factory factory = IUniswapV2Factory(uniswapFactory);
        IERC20 LPToken = IERC20(factory.getPair(address(busd_), address(aurum_)));

        ArbitrageVariable memory vars;

        vars.balanceBUSD = busd_.balanceOf(address(this));
        vars.balanceAURUM = aurum_.balanceOf(address(this));
        vars.balanceLPToken = LPToken.balanceOf(address(this));

        vars.goldPrice = oracle.getGoldPrice();
        vars.currentPrice = (busd_.balanceOf(address(LPToken)) * 1e18 / aurum_.balanceOf(address(LPToken)));

        //Check difference price
        uint dif;
        if(vars.goldPrice > vars.currentPrice) {
            dif = vars.goldPrice - vars.currentPrice;
        } else {
            dif = vars.currentPrice - vars.goldPrice;
        }

        uint difPercent = dif * 1e18 / vars.goldPrice;
        if(difPercent < 0.01e18){
            return; //Dif < 1%, No need for arbitrage
        }

        //Removing LP for using less token for stabilized pricec
        if(vars.balanceLPToken != 0){
            if(busd_.balanceOf(address(LPToken)) != vars.balanceBUSD){
                //Remove all
                removeLiquidity(address(busd_), address(aurum_), vars.balanceLPToken);
            } else {
                //Remove 99%
                removeLiquidity(address(busd_), address(aurum_), vars.balanceLPToken / 100);
            }
        }
        
        vars.balanceBUSD = busd_.balanceOf(address(this));
        vars.balanceAURUM = aurum_.balanceOf(address(this));


        vars.lpBalanceBUSD = busd_.balanceOf(address(LPToken)); //Balance of tokens in LPpool after removing liquidity
        vars.lpBalanceAURUM = aurum_.balanceOf(address(LPToken));
        require(vars.lpBalanceBUSD != 0 && vars.lpBalanceAURUM != 0,"Not enough LP balance");

        //Calculate swap amount to target price
        uint amountIn;
        uint amountOut;
        if(vars.goldPrice > vars.currentPrice) {
            //Buy Aurum, amountIn is kBUSD amount
            amountIn = vars.lpBalanceBUSD * (sqrt(vars.goldPrice * 1e36 / vars.currentPrice) -1e18) / (1e18 - swapfee);
            if(amountIn > vars.balanceBUSD){
                amountIn = vars.balanceBUSD;
            }
            //Swap
            amountOut = swap(address(busd_), address(aurum_), amountIn);
            vars.balanceBUSD = vars.balanceBUSD - amountIn;
            vars.balanceAURUM = vars.balanceAURUM + amountOut;
        } else {
            amountIn = vars.lpBalanceAURUM * (sqrt(vars.currentPrice * 1e36 / vars.goldPrice) - 1e18) / (1e18 - swapfee);
            if(amountIn > vars.balanceAURUM){
                amountIn = vars.balanceAURUM;
            }
            amountOut = swap(address(aurum_), address(busd_), amountIn);
            vars.balanceAURUM = vars.balanceAURUM - amountIn;
            vars.balanceBUSD = vars.balanceBUSD + amountOut;
        }

        //Finally add liquidity
        addLiquidity(address(busd_), address(aurum_), vars.balanceBUSD, vars.balanceAURUM);
    }

    //Square root mathematic library  this function fork from uniswap
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
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

    function _setUniswapRouters(address newUniswapRouters) external onlyAdmin {
        require(newUniswapRouters != address(0));
        address oldUniswapRouters = uniswapRouters;
        uniswapRouters = newUniswapRouters;

        emit SetUniswapRouters(oldUniswapRouters, newUniswapRouters);
    }

    function _setUniswapFactory(address newUniswapFactory) external onlyAdmin {
        require(newUniswapFactory != address(0));
        address oldUniswapFactory = uniswapFactory;
        uniswapFactory = newUniswapFactory;

        emit SetUniswapFactory(oldUniswapFactory, newUniswapFactory);
    }

    function _setFee(uint newFee) external onlyAdmin {
        require(newFee != swapfee,"repeated fee");
        uint oldFee = swapfee;
        swapfee = newFee;

        emit SetFee(oldFee, newFee);
    }

    function _setPriceOracle(address newPriceOracle) external onlyAdmin {
        require(newPriceOracle != address(0));
        address oldPriceOracle = address(oracle);
        oracle = PriceOracle(newPriceOracle);

        emit SetUniswapRouters(oldPriceOracle, newPriceOracle);
    }
    // Migrate kBUSD, AURUM, LP token   to target address.
    function _migrate(address to) external onlyAdmin {
        IERC20 busd_ = IERC20(busd);
        IERC20 aurum_ = IERC20(aurum);

        IUniswapV2Factory factory = IUniswapV2Factory(uniswapFactory);
        IERC20 LPToken = IERC20(factory.getPair(address(busd_), address(aurum_)));

        uint balanceBUSD = busd_.balanceOf(address(this));
        uint balanceAURUM = aurum_.balanceOf(address(this));
        uint balanceLPToken = LPToken.balanceOf(address(this));

        //Approve all tokens
        bool success;
        success = busd_.approve(to, balanceBUSD);
        if(!success){
            revert ApproveFail();
        }
        success = aurum_.approve(to, balanceAURUM);
        if(!success){
            revert ApproveFail();
        }
        success = LPToken.approve(to, balanceLPToken);
        if(!success){
            revert ApproveFail();
        }

        //Transfer all tokens
        success = busd_.transfer(to, balanceBUSD);
        if(!success){
            revert TransferFail();
        }
        success = aurum_.transfer(to, balanceAURUM);
        if(!success){
            revert TransferFail();
        }
        success = LPToken.transfer(to, balanceLPToken);
        if(!success){
            revert TransferFail();
        }

        emit Migrate(to, balanceBUSD, balanceAURUM, balanceLPToken);
    }

}