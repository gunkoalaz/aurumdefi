// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import './interface/ComptrollerInterface.sol';
//
//  Lend token contract is forked and modified from venus' VToken contract
//  LendREI is not ERC20 standard !!
//

contract LendREI{

    function isLendToken() external pure returns(bool) {return true;} // Indicator that this is the lend token

    bool internal _notEntered; // re-entrancy guarding check
    // -----------------------------
    // Standard variables for tokens
    // -----------------------------
    string public name;
    string public symbol;
    uint8 public decimals;
    uint public totalSupply;

    mapping (address => uint256) accountTokens;
    mapping (address => mapping (address => uint256)) transferAllowances;
    address public admin;                                   //owner of this contract
    // ----------------
    // Market parameter
    // ----------------
    struct BorrowSnapshot {
        uint principal;
        uint interestIndex;
    }
    mapping (address => BorrowSnapshot) public accountBorrows;    //Outstanding borrow balances for each account
    function getAccountBorrows(address user) external view returns(uint, uint) { 
        return (accountBorrows[user].principal, accountBorrows[user].interestIndex);
    }

    ComptrollerInterface public comptroller;                //get the comptroller
    InterestRateModel public interestRateModel;

    address[] public borrowAddress;         //Stored all borrow address
    mapping(address => bool) hasBorrowed;  
    function getBorrowAddress() external view returns(address[] memory){
        return borrowAddress;
    }

    // -----------------
    // Lending parameter
    // -----------------
    uint constant public borrowRateMaxMantissa = 0.0004e14;        //Maximum borrow rate (0.000004% / sec) or 126.14% /year
    uint constant public reserveFactorMaxMantissa = 1e18;          //Maximum fraction of interest that can be set aside for reserves
    uint constant public initialExchangeRateMantissa = 1e18;       //Initial exchange rate, Used when minting first Lend token (totalSupply = 0)
    uint public reserveFactorMantissa;                          //Current fraction of interest

    // AccrueInterest update parameter
    uint public accrualTimestamp;                                //Last accrued block timestamp
    uint public borrowIndex;                                       //Accumulate total earned interest rate
    uint public totalBorrows;                                      //Total amount of borrowed underlying asset
    uint public totalReserves;                                     //Total amount of underlying asset

    modifier nonReentrant() {
        require(_notEntered, "re-entered");
        _notEntered = false;
        _;
        _notEntered = true; // get a gas-refund post-Istanbul
    }


    // ------------------
    // Initiate parameter
    // ------------------

    constructor (string memory name_, string memory symbol_, uint8 decimals_, address interestRateModel_, address comptroller_) {

        name = name_;
        symbol = symbol_;
        decimals = decimals_;

        interestRateModel = InterestRateModel(interestRateModel_);
        comptroller = ComptrollerInterface(comptroller_);
        borrowIndex = 1e18;
        reserveFactorMantissa = 0.2e18; //default reserveFactor = 20%
        
        accrualTimestamp = block.timestamp;
        admin = msg.sender;
        _notEntered = true;
    }

    // -------------
    // Market Events
    // -------------

    error NotAllowed();


    event Mint(address minter, uint mintAmount, uint mintTokens);                                                               //Emit when tokens are minted
    event Redeem(address redeemer, uint redeemAmount, uint redeemTokens);                                                       //Emit when tokens are redeemed
    event RedeemFee(address redeemer, uint feeAmount, uint redeemTokens);                                                       //Emit when tokens are redeemed and fee are transferred
    event Borrow(address borrower, uint borrowAmount, uint accountBorrows, uint totalBorrows);                                  //Emit when underlying is borrowed
    event RepayBorrow(address payer, address borrower, uint repayAmount, uint accountBorrows, uint totalBorrows);               //Emit when a borrow is repaid
    event LiquidateBorrow(address liquidator, address borrower, uint repayAmount, address LendTokenCollateral, uint seizeTokens);  //Emit when a borrow is liquidated
    event NewLendTokenStorage(address oldLendTokenStorage, address newLendTokenStorage);

    event AccrueInterest(uint cashPrior, uint interestAccumulated, uint borrowIndex, uint totalBorrows);                        //Emit when interest is accrued
    event NEW_SUPERVISE_TOKEN(address oldLendToken, address newLendToken);                                                      //Emit when change the bind token
    event NewMarketInterestRateModel(InterestRateModel oldInterestRateModel, InterestRateModel newInterestRateModel);           //Emit when changing interestRateModel
    event NewReserveFactor(uint oldReserveFactorMantissa, uint newReserveFactorMantissa);                                       //Emit when changing reserve factor
    event ReservesAdded(address benefactor, uint addAmount, uint newTotalReserves);                                             //Emit when adding reserves
    event ReservesReduced(address admin, uint reduceAmount, uint newTotalReserves);                                             //Emit when reducing reserves
    event NewComptroller(ComptrollerInterface oldComptroller, ComptrollerInterface newComptroller);                             //Emit when changing comptroller

    // ------------
    // Admin Events
    // ------------

    event NewAdmin(address oldAdmin, address newAdmin);    

    /**
        * @notice EIP20 Transfer event
    */
    event Transfer(address indexed from, address indexed to, uint amount);

    /**
      * @notice EIP20 Approval event
    */
    event Approval(address indexed owner, address indexed spender, uint amount);

    /**
     * @notice Transfer `tokens` tokens from `src` to `dst` by `spender`
     * @dev Called by both `transfer` and `transferFrom` internally
     * @param spender The address of the account performing the transfer
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param tokens The number of tokens to transfer
     */
    function transferTokens(address spender, address src, address dst, uint tokens) internal{
        /* Fail if transfer not allowed */
        comptroller.transferAllowed(address(this), src, dst, tokens);
        
        /* Do not allow self-transfers */
        if (src == dst) {
            revert ("BAD_INPUT");
        }

        /* Get the allowance, infinite for the account owner */
        uint startingAllowance = 0;
        if (spender == src) {
            startingAllowance = type(uint).max;
        } else {
            startingAllowance = transferAllowances[src][spender];
        }

        uint allowanceNew;
        uint srvTokensNew;
        uint dstTokensNew;

        allowanceNew = startingAllowance - tokens;
        srvTokensNew = accountTokens[src] - tokens;
        dstTokensNew = accountTokens[dst] + tokens;

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        accountTokens[src] = srvTokensNew;
        accountTokens[dst] = dstTokensNew;

        /* Eat some of the allowance (if necessary) */
        if (startingAllowance != type(uint).max) {
            transferAllowances[src][spender] = allowanceNew;
        }

        /* We emit a Transfer event */
        emit Transfer(src, dst, tokens);
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     */
    function transfer(address dst, uint256 amount) external nonReentrant {
        transferTokens(msg.sender, msg.sender, dst, amount);
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     */
    function transferFrom(address src, address dst, uint256 amount) external nonReentrant{
        transferTokens(msg.sender, src, dst, amount);
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved
     */
    function approve(address spender, uint256 amount) external{
        address src = msg.sender;
        transferAllowances[src][spender] = amount;
        emit Approval(src, spender, amount);
    }

    /**
     * @notice Get the current allowance from `owner` for `spender`
     * @param owner The address of the account which owns the tokens to be spent
     * @param spender The address of the account which may transfer tokens
     * @return The number of tokens allowed to be spent
     */
    function allowance(address owner, address spender) external view returns (uint256) {
        return transferAllowances[owner][spender];
    }

    /**
     * @notice Get the token balance of the `owner`
     * @param owner The address of the account to query
     * @return The number of tokens owned by `owner`
     */
    function balanceOf(address owner) external view returns (uint256) {
        return accountTokens[owner];
    }

    /**
     * @notice Get the underlying balance of the `owner`
     * @dev This also accrues interest in a transaction
     * @param owner The address of the account to query
     * @return The amount of underlying owned by `owner`
     */
    function balanceOfUnderlying(address owner) external returns (uint) {
        uint exchangeRate = exchangeRateCurrent();
        uint balance = exchangeRate * accountTokens[owner] / 1e18;
        return balance;
    }

    /**
     * @notice Get a snapshot of the account's balances, and the cached exchange rate
     * @dev This is used by comptroller to more efficiently perform liquidity checks.
     * @param account Address of the account to snapshot
     * @return (token balance, borrow balance, exchange rate mantissa)
     */
    function getAccountSnapshot(address account) external view returns (uint, uint, uint) {
        uint LendTokenBalance = accountTokens[account];
        uint borrowBalance;
        uint exchangeRateMantissa;

        borrowBalance = borrowBalanceStored(account);

        exchangeRateMantissa = exchangeRateStored();

        return (LendTokenBalance, borrowBalance, exchangeRateMantissa);
    }


    /**
     * @notice Return the borrow balance of account based on stored data
     * @param account The address whose balance should be calculated
     * @return The principal * market borrow index / recorded borrowIndex
     */
    function borrowBalanceStored(address account) public view returns (uint) {
        uint principalTimesIndex;
        uint result;

        /* Get borrowBalance and borrowIndex */
        (uint principal, uint interestIndex) = this.getAccountBorrows(account);

        if (principal == 0) {
            return 0;
        }

        /* Calculate new borrow balance using the interest index:
         *  recentBorrowBalance = borrower.borrowBalance * market.borrowIndex / borrower.borrowIndex
         */

        // principalTimesIndex is now 1e36  :: e18 * e18 = e36
        principalTimesIndex = principal * borrowIndex;

        // result is 1e18  :: e36 / e18 = e18
        result = principalTimesIndex / interestIndex;

        return result;
    }
    /**
     * @notice Calculates the exchange rate from the underlying to the lendToken
     * @dev This function does not accrue interest before calculating the exchange rate
     * @return Calculated exchange rate scaled by 1e18
     */
    function exchangeRateStored() public view returns (uint) {
        uint _totalSupply = totalSupply;
        uint totalCash = getCashPrior();
        uint cashPlusBorrowsMinusReserves;

        if (_totalSupply == 0) {
            /*
             * If there are no tokens minted:
             *  exchangeRate = initialExchangeRate
             */
            return (initialExchangeRateMantissa);
        } else {
            /*
             * Otherwise:
             *  exchangeRate = (totalCash + totalBorrows - totalReserves) / totalSupply
             */

            // cashPlusBorrows is in 1e18
            cashPlusBorrowsMinusReserves = totalCash + totalBorrows - totalReserves;

            // exchangeRate mantissa is in 1e18 :: e18 * 1e18 / e18
            uint exchangeRateMantissa = cashPlusBorrowsMinusReserves * 1e18 / _totalSupply;

            return exchangeRateMantissa;
        }
    }
    function getCash() public view returns (uint) {
        return payable(address(this)).balance;
    }

    function getCashPrior() internal view returns (uint) {
        uint contractBalance = payable(address(this)).balance;
        uint startingBalance = contractBalance - msg.value;
        return startingBalance;
    }
    /**
     * @notice Applies accrued interest to total borrows and reserves
     * @dev This calculates interest accrued from the last checkpointed timestamp
     *   up to the current timestamp and writes new checkpoint to storage.
     */
    function accrueInterest() public {
        /* Remember the initial block timestamp */
        uint currentTimestamp = block.timestamp;
        uint accrualTimestampPrior = accrualTimestamp;

        /* Short-circuit accumulating 0 interest */
        if (accrualTimestampPrior == currentTimestamp) {
            return ;
        }

        /* Read the previous values out of storage */
        uint cashPrior = getCashPrior();
        uint borrowsPrior = totalBorrows;
        uint reservesPrior = totalReserves;
        uint borrowIndexPrior = borrowIndex;

        /* Calculate the current borrow interest rate */
        uint borrowRateMantissa = interestRateModel.getBorrowRate(cashPrior, borrowsPrior, reservesPrior);
        require(borrowRateMantissa <= borrowRateMaxMantissa, "borrow rate is absurdly high");

        /* Calculate the time elapsed since the last accrual */
        uint timeDelta = currentTimestamp - accrualTimestampPrior;

        /*
         * Calculate the interest accumulated into borrows and reserves and the new index:
         *  simpleInterestFactor = borrowRate * timeDelta
         *  interestAccumulated = simpleInterestFactor * totalBorrows
         *  totalBorrowsNew = interestAccumulated + totalBorrows
         *  totalReservesNew = interestAccumulated * reserveFactor + totalReserves
         *  borrowIndexNew = simpleInterestFactor * borrowIndex + borrowIndex
         */

        uint simpleInterestFactor;
        uint interestAccumulated;
        uint totalBorrowsNew;
        uint totalReservesNew;
        uint borrowIndexNew;

        // simpleInterestFactor is 1e18 :: e18 * e1
        simpleInterestFactor = borrowRateMantissa * timeDelta;
        // interestAccumulated is 1e18 :: e18 * e18 /1e18
        interestAccumulated = simpleInterestFactor * borrowsPrior / 1e18;
        // totalBorrowsNew is 1e18
        totalBorrowsNew = interestAccumulated + borrowsPrior;
        // totalReservesNew is 1e18  :: (e18 * e18 / e18) + e18
        totalReservesNew = (reserveFactorMantissa * interestAccumulated / 1e18) + reservesPrior;
        // borrowIndexNew is 1e18 :: (e18 * e18 / e18) + e18
        borrowIndexNew = (simpleInterestFactor * borrowIndexPrior / 1e18) + borrowIndexPrior;

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /* We write the previously calculated values into storage */
        accrualTimestamp = currentTimestamp;
        borrowIndex = borrowIndexNew;
        totalBorrows = totalBorrowsNew;
        totalReserves = totalReservesNew;

        /* We emit an AccrueInterest event */
        emit AccrueInterest(cashPrior, interestAccumulated, borrowIndexNew, totalBorrowsNew);
    }
    /**
     * @notice Returns the current per-seconds borrow interest rate for this LendToken
     * @return The borrow interest rate per seconds, scaled by 1e18
     */
    function borrowRatePerSeconds() external view returns (uint) {
        return interestRateModel.getBorrowRate(getCashPrior(), totalBorrows, totalReserves);
    }

    /**
     * @notice Returns the current per-seconds supply interest rate for this lendToken
     * @return The supply interest rate per seconds, scaled by 1e18
     */
    function supplyRatePerSeconds() external view returns (uint) {
        return interestRateModel.getSupplyRate(getCashPrior(), totalBorrows, totalReserves, reserveFactorMantissa);
    }


    /**
     * @notice Accrue interest then return the up-to-date exchange rate
     * @return Calculated exchange rate scaled by 1e18
     */
    function exchangeRateCurrent() public returns (uint) {
        accrueInterest();
        return exchangeRateStored();
    }

    /**
     * @notice Sender supplies assets into the market and receives lendTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @return (uint) the actual mint amount.
     */
    function mint() external payable returns(uint) {
        return mintInternal(msg.value);
    }
    function mintInternal(uint mintAmount) internal nonReentrant returns (uint) {
        accrueInterest();
        // mintFresh emits the actual Mint event if successful and logs on errors, so we don't need to
        return mintFresh(msg.sender, mintAmount);
    }


    /**
     * @notice User supplies assets into the market and receives lendTokens in exchange
     * @dev Assumes interest has already been accrued up to the current timestamp
     * @param minter The address of the account which is supplying the assets
     * @param mintAmount The amount of the underlying asset to supply
     * @return (uint) the actual mint amount.
     */
    function mintFresh(address minter, uint mintAmount) internal returns (uint) {
        /* Fail if mint not allowed */
        comptroller.mintAllowed(address(this), minter);

        uint exchangeRateMantissa;
        uint mintTokens;
        uint totalSupplyNew;
        uint accountTokensNew;
        uint actualMintAmount;

        exchangeRateMantissa = exchangeRateStored();

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        actualMintAmount = doTransferIn(minter, mintAmount);

        /*
         * We get the current exchange rate and calculate the number of lendTokens to be minted:
         *  mintTokens = actualMintAmount / exchangeRate
         */

        mintTokens = actualMintAmount * 1e18 / exchangeRateMantissa;

        /*
         * We calculate the new total supply of lendTokens and minter token balance, checking for overflow:
         *  totalSupplyNew = totalSupply + mintTokens
         *  accountTokensNew = accountTokens[minter] + mintTokens
         */
        totalSupplyNew = totalSupply + mintTokens;
        accountTokensNew = accountTokens[minter] + mintTokens;


        /* We write previously calculated values into storage */
        totalSupply = totalSupplyNew;
        accountTokens[minter] = accountTokensNew;

        /* We emit a Mint event, and a Transfer event */
        emit Mint(minter, actualMintAmount, mintTokens);
        emit Transfer(address(this), minter, mintTokens);

        return (actualMintAmount);
    }

    /**
     * @notice Sender redeems lendTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of lendTokens to redeem into underlying
     */
    function redeem(uint redeemTokens) external{
        redeemInternal(redeemTokens);
    }
    function redeemInternal(uint redeemTokens) internal nonReentrant {
        accrueInterest();
        redeemFresh(msg.sender, redeemTokens, 0);
    }

    /**
     * @notice Sender redeems lendTokens in exchange for a specified amount of underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemAmount The amount of underlying to receive from redeeming lendTokens
     */
    function redeemUnderlying(uint redeemAmount) external{
        redeemUnderlyingInternal(redeemAmount);
    }
    function redeemUnderlyingInternal(uint redeemAmount) internal nonReentrant{
        accrueInterest();
        redeemFresh(msg.sender, 0, redeemAmount);
    }


    /**
     * @notice User redeems lendTokens in exchange for the underlying asset
     * @dev Assumes interest has already been accrued up to the current timestamp
     * @param redeemer The address of the account which is redeeming the tokens
     * @param redeemTokensIn The number of lendTokens to redeem into underlying (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     * @param redeemAmountIn The number of underlying tokens to receive from redeeming lendTokens (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     */
    struct RedeemVars {
        uint exchangeRateMantissa;
        uint redeemTokens;
        uint redeemAmount;
        uint totalSupplyNew;
        uint accountTokensNew;
    }
    function redeemFresh(address redeemer, uint redeemTokensIn, uint redeemAmountIn) internal{
        require(redeemTokensIn == 0 || redeemAmountIn == 0, "BAD_INPUT");


        RedeemVars memory vars;

        
        /* exchangeRate = invoke Exchange Rate Stored() */
        vars.exchangeRateMantissa = exchangeRateStored();
        if (vars.exchangeRateMantissa == 0) {
            revert ("Fail exchange rate");
        }

        /* If redeemTokensIn > 0: */
        if (redeemTokensIn > 0) {
            /*
             * We calculate the exchange rate and the amount of underlying to be redeemed:
             *  redeemTokens = redeemTokensIn
             *  redeemAmount = redeemTokensIn x exchangeRateCurrent
             */
            vars.redeemTokens = redeemTokensIn;

            // redeemAmount is 1e18 :: e18*e18 / 1e18
            vars.redeemAmount = vars.exchangeRateMantissa * redeemTokensIn / 1e18;
        } else {
            /*
             * We get the current exchange rate and calculate the amount to be redeemed:
             *  redeemTokens = redeemAmountIn / exchangeRate
             *  redeemAmount = redeemAmountIn
             */

            // redeemTokens is 1e18 :: e18 * 1e18 / e18
            vars.redeemTokens = redeemAmountIn * 1e18 / vars.exchangeRateMantissa;

            vars.redeemAmount = redeemAmountIn;
        }

            /* Fail if redeem not allowed */
        comptroller.redeemAllowed(address(this), redeemer, vars.redeemTokens);

        /*
         * We calculate the new total supply and redeemer balance, checking for underflow:
         *  totalSupplyNew = totalSupply - redeemTokens
         *  accountTokensNew = accountTokens[redeemer] - redeemTokens
         */

        vars.totalSupplyNew = totalSupply - vars.redeemTokens;

        vars.accountTokensNew = accountTokens[redeemer] - vars.redeemTokens;

        /* Fail gracefully if protocol has insufficient cash */
        if (getCashPrior() < vars.redeemAmount) {
            revert ("Insufficient cash");
        }

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        uint feeAmount;
        uint remainedAmount;
        if (IComptroller(address(comptroller)).treasuryPercent() != 0) {
            //feeAmount is 1e18 :: e18 * e18 /1e18
            feeAmount = vars.redeemAmount * IComptroller(address(comptroller)).treasuryPercent() /1e18;
            remainedAmount = vars.redeemAmount - feeAmount;

        } else {
            remainedAmount = vars.redeemAmount;
        }
        

        if(feeAmount != 0) {
            doTransferOut(IComptroller(address(comptroller)).treasuryAddress(), feeAmount);
            emit RedeemFee(redeemer, feeAmount, vars.redeemTokens);
        }
        doTransferOut(redeemer, remainedAmount);

        /* We write previously calculated values into storage */
        totalSupply = vars.totalSupplyNew;
        accountTokens[redeemer] = vars.accountTokensNew;

        /* We emit a Transfer event, and a Redeem event */
        emit Transfer(redeemer, address(this), vars.redeemTokens);
        emit Redeem(redeemer, remainedAmount, vars.redeemTokens);
    }
    /**
      * @notice Sender borrows assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      */
    function borrow(uint borrowAmount) external {
        borrowInternal(borrowAmount);
    }
    function borrowInternal(uint borrowAmount) internal nonReentrant {
        accrueInterest();
        // borrowFresh emits borrow-specific logs on errors, so we don't need to
        borrowFresh(msg.sender, borrowAmount);
    }


    /*
      * @notice Users borrow assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      */
    function borrowFresh(address  borrower, uint borrowAmount) internal {
        /* Fail if borrow not allowed */
        comptroller.borrowAllowed(address(this), borrower, borrowAmount);

        /* Fail gracefully if protocol has insufficient underlying cash */
        if (getCashPrior() < borrowAmount) {
            revert("TOKEN_INSUFFICIENT_CASH");
        }

        uint localvarsAccountBorrows;
        uint accountBorrowsNew;
        uint totalBorrowsNew;

        /*
         * We calculate the new borrower and total borrow balances, failing on overflow:
         *  accountBorrowsNew = accountBorrows + borrowAmount
         *  totalBorrowsNew = totalBorrows + borrowAmount
         */
        localvarsAccountBorrows = borrowBalanceStored(borrower);

        accountBorrowsNew = localvarsAccountBorrows + borrowAmount;
        totalBorrowsNew = totalBorrows + borrowAmount;

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        // List borrower to the ledger
        if (hasBorrowed[borrower] == false){
            hasBorrowed[borrower] = true;
            borrowAddress.push(borrower);
        }   
        doTransferOut(borrower, borrowAmount);

        /* We write the previously calculated values into storage */
        accountBorrows[borrower].principal = accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        
        totalBorrows = totalBorrowsNew;

        /* We emit a Borrow event */
        emit Borrow(borrower, borrowAmount, accountBorrowsNew, totalBorrowsNew);
    }

    /**
     * @notice Sender repays their own borrow
     * @return actualRepayAmount
     */
    function repayBorrow() external payable returns (uint) {
        return repayBorrowInternal(msg.value);
    }
    function repayBorrowInternal(uint repayAmount) internal nonReentrant returns (uint) {
        accrueInterest();
        // repayBorrowFresh emits repay-borrow-specific logs on errors, so we don't need to
        return repayBorrowFresh(msg.sender, msg.sender, repayAmount);
    }


    /**
     * @notice Borrows are repaid by another user (possibly the borrower).
     * @param payer the account paying off the borrow
     * @param borrower the account with the debt being payed off
     * @param repayAmount the amount of undelrying tokens being returned
     */
    function repayBorrowFresh(address payer, address borrower, uint repayAmount) internal returns (uint) {
        /* Fail if repayBorrow not allowed */
        comptroller.repayBorrowAllowed(address(this), borrower);

        uint localvarsRepayAmount;
        uint borrowerIndex;
        uint localvarsAccountBorrows;
        uint accountBorrowsNew;
        uint totalBorrowsNew;
        uint actualRepayAmount;

        /* We remember the original borrowerIndex for verification purposes */
        borrowerIndex = accountBorrows[borrower].interestIndex;

        /* We fetch the amount the borrower owes, with accumulated interest */
        localvarsAccountBorrows = borrowBalanceStored(borrower);

        /* this part is modified from venus vToken contract,  */
        // prevent over repay by change repayAmount to maximum repay (total borrowed amount)
        if (repayAmount >= localvarsAccountBorrows) {
            // Could 'not allowed' to over repay in LendREI because the use of payable function
            // if this happen the transaction will revert in 'doTransferIn' function
                // localvarsRepayAmount = localvarsAccountBorrows;
            // We revert here to prevent over gas cost
            revert('Over repay');
        } else {
            localvarsRepayAmount = repayAmount;
        }

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        actualRepayAmount = doTransferIn(payer, localvarsRepayAmount);

        /*
         * We calculate the new borrower and total borrow balances, failing on underflow:
         *  accountBorrowsNew = accountBorrows - actualRepayAmount
         *  totalBorrowsNew = totalBorrows - actualRepayAmount
         */
        accountBorrowsNew = localvarsAccountBorrows - actualRepayAmount;

        totalBorrowsNew = totalBorrows - actualRepayAmount;

        /* We write the previously calculated values into storage */
        accountBorrows[borrower].principal = accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        
        totalBorrows = totalBorrowsNew;

        /* We emit a RepayBorrow event */
        emit RepayBorrow(payer, borrower, actualRepayAmount, accountBorrowsNew, totalBorrowsNew);

        return actualRepayAmount;
    }

    function liquidateBorrow(address borrower, LendTokenInterface lendTokenCollateral) external payable returns (uint) {
        return liquidateBorrowInternal(borrower, msg.value, lendTokenCollateral);
    }
    // Fallback function, sending Rei to contract will mint tokens
    receive() external payable {
        mintInternal(msg.value);
    }
    /**
     * @notice The sender liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this lendToken to be liquidated
     * @param lendTokenCollateral The market in which to seize collateral from the borrower
     * @param repayAmount The amount of the underlying borrowed asset to repay
     */
    function liquidateBorrowInternal(address borrower, uint repayAmount, LendTokenInterface lendTokenCollateral) internal nonReentrant returns (uint) {
        //Interest must be update in this and Collateral lendToken
        accrueInterest();
        lendTokenCollateral.accrueInterest();

        address liquidator = msg.sender;

        /* Fail if liquidate not allowed */
        comptroller.liquidateBorrowAllowed(address(this), address(lendTokenCollateral), borrower, repayAmount);

        /* Verify lendTokenCollateral market's lastTimestamp equals current timestamp */
        if (lendTokenCollateral.accrualTimestamp() != block.timestamp) {
            revert ("TIME MISMATCH");
        }

        /* Fail if borrower = liquidator */
        if (borrower == liquidator) {
            revert ("CAN'T SELF LIQUIDATE");
        }

        /* Fail if repayAmount = 0 */
        if (repayAmount == 0) {
            revert ("Amount = 0");
        }

        /* Fail if repayAmount = -1 */
        if (repayAmount == type(uint).max) {
            revert ("AMOUNT is MAX value");
        }

        /* Fail if repayBorrow fails */
        uint actualRepayAmount = repayBorrowFresh(liquidator, borrower, repayAmount);

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /* We calculate the number of collateral tokens that will be seized */
        uint seizeTokens = comptroller.liquidateCalculateSeizeTokens(address(this), address(lendTokenCollateral), actualRepayAmount);

        /* Revert if borrower collateral token balance < seizeTokens */
        require(lendTokenCollateral.balanceOf(borrower) >= seizeTokens, "LIQUIDATE_SEIZE_TOO_MUCH");

        // If this is also the collateral, run seizeInternal to avoid re-entrancy, otherwise make an external call
        if (address(lendTokenCollateral) == address(this)) {
            seizeInternal(address(this), liquidator, borrower, seizeTokens);
        } else {
            lendTokenCollateral.seize(liquidator, borrower, seizeTokens);
        }


        /* We emit a LiquidateBorrow event */
        emit LiquidateBorrow(liquidator, borrower, actualRepayAmount, address(lendTokenCollateral), seizeTokens);

        return actualRepayAmount;
    }



    /**
     * @notice Transfers collateral tokens (this market) to the liquidator.
     * @dev Will fail unless called by another lendToken during the process of liquidation.
     *  Its absolutely critical to use msg.sender as the borrowed lendToken and not a parameter.
     * @param liquidator The account receiving seized collateral
     * @param borrower The account having collateral seized
     * @param seizeTokens The number of lendTokens to seize
     */
    function seize(address liquidator, address borrower, uint seizeTokens) external nonReentrant{
        // msg.sender pass the contract caller address to get allowance.
        // only Collateral LendToken OR aurumController which are listed in market can call and got allowed.
        seizeInternal(msg.sender, liquidator, borrower, seizeTokens);
    }

    /**
     * @notice Transfers collateral tokens (this market) to the liquidator.
     * @dev Called only during an in-kind liquidation, or by liquidateBorrow during the liquidation of another lendToken.
     *  Its absolutely critical to use msg.sender as the seizer lendToken and not a parameter.
     * @param seizerToken The contract seizing the collateral (i.e. borrowed lendToken)
     * @param liquidator The account receiving seized collateral
     * @param borrower The account having collateral seized
     * @param seizeTokens The number of lendTokens to seize
     */
    function seizeInternal(address seizerToken, address liquidator, address borrower, uint seizeTokens) internal{
        /* Fail if seize not allowed */
        comptroller.seizeAllowed(address(this), seizerToken, liquidator, borrower);

        /* Fail if borrower = liquidator */
        if (borrower == liquidator) {
            revert ("CAN'T SELF LIQUIDATE");
        }

        uint borrowerTokensNew;
        uint liquidatorTokensNew;

        /*
         * We calculate the new borrower and liquidator token balances, failing on underflow/overflow:
         *  borrowerTokensNew = accountTokens[borrower] - seizeTokens
         *  liquidatorTokensNew = accountTokens[liquidator] + seizeTokens
         */
        borrowerTokensNew = accountTokens[borrower] - seizeTokens;

        liquidatorTokensNew = accountTokens[liquidator] + seizeTokens;

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /* We write the previously calculated values into storage */
        accountTokens[borrower] = borrowerTokensNew;
        accountTokens[liquidator] = liquidatorTokensNew;

        /* Emit a Transfer event */
        emit Transfer(borrower, liquidator, seizeTokens);
    }

/*** Admin Functions ***/

    function _setAdmin(address newAdmin) external{
        // Check caller = admin
        if (msg.sender != admin) {
            revert("UNAUTHORIZED");
        }

        address oldAdmin = admin;
        admin = newAdmin;

        emit NewAdmin(oldAdmin, newAdmin);
    }

    // Fee rate
    function _setReserveFactor(uint newReserveFactorMantissa) external {
        //Only admin function
        require (msg.sender == admin,"Only admin function");
        accrueInterest();

        // Check newReserveFactor ≤ maxReserveFactor
        if (newReserveFactorMantissa > reserveFactorMaxMantissa) {
            revert ("Value greater than max");
        }

        uint oldReserveFactorMantissa = reserveFactorMantissa;
        reserveFactorMantissa = newReserveFactorMantissa;

        emit NewReserveFactor(oldReserveFactorMantissa, newReserveFactorMantissa);
    }

    function _setInterestRateModel(InterestRateModel newInterestRateModel) external {
        require (msg.sender == admin, "Only admin");

        accrueInterest();

        // _setInterestRateModelFresh emits interest-rate-model-update-specific logs on errors, so we don't need to.
        // Used to store old model for use in the event that is emitted on success
        InterestRateModel oldInterestRateModel;

        // Track the market's current interest rate model
        oldInterestRateModel = interestRateModel;

        // Ensure invoke newInterestRateModel.isInterestRateModel() returns true
        require(newInterestRateModel.isInterestRateModel(), "marker method returned false");

        // Set the interest rate model to newInterestRateModel
        interestRateModel = newInterestRateModel;

        // Emit NewMarketInterestRateModel(oldInterestRateModel, newInterestRateModel)
        emit NewMarketInterestRateModel(oldInterestRateModel, newInterestRateModel);
    }

    function _setComptroller(ComptrollerInterface newComptroller) external{
        require (msg.sender == admin, "Only admin");

        ComptrollerInterface oldComptroller = comptroller;
        // Ensure invoke comptroller.isComptroller() returns true
        require(newComptroller.isComptroller(), "marker method returned false");

        // Set market's comptroller to newComptroller
        comptroller = newComptroller;

        // Emit NewComptroller(oldComptroller, newComptroller)
        emit NewComptroller(oldComptroller, newComptroller);

    }

    function _reduceReserves(uint reduceAmount) external nonReentrant{
        if (msg.sender != admin) {
            revert("UNAUTHORIZED");
        }
        accrueInterest();
        // Fail gracefully if protocol has insufficient underlying cash
        if (getCashPrior() < reduceAmount) {
            revert ("INSUFFICIENT CASH");
        }

        // Check reduceAmount ≤ reserves[n] (totalReserves)
        if (reduceAmount > totalReserves) {
            revert ("INSUFFICIENT RESERVES");
        }

        // totalReserves - reduceAmount
        uint totalReservesNew;

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        totalReservesNew = totalReserves - reduceAmount;

        // Store reserves[n+1] = reserves[n] - reduceAmount
        totalReserves = totalReservesNew;

        emit ReservesReduced(admin, reduceAmount, totalReservesNew);
        // doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
        doTransferOut(admin, reduceAmount);
    }


/*** Safe Token ***/

    /**
     * @dev Similar to EIP20 transfer, except it handles a False result from `transferFrom` and reverts in that case.
     *      This will revert due to insufficient balance or insufficient allowance.
     *      This function returns the actual amount received,
     *      which may be less than `amount` if there is a fee attached to the transfer.
     *
     *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
     *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
     */
    function doTransferIn(address from, uint amount) internal returns (uint) {
        // Sanity checks
        require(msg.sender == from, "sender mismatch");
        require(msg.value == amount, "value mismatch");
        return amount;
    }

    /**
     * @dev Similar to EIP20 transfer, except it handles a False success from `transfer` and returns an explanatory
     *      error code rather than reverting. If caller has not called checked protocol's balance, this may revert due to
     *      insufficient cash held in this contract. If caller has checked protocol's balance prior to this call, and verified
     *      it is >= amount, this should not revert in normal conditions.
     *
     *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
     *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
     */
    function doTransferOut(address to, uint amount) internal {
        payable(to).transfer(amount);
    }


}