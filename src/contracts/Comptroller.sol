// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './interface/ComptrollerInterface.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

error MarketNotList();
error InsufficientLiquidity();
error PriceError();
error NotLiquidatePosition();
error AdminOnly();
error ProtocolPaused();

contract Comptroller is ComptrollerInterface {

    event NewAurumController(AurumControllerInterface oldAurumController, AurumControllerInterface newAurumController);
    event NewComptrollerCalculation(ComptrollerCalculation oldComptrollerCalculation, ComptrollerCalculation newComptrollerCalculation);
    event NewTreasuryGuardian(address oldTreasuryGuardian, address newTreasuryGuardian);
    event NewTreasuryAddress(address oldTreasuryAddress, address newTreasuryAddress);
    event NewTreasuryPercent(uint oldTreasuryPercent, uint newTreasuryPercent);
    event ARMGranted(address recipient, uint amount);
    event NewPendingAdmin (address oldPendingAdmin,address newPendingAdmin);
    event NewAdminConfirm (address oldAdmin, address newAdmin);
    event DistributedGOLDVault(uint amount);

    //  Variables declaration
    //
    address admin;
    address pendingAdmin;
    ComptrollerStorage public compStorage;
    ComptrollerCalculation public compCalculate;
    AurumControllerInterface public aurumController;

    address public treasuryGuardian;        //Guardian of the treasury
    address public treasuryAddress;         //Wallet Address
    uint256 public treasuryPercent;         //Fee in percent of accrued interest with decimal 18 , This value is used in liquidate function of each LendToken
    
    bool internal locked;   // reentrancy Guardian



    constructor(ComptrollerStorage compStorage_) {
        admin = msg.sender;
        compStorage = compStorage_;       //Bind storage to the comptroller contract.
        locked = false;     // reentrancyGuard Variable
    }


    //
    //  Get parameters function
    //

    function isComptroller() external pure returns(bool){   // double check the contract
        return true;
    }
    function isProtocolPaused() external view returns(bool) {
        return compStorage.protocolPaused();
    }
    function getMintedGOLDs(address minter) external view returns(uint) {   // The ledger of user's AURUM minted is stored in ComptrollerStorage contract.
        return compStorage.getMintedGOLDs(minter);
    }
    function getComptrollerOracleAddress() external view returns(address) {  
        return address(compStorage.oracle());
    }
    function getAssetsIn(address account) external view returns (LendTokenInterface[] memory) {
        return compStorage.getAssetsIn(account);
    }
    function getGoldMintRate() external view returns (uint) {
        return compStorage.goldMintRate();
    }
    function addToMarket(LendTokenInterface lendToken) external{
        compStorage.addToMarket(lendToken, msg.sender);
    }
    function exitMarket(address lendTokenAddress) external{
        LendTokenInterface lendToken = LendTokenInterface(lendTokenAddress);
        /* Get sender tokensHeld and borrowBalance from the lendToken */
        (uint tokensHeld, uint borrowBalance, ) = lendToken.getAccountSnapshot(msg.sender);

        /* Fail if the sender has a borrow balance */
        if (borrowBalance != 0) {
            revert();
        }

        // if All of user's tokensHeld allowed to redeem, then it's allowed to UNCOLLATERALIZED.
        this.redeemAllowed(lendTokenAddress, msg.sender, tokensHeld);  

        // Execute change of state variable in ComptrollerStorage.
        compStorage.exitMarket(lendTokenAddress, msg.sender);
    }


    /*** Policy Hooks ***/

    // Check if the account be allowed to mint tokens
    // This check only
    // 1. Protocol not pause
    // 2. The lendToken is listed
    // Then update the reward SupplyIndex
    function mintAllowed(address lendToken, address minter) external{
        bool protocolPaused = compStorage.protocolPaused();
        if(protocolPaused){ revert ProtocolPaused(); }
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!compStorage.getMintGuardianPaused(lendToken), "mint is paused");

        if (!compStorage.isMarketListed(lendToken)) {
            revert MarketNotList();
        }

        // Keep the flywheel moving
        compStorage.updateARMSupplyIndex(lendToken);
        compStorage.distributeSupplierARM(lendToken, minter);
    }

    //
    //  Redeem allowed will check
    //      1. is the asset is list in market ?
    //      2. had the redeemer entered the market ?
    //      3. predict the value after redeem and check. if the loan is over (shortfall) then user can't redeem.
    //      4. if all pass then redeem is allowed.
    //

    function redeemAllowed(address lendToken, address redeemer, uint redeemTokens) external{
        bool protocolPaused = compStorage.protocolPaused();
        if(protocolPaused){ revert ProtocolPaused(); }
        if (!compStorage.isMarketListed(lendToken)) {         //Can't redeem the asset which not list in market.
            revert MarketNotList();
        }

        /* If the redeemer is not 'in' the market (this token not in collateral calculation), then we can bypass the liquidity check */
        if (!compStorage.checkMembership(redeemer, LendTokenInterface(lendToken)) ) {
            return ;
        }

        /* Otherwise, perform a hypothetical liquidity check to guard against shortfall */
        (, uint shortfall) = compCalculate.getHypotheticalAccountLiquidity(redeemer, lendToken, redeemTokens, 0);

        if (shortfall != 0) {
            revert InsufficientLiquidity();
        }

        compStorage.updateARMSupplyIndex(lendToken);
        compStorage.distributeSupplierARM(lendToken, redeemer);
    }

    //
    //  Borrow allowed will check
    //      1. is the asset listed in market ?
    //      2. if borrower not yet listed in market.accountMembership --> add the borrower in
    //      3. Check the price of oracle (is it still in normal status ?)
    //      4.1 Check borrow cap (if borrowing amount more than cap  it's not allowed)
    //      4.2 Predict the loan after borrow. if the loan is over (shortfall) then user can't borrow.
    //      5. if all pass, return no ERROR.
    //
    function borrowAllowed(address lendToken, address borrower, uint borrowAmount) external{
        bool protocolPaused = compStorage.protocolPaused();
        if(protocolPaused){ revert ProtocolPaused(); }
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!compStorage.getBorrowGuardianPaused(lendToken));

        if (!compStorage.isMarketListed(lendToken)) {
            revert MarketNotList();
        }
        if (!compStorage.checkMembership(borrower, LendTokenInterface(lendToken)) ) {
            // previously we check that 'lendToken' is one of the verify LendToken, so make sure that this function is called by the verified lendToken not ATTACKER wallet.
            require(msg.sender == lendToken, "sender must be lendToken");

            // the borrow token automatically addToMarket.
            compStorage.addToMarket(LendTokenInterface(lendToken), borrower);
        }

        if (compStorage.oracle().getUnderlyingPrice(LendTokenInterface(lendToken)) == 0) {
            revert PriceError();
        }

        uint borrowCap = compStorage.getBorrowCaps(lendToken);
        // Borrow cap of 0 corresponds to unlimited borrowing
        if (borrowCap != 0) {
            uint totalBorrows = LendTokenInterface(lendToken).totalBorrows();
            uint nextTotalBorrows = totalBorrows + borrowAmount;
            require(nextTotalBorrows < borrowCap, "borrow cap reached");     // if total borrow + pending borrow reach borrow cap --> error
        }
        uint shortfall;
        (, shortfall) = compCalculate.getHypotheticalAccountLiquidity(borrower, lendToken, 0, borrowAmount);
        if (shortfall != 0) {
            revert InsufficientLiquidity();
        }

        // Keep the flywheel moving
        uint borrowIndex = LendTokenInterface(lendToken).borrowIndex();
        compStorage.updateARMBorrowIndex(lendToken, borrowIndex);
        compStorage.distributeBorrowerARM(lendToken, borrower, borrowIndex);
    }
    
    //
    // repay is mostly allowed.  except the market is closed.
    //
    function repayBorrowAllowed(address lendToken, address borrower) external {
        bool protocolPaused = compStorage.protocolPaused();
        if(protocolPaused){ revert ProtocolPaused(); }

        if (!compStorage.isMarketListed(lendToken) ) {
            revert MarketNotList();
        }

        // Keep the flywheel moving
        uint borrowIndex = LendTokenInterface(lendToken).borrowIndex();
        compStorage.updateARMBorrowIndex(lendToken, borrowIndex);
        compStorage.distributeBorrowerARM(lendToken, borrower, borrowIndex);
    }

    //
    //  Liquidate allowed will check
    //      1. is market listed ?
    //      2. is the borrower currently shortfall ? (run predict function without borrowing or redeeming)
    //      3. calculate the max repayAmount by formula   borrowBalance * closeFactorMantissa (%)
    //      4. check if repayAmount > maximumClose   then revert.
    //      5. if all pass => allowed
    //
    function liquidateBorrowAllowed(address lendTokenBorrowed, address lendTokenCollateral, address borrower, uint repayAmount) external view{
        bool protocolPaused = compStorage.protocolPaused();
        if(protocolPaused){ revert ProtocolPaused(); }

        if (!(compStorage.isMarketListed(lendTokenBorrowed) || address(lendTokenBorrowed) == address(aurumController)) || !compStorage.isMarketListed(lendTokenCollateral) ) {
            revert MarketNotList();
        }
        /* The borrower must have shortfall in order to be liquidatable */
        (, uint shortfall) = compCalculate.getHypotheticalAccountLiquidity(borrower, address(0), 0, 0);

        if (shortfall == 0) {
            revert NotLiquidatePosition();
        }

        /* The liquidator may not repay more than what is allowed by the closeFactor */
        uint borrowBalance;

        if (address(lendTokenBorrowed) != address(aurumController)) {                   //aurumController is GOLD aurum minting control
            borrowBalance = LendTokenInterface(lendTokenBorrowed).borrowBalanceStored(borrower);
        } else {
            borrowBalance = compStorage.getMintedGOLDs(borrower);
        }

        uint maxClose = compStorage.closeFactorMantissa() * borrowBalance / 1e18;
        if (repayAmount > maxClose) {
            revert InsufficientLiquidity();
        }
    }


    //
    //  SeizeAllowed will check
    //      1. check the lendToken Borrow and Collateral both are listed in market (aurumController also can be lendTokenBorrowed address)    
    //         
    //      2. lendToken Borrow and Collateral are in the same market (Comptroller)
    //      3. if all pass => (allowed).
    //      
    //  lendTokenBorrowed is the called LendToken or aurumController.
    function seizeAllowed(address lendTokenCollateral, address lendTokenBorrowed, address liquidator, address borrower) external{
        bool protocolPaused = compStorage.protocolPaused();
        if(protocolPaused){ revert ProtocolPaused(); }
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!compStorage.seizeGuardianPaused());

        // We've added aurumController as a borrowed token list check for seize
        if (!compStorage.isMarketListed(lendTokenCollateral) || !(compStorage.isMarketListed(lendTokenBorrowed) || address(lendTokenBorrowed) == address(aurumController))) {
            revert MarketNotList();
        }
        // Check Borrow and Collateral in the same market (comptroller).
        if (LendTokenInterface(lendTokenCollateral).comptroller() != LendTokenInterface(lendTokenBorrowed).comptroller()) {
            revert();
        }

        // Keep the flywheel moving
        compStorage.updateARMSupplyIndex(lendTokenCollateral);
        compStorage.distributeSupplierARM(lendTokenCollateral, borrower);
        compStorage.distributeSupplierARM(lendTokenCollateral, liquidator);
    }

    //
    //  TransferAllowed is simply automatic allowed when redeeming is allowed (redeeming then transfer)
    //  So just check if this token is redeemable ?
    //
    function transferAllowed(address lendToken, address src, address dst, uint transferTokens) external {
        bool protocolPaused = compStorage.protocolPaused();
        if(protocolPaused){ revert ProtocolPaused(); }
        // Pausing is a very serious situation - we revert to sound the alarms
        require(!compStorage.transferGuardianPaused());

        // Currently the only consideration is whether or not
        //  the src is allowed to redeem this many tokens
        this.redeemAllowed(lendToken, src, transferTokens);

        // Keep the flywheel moving
        compStorage.updateARMSupplyIndex(lendToken);
        compStorage.distributeSupplierARM(lendToken, src);
        compStorage.distributeSupplierARM(lendToken, dst);
    }

    /*** Liquidity/Liquidation Calculations ***/
    //  Calculating function in ComptrollerCalculation contract

    function liquidateCalculateSeizeTokens(address lendTokenBorrowed, address lendTokenCollateral, uint actualRepayAmount) external view returns (uint) {
        return compCalculate.liquidateCalculateSeizeTokens(lendTokenBorrowed, lendTokenCollateral, actualRepayAmount);
    }

    function liquidateGOLDCalculateSeizeTokens(address lendTokenCollateral, uint actualRepayAmount) external view returns (uint) {
        return compCalculate.liquidateGOLDCalculateSeizeTokens(lendTokenCollateral, actualRepayAmount);
    }



    //
    /*** Admin Functions ***/
    //

    function _setPendingAdmin(address newPendingAdmin) external {
        if(msg.sender != admin) { revert AdminOnly();}
        address oldPendingAdmin = pendingAdmin;
        pendingAdmin = newPendingAdmin;

        emit NewPendingAdmin (oldPendingAdmin, newPendingAdmin);
    }

    function _confirmNewAdmin() external {
        if(msg.sender != admin) { revert AdminOnly();}
        address oldAdmin = admin;
        address newAdmin = pendingAdmin;
        admin = pendingAdmin;
        //Also set ComptrollerStorage's new admin to the same as comptroller.
        compStorage._setNewStorageAdmin(newAdmin);

        emit NewAdminConfirm (oldAdmin, newAdmin);
    }
    
    function _setAurumController(AurumControllerInterface aurumController_) external{
        if(msg.sender != admin) { revert AdminOnly();}

        AurumControllerInterface oldRate = aurumController;
        aurumController = aurumController_;
        emit NewAurumController(oldRate, aurumController_);
    }


    function _setTreasuryData(address newTreasuryGuardian, address newTreasuryAddress, uint newTreasuryPercent) external{
        if (!(msg.sender == admin || msg.sender == treasuryGuardian)) { revert AdminOnly(); }

        require(newTreasuryPercent < 1e18, "treasury percent cap overflow");

        address oldTreasuryGuardian = treasuryGuardian;
        address oldTreasuryAddress = treasuryAddress;
        uint oldTreasuryPercent = treasuryPercent;

        treasuryGuardian = newTreasuryGuardian;
        treasuryAddress = newTreasuryAddress;
        treasuryPercent = newTreasuryPercent;

        emit NewTreasuryGuardian(oldTreasuryGuardian, newTreasuryGuardian);
        emit NewTreasuryAddress(oldTreasuryAddress, newTreasuryAddress);
        emit NewTreasuryPercent(oldTreasuryPercent, newTreasuryPercent);
    }


    function _setComptrollerCalculation (ComptrollerCalculation newCompCalculate) external {
        if(msg.sender != admin) { revert AdminOnly();}
        ComptrollerCalculation oldCompCalculate = compCalculate;
        compCalculate = newCompCalculate;

        emit NewComptrollerCalculation (oldCompCalculate, newCompCalculate);
    }

    // Claim ARM function

    function claimARMAllMarket(address holder) external {
        return claimARM(holder, compStorage.getAllMarkets());
    }

    function claimARM(address holder, LendTokenInterface[] memory lendTokens) public {
        this.claimARM(holder, lendTokens, true, true);
    }

    function claimARM(address holder, LendTokenInterface[] memory lendTokens, bool borrowers, bool suppliers) external {
        require (locked == false,"No reentrance"); //Reentrancy guard
        locked = true;
        for (uint i = 0; i < lendTokens.length; i++) {
            LendTokenInterface lendToken = lendTokens[i];
            require(compStorage.isMarketListed(address(lendToken)));
            uint armAccrued;
            if (borrowers) {
                // Update the borrow index of each lendToken in the storage of comptroller
                // Borrow index is the multiplier which gradually increase by the amount of interest (borrowRate)
                uint borrowIndex = lendToken.borrowIndex();
                compStorage.updateARMBorrowIndex(address(lendToken), borrowIndex);

                compStorage.distributeBorrowerARM(address(lendToken), holder, borrowIndex);
                armAccrued = compStorage.getArmAccrued(holder);
                compStorage.grantARM(holder, armAccrued);   //reward the user then set user's armAccrued to 0;
            }
            if (suppliers) { 
                compStorage.updateARMSupplyIndex(address(lendToken));
                compStorage.distributeSupplierARM(address(lendToken), holder);
                armAccrued = compStorage.getArmAccrued(holder);
                compStorage.grantARM(holder, armAccrued);
            }
        }
        locked = false;
    }


    /*** Aurum Distribution Admin ***/


    function _setAurumSpeed(LendTokenInterface lendToken, uint aurumSpeed) external {
        if(msg.sender != admin) { revert AdminOnly();}
        uint currentAurumSpeed = compStorage.getAurumSpeeds(address(lendToken));
        if (currentAurumSpeed != 0) {
            // note that ARM speed could be set to 0 to halt liquidity rewards for a market
            uint borrowIndex = lendToken.borrowIndex();
            compStorage.updateARMSupplyIndex(address(lendToken));
            compStorage.updateARMBorrowIndex(address(lendToken), borrowIndex);
        } else if (aurumSpeed != 0) {
            // Add the ARM market
            compStorage.addARMdistributionMarket(lendToken);
        }

        if (currentAurumSpeed != aurumSpeed) {
            compStorage.setAurumSpeed(lendToken, aurumSpeed);
        }
    }

    //Set the amount of GOLD had minted, this should be called by aurumController contract
    function setMintedGOLDOf(address owner, uint amount) external {
        require(msg.sender == address(aurumController));
        bool protocolPaused = compStorage.protocolPaused();
        if(protocolPaused){ revert ProtocolPaused(); }


        bool mintGOLDGuardianPaused = compStorage.mintGOLDGuardianPaused();
        bool repayGOLDGuardianPaused = compStorage.repayGOLDGuardianPaused();
        require(!mintGOLDGuardianPaused && !repayGOLDGuardianPaused, "GOLD is paused");

        
        compStorage.setMintedGOLD(owner,amount);
    }

}



contract ComptrollerCalculation {

    // no admin setting in this contract, 
    ComptrollerStorage compStorage;
    
    constructor(ComptrollerStorage _compStorage) {
        compStorage = _compStorage;
    }

    /*** Liquidity/Liquidation Calculations ***/

    /**
     * @dev Local vars for avoiding stack-depth limits in calculating account liquidity.
     *  Note that `lendTokenBalance` is the number of lendTokens the account owns in the market,
     *  whereas `borrowBalance` is the amount of underlying that the account has borrowed.
     */
    struct AccountLiquidityLocalVars {
        uint sumCollateral;
        uint sumBorrowPlusEffects;
        uint lendTokenBalance;
        uint borrowBalance;
        uint exchangeRateMantissa;
        uint oraclePriceMantissa;
        uint goldOraclePriceMantissa;
        uint tokensToDenom;
    }

    /**
     * @notice Determine the current account liquidity wrt collateral requirements
     * @return (possible error code (semi-opaque),
                account liquidity in excess of collateral requirements,
     *          account shortfall below collateral requirements)
     */
    function getAccountLiquidity(address account) external view returns (uint, uint) {
        (uint liquidity, uint shortfall) = getHypotheticalAccountLiquidityInternal(account, LendTokenInterface(address(0)), 0, 0);

        return (liquidity, shortfall);
    }

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param lendTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @return (possible error code (semi-opaque),
                hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements)
     */
    //
    //  This function will simulate the user's account after interact with a specify LendToken when increasing loan (Borrowing and Redeeming)
    //  How much liquidity left OR How much shortage will return.
    //      1. get each aset that the account participate in the market
    //      2. Sum up Collateral value (+), Borrow (-), Effect[BorrowMore, RedeemMore, Gold Minted] (-)
    //      3. Return liquidity if positive, Return shortage if negative.
    //
    function getHypotheticalAccountLiquidity(address account, address lendTokenModify, uint redeemTokens, uint borrowAmount) external view returns (uint, uint) {
        (uint liquidity, uint shortfall) = getHypotheticalAccountLiquidityInternal(account, LendTokenInterface(lendTokenModify), redeemTokens, borrowAmount);
        return (liquidity, shortfall);
    }

    function isShortage(address account) external view returns(bool){
        (,uint shortfall) = getHypotheticalAccountLiquidityInternal(account, LendTokenInterface(msg.sender), 0, 0);
        if(shortfall > 0){
            return true;
        } else {
            return false;
        }
    }
    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param lendTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @dev Note that we calculate the exchangeRateStored for each collateral lendToken using stored data,
     *  without calculating accumulated interest.
     * @return (hypothetical account liquidity in excess of collateral requirements,
     *          hypothetical account shortfall below collateral requirements)
     */
    function getHypotheticalAccountLiquidityInternal(
        address account,
        LendTokenInterface lendTokenModify,
        uint redeemTokens,
        uint borrowAmount) internal view returns (uint, uint) {

        AccountLiquidityLocalVars memory vars; // Holds all our calculation results

        vars.goldOraclePriceMantissa = compStorage.oracle().getGoldPrice();
        if (vars.goldOraclePriceMantissa == 0) {
            revert ("Gold price error");
        }

        // For each asset the account is in
        LendTokenInterface[] memory assets = compStorage.getAssetsIn(account);
        for (uint i = 0; i < assets.length; i++) {
            LendTokenInterface asset = assets[i];

            // Read the balances and exchange rate from the lendToken
            (vars.lendTokenBalance, vars.borrowBalance, vars.exchangeRateMantissa) = asset.getAccountSnapshot(account);


            uint collateralFactorMantissa = compStorage.getMarketCollateralFactorMantissa(address(asset));

            // Get the normalized price of the asset
            vars.oraclePriceMantissa = compStorage.oracle().getUnderlyingPrice(asset);
            if (vars.oraclePriceMantissa == 0) {
                revert("Oracle error");
            }

            // Pre-compute a conversion factor
            // Unit compensate = 1e18 :: (e18*e18 / e18) *e18 / e18 
            vars.tokensToDenom = (collateralFactorMantissa * vars.exchangeRateMantissa / 1e18) * vars.oraclePriceMantissa / 1e18;

            // sumCollateral += tokensToDenom * lendTokenBalance
            // Unit compensate = 1e18 :: (e18*e18 / e18)
            vars.sumCollateral += (vars.tokensToDenom * vars.lendTokenBalance / 1e18);

            // sumBorrowPlusEffects += oraclePrice * borrowBalance
            // Unit compensate = 1e18 :: (e18*e18 /e18)
            vars.sumBorrowPlusEffects += (vars.oraclePriceMantissa * vars.borrowBalance / 1e18);

            // Calculate effects of interacting with lendTokenModify
            if (asset == lendTokenModify) {
                // redeem effect
                // sumBorrowPlusEffects += tokensToDenom * redeemTokens
                // Unit compensate = 1e18
                vars.sumBorrowPlusEffects += (vars.tokensToDenom * redeemTokens / 1e18);

                // borrow effect
                // sumBorrowPlusEffects += oraclePrice * borrowAmount
                // Unit compensate = 1e18
                vars.sumBorrowPlusEffects += (vars.oraclePriceMantissa * borrowAmount / 1e18);
            }
        }

        //---------------------- This formula modified from VAI minted of venus contract to => GoldMinted * GoldOraclePrice------------------
        // sumBorrowPlusEffects += GoldMinted * GoldOraclePrice
        vars.sumBorrowPlusEffects += (vars.goldOraclePriceMantissa * compStorage.getMintedGOLDs(account) / 1e18);

        // These are safe, as the underflow condition is checked first
        if (vars.sumCollateral > vars.sumBorrowPlusEffects) {
            //Return remaining liquidity.
            return (vars.sumCollateral - vars.sumBorrowPlusEffects, 0);
        } else {
            //Return shortfall amount.
            return (0, vars.sumBorrowPlusEffects - vars.sumCollateral);
        }
    }


    /**
     * @notice Calculate number of tokens of collateral asset to seize given an underlying amount
     * @dev Used in liquidation (called in lendToken.liquidateBorrowFresh)
     * @param lendTokenBorrowed The address of the borrowed lendToken
     * @param lendTokenCollateral The address of the collateral lendToken
     * @param actualRepayAmount The amount of lendTokenBorrowed underlying to convert into lendTokenCollateral tokens
     * @return (errorCode, number of lendTokenCollateral tokens to be seized in a liquidation)
     */
    function liquidateCalculateSeizeTokens(address lendTokenBorrowed, address lendTokenCollateral, uint actualRepayAmount) external view returns (uint) {
        /* Read oracle prices for borrowed and collateral markets */
        uint priceBorrowedMantissa = compStorage.oracle().getUnderlyingPrice(LendTokenInterface(lendTokenBorrowed));
        uint priceCollateralMantissa = compStorage.oracle().getUnderlyingPrice(LendTokenInterface(lendTokenCollateral));
        if (priceBorrowedMantissa == 0 || priceCollateralMantissa == 0) {
            revert ("Oracle price error");
        }

        /*
         * Get the exchange rate and calculate the number of collateral tokens to seize:
         *  seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
         *  seizeTokens = seizeAmount / exchangeRate
         *   = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
         */
        uint exchangeRateMantissa = LendTokenInterface(lendTokenCollateral).exchangeRateStored(); // Note: reverts on error
        uint seizeTokens;

        // Numerator is 1e54    // *1e18 for calculating ratio into 1e18
        uint numerator = compStorage.liquidationIncentiveMantissa() * priceBorrowedMantissa * 1e18;
        // Denominator is 1e36
        uint denominator = priceCollateralMantissa * exchangeRateMantissa;
        // Ratio is 1e18
        uint ratioMantissa = numerator / denominator;

        seizeTokens = ratioMantissa * actualRepayAmount / 1e18;

        return seizeTokens;
    }

    /**
     * @notice Calculate number of tokens of collateral asset to seize given an underlying amount
     * @dev Used in liquidation (called in lendToken.liquidateBorrowFresh)
     * @param lendTokenCollateral The address of the collateral lendToken
     * @param actualRepayAmount The amount of lendTokenBorrowed underlying to convert into lendTokenCollateral tokens
     * @return (errorCode, number of lendTokenCollateral tokens to be seized in a liquidation)
     */
    function liquidateGOLDCalculateSeizeTokens(address lendTokenCollateral, uint actualRepayAmount) external view returns (uint) {
        /* Read oracle prices for borrowed and collateral markets */
        //The different to the previous function is only Borrow price oracle is GOLD price
        uint priceBorrowedMantissa = compStorage.oracle().getGoldPrice();  // get the current gold price feeding from oracle
        uint priceCollateralMantissa = compStorage.oracle().getUnderlyingPrice(LendTokenInterface(lendTokenCollateral));
        if (priceCollateralMantissa == 0 || priceBorrowedMantissa == 0) {
            revert ("Oracle price error");
        }

        /*
         * Get the exchange rate and calculate the number of collateral tokens to seize:
         *  seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
         *  seizeTokens = seizeAmount / exchangeRate
         *   = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
         */
        uint exchangeRateMantissa = LendTokenInterface(lendTokenCollateral).exchangeRateStored(); // Note: reverts on error
        uint seizeTokens;

        // Numerator is 1e54    // *1e18 for calculating ratio into 1e18
        uint numerator = compStorage.liquidationIncentiveMantissa() * priceBorrowedMantissa * 1e18;
        // Denominator is 1e36
        uint denominator = priceCollateralMantissa * exchangeRateMantissa;
        // Ratio is 1e18
        uint ratioMantissa = numerator / denominator;

        seizeTokens = ratioMantissa * actualRepayAmount / 1e18;

        return seizeTokens;
    }
}


contract ComptrollerStorage {

    event MarketListed(LendTokenInterface lendToken);
    event MarketEntered(LendTokenInterface lendToken, address account);
    event MarketExited(LendTokenInterface lendToken, address account);
    event NewCloseFactor(uint oldCloseFactorMantissa, uint newCloseFactorMantissa);
    event NewCollateralFactor(LendTokenInterface lendToken, uint oldCollateralFactorMantissa, uint newCollateralFactorMantissa);
    event NewLiquidationIncentive(uint oldLiquidationIncentiveMantissa, uint newLiquidationIncentiveMantissa);
    event AurumSpeedUpdated(LendTokenInterface indexed lendToken, uint newSpeed);
    event DistributedSupplierARM(LendTokenInterface indexed lendToken, address indexed supplier, uint aurumDelta, uint aurumSupplyIndex);
    event DistributedBorrowerARM(LendTokenInterface indexed lendToken, address indexed borrower, uint aurumDelta, uint aurumBorrowIndex);
    event NewGOLDMintRate(uint oldGOLDMintRate, uint newGOLDMintRate);
    event ActionProtocolPaused(bool state);
    event ActionTransferPaused(bool state);
    event ActionSeizePaused(bool state);
    event ActionMintPaused(address lendToken, bool state);
    event ActionBorrowPaused(address lendToken, bool state);
    event NewBorrowCap(LendTokenInterface indexed lendToken, uint newBorrowCap);
    event NewPriceOracle(PriceOracle oldPriceOracle, PriceOracle newPriceOracle);
    event MintGOLDPause(bool state);

    address public armAddress;
    address public comptrollerAddress;
    address public admin;
    PriceOracle public oracle;                              //stored contract of current PriceOracle (can be changed by _setPriceOracle function)
    function getARMAddress() external view returns(address) {return armAddress;}

    //
    // Liquidation variables
    //
    //Close factor is the % (in 1e18 value) of borrowing asset can be liquidate   e.g. if set 50% --> borrow 1000 USD, position can be liquidate maximum of 500 USD
    uint public closeFactorMantissa;                        //calculate the maximum repayAmount when liquidating a borrow   --> can be set by _setCloseFactor(uint)
    uint public liquidationIncentiveMantissa;               //multiplier that liquidator will receive after successful liquidate ; venus comptroller set up = 1100000000000000000 (1.1e18)


    //
    //  Pause variables
    //
    
    /**
     * @notice The Pause Guardian can pause certain actions as a safety mechanism.
     *  Actions which allow users to remove their own assets cannot be paused.
     *  Liquidation / seizing / transfer can only be paused globally, not by market.
     */
    bool public protocolPaused;
    bool public transferGuardianPaused;
    bool public seizeGuardianPaused;
    mapping(address => bool) public mintGuardianPaused;
    function getMintGuardianPaused(address lendTokenAddress) external view returns(bool){ return mintGuardianPaused[lendTokenAddress];}
    mapping(address => bool) public borrowGuardianPaused;
    function getBorrowGuardianPaused(address lendTokenAddress) external view returns(bool){ return borrowGuardianPaused[lendTokenAddress];}
    bool public mintGOLDGuardianPaused;
    bool public repayGOLDGuardianPaused;




    mapping(address => uint) public armAccrued;             //ARM accrued but not yet transferred to each user
    function getArmAccrued(address user) external view returns (uint) {return armAccrued[user];}

    //
    //  Aurum Gold controller 'AURUM token'
    //
    mapping(address => uint) public mintedGOLDs;        //minted Aurum GOLD amount to each user
    function getMintedGOLDs(address user) external view returns(uint) {return mintedGOLDs[user];}
    uint16 public goldMintRate;                           //GOLD Mint Rate (percentage)  value with two decimals 0-10000, 100 = 1%, 1000 = 10%,
    //
    //  ARM distribution variables
    //
    mapping(address => uint) public aurumSpeeds;        //The portion of aurumRate that each market currently receives
    function getAurumSpeeds(address lendToken) external view returns(uint) { return aurumSpeeds[lendToken];}

    //
    //  Borrow cap
    //
    mapping(address => uint) public borrowCaps;         //borrowAllowed for each lendToken address. Defaults to zero which corresponds to unlimited borrowing.
    function getBorrowCaps(address lendTokenAddress) external view returns (uint) { return borrowCaps[lendTokenAddress];}
    
    
    //
    // Market variables
    //
    mapping(address => LendTokenInterface[]) public accountAssets;   //stored each account's assets.
    function getAssetsIn(address account) external view returns (LendTokenInterface[] memory) {return accountAssets[account];}
    struct Market {
        bool isListed;                                      //Listed = true,  Not listed = false

        /**
         * @notice Multiplier representing the most one can borrow against their collateral in this market.
         *  For instance, 0.9 to allow borrowing 90% of collateral value.
         *  Must be between 0 and 1, and stored as a mantissa.
         */
        uint collateralFactorMantissa;

        mapping(address => bool) accountMembership;         //Each market mapping of "accounts in this asset"  similar to 'accountAssets' variable but the market side.
    }
    /**
     * @notice Official mapping of lendTokens -> Market metadata
     * @dev Used e.g. to determine if a market is supported
     */
    mapping(address => Market) public markets;              //Can be set by _supportMarket admin function.

    function checkMembership(address account, LendTokenInterface lendToken) external view returns (bool) {return markets[address(lendToken)].accountMembership[account];}
    function isMarketListed(address lendTokenAddress) external view returns (bool) {return markets[lendTokenAddress].isListed;}
    function getMarketCollateralFactorMantissa(address lendTokenAddress) external view returns (uint) {return markets[lendTokenAddress].collateralFactorMantissa;}

    struct TheMarketState {
        /// @notice The market's last updated aurumBorrowIndex or aurumSupplyIndex
        // index variable is in Double (1e36)  stored the last update index
        uint index;

        /// @notice The block number the index was last updated at
        uint lastTimestamp;
    }

    LendTokenInterface[] public allMarkets;                          //A list of all markets
    function getAllMarkets() external view returns(LendTokenInterface[] memory) {return allMarkets;}

    mapping(address => TheMarketState) public armSupplyState;     //market supply state for each market
    mapping(address => TheMarketState) public armBorrowState;     //market borrow state for each market

    //Individual index variables  will update once individual check allowed function (will lastly call distributeSupplier / distributeBorrower function) to the current market's index.
    mapping(address => mapping(address => uint)) public aurumSupplierIndex;     //supply index of each market for each supplier as of the last time they accrued ARM
    mapping(address => mapping(address => uint)) public aurumBorrowerIndex;     //borrow index of each market for each borrower as of the last time they accrued ARM

    /// @notice The portion of ARM that each contributor receives per block
    mapping(address => uint) public aurumContributorSpeeds;

    /// @notice Last block at which a contributor's ARM rewards have been allocated
    mapping(address => uint) public lastContributorBlock;
    

    /// @notice The initial Aurum index for a market
    uint224 constant armInitialIndex = 1e36;

    //
    //  CloseFactorMantissa guide
    //
    
    uint public constant closeFactorMinMantissa = 0.05e18;        // 0.05   // closeFactorMantissa must be strictly greater than this value   ** MIN  5%
    uint public constant closeFactorMaxMantissa = 0.9e18;         // 0.9    // closeFactorMantissa must not exceed this value                 ** MAX 90%
    uint public constant collateralFactorMaxMantissa = 0.9e18;    // 0.9    // No collateralFactorMantissa may exceed this value


    constructor(address _armAddress) {
        admin = msg.sender;
        armAddress = _armAddress;
        closeFactorMantissa = 0.5e18;
        liquidationIncentiveMantissa = 1.1e18;
    }





    //
    // Comptroller parameter change function
    // Require comptroller is msg.sender
    //
    modifier onlyComptroller {
        require (msg.sender == comptrollerAddress, "Only comptroller");
        _;
    }

    function _setNewStorageAdmin(address newAdmin) external onlyComptroller {
        admin = newAdmin;
    }

    /**
     * @notice Add the market to the borrower's "assets in" for liquidity calculations
     * @param lendToken The market to enter
     * @param borrower The address of the account to modify
     */
    function addToMarket(LendTokenInterface lendToken, address borrower) external onlyComptroller {
        Market storage marketToJoin = markets[address(lendToken)];

        if (!marketToJoin.isListed) {
            // market is not listed, cannot join
            revert ("MARKET_NOT_LISTED");
        }

        if (marketToJoin.accountMembership[borrower]) {
            // already joined
            return ;
        }

        // survived the gauntlet, add to list
        // NOTE: we store these somewhat redundantly as a significant optimization
        //  this avoids having to iterate through the list for the most common use cases
        //  that is, only when we need to perform liquidity checks
        //  and not whenever we want to check if an account is in a particular market
        marketToJoin.accountMembership[borrower] = true;
        accountAssets[borrower].push(lendToken);

        emit MarketEntered(lendToken, borrower);
    }

    //  To exitMarket.. Checking condition
    //      --user must not borrowing this asset, 
    //      --user is allowed to redeem all the tokens (no excess loan when hypotheticalLiquidityCheck)
    //  Action
    //      1.trigger boolean of user address of market's accountMembership to false
    //      2.delete userAssetList to this market.
    //
    function exitMarket(address lendTokenAddress, address user) external onlyComptroller{
        LendTokenInterface lendToken = LendTokenInterface(lendTokenAddress);

        Market storage marketToExit = markets[address(lendToken)];

        /* Return out if the sender is not ‘in’ the market */
        if (!marketToExit.accountMembership[user]) {
            return ;
        }

        /* Set lendToken account membership to false */
        delete marketToExit.accountMembership[user];

        /* Delete lendToken from the account’s list of assets */
        // In order to delete lendToken, copy last item in list to location of item to be removed, reduce length by 1
        LendTokenInterface[] storage userAssetList = accountAssets[user];
        uint len = userAssetList.length;
        uint i;
        for (i=0 ; i < len ; i++) {
            if (userAssetList[i] == lendToken) {    // found the deleting array
                userAssetList[i] = userAssetList[len - 1]; // move the last parameter in array to the deleting array
                userAssetList.pop();    //this function remove the last parameter and also reduce array length by 1
                break;  //break before i++ so if there is the asset list, 'i' must always lesser than 'len'
            }
        }

        // We *must* have found the asset in the list or our redundant data structure is broken
        assert(i < len);

        emit MarketExited(lendToken, user);
    }

    function setAurumSpeed(LendTokenInterface lendToken, uint aurumSpeed) external onlyComptroller {
        aurumSpeeds[address(lendToken)] = aurumSpeed;
        emit AurumSpeedUpdated(lendToken, aurumSpeed);
    }

    // This function is called by _setAurumSpeed admin function when starting distribute ARM reward (from aurumSpeed 0)
    // it will check the MarketState of this lendToken and set to InitialIndex
    function addARMdistributionMarket(LendTokenInterface lendToken) external onlyComptroller {
        // Add the ARM market
        Market storage market = markets[address(lendToken)];
        require(market.isListed == true, "aurum market is not listed");

        if (armSupplyState[address(lendToken)].index == 0 && armSupplyState[address(lendToken)].lastTimestamp == 0) {
            armSupplyState[address(lendToken)] = TheMarketState({
                index: armInitialIndex,
                lastTimestamp: block.timestamp
            });
        }


        if (armBorrowState[address(lendToken)].index == 0 && armBorrowState[address(lendToken)].lastTimestamp == 0) {
                armBorrowState[address(lendToken)] = TheMarketState({
                    index: armInitialIndex,
                    lastTimestamp: block.timestamp
                });
        }
    }

    //Update the ARM distribute to Supplier
    //This function update the armSupplyState
    function updateARMSupplyIndex(address lendToken) external onlyComptroller {
        TheMarketState storage supplyState = armSupplyState[lendToken];
        uint supplySpeed = aurumSpeeds[lendToken];
        uint currentTime = block.timestamp;
        uint deltaTime = currentTime - supplyState.lastTimestamp;

        if (deltaTime > 0 && supplySpeed > 0) {
            uint supplyTokens = LendTokenInterface(lendToken).totalSupply();
            uint armAcc = deltaTime * supplySpeed;
            // addingValue is e36
            uint addingValue;
            if (supplyTokens > 0){
                addingValue = armAcc * 1e36 / supplyTokens;  // calculate index and stored in Double 
            } else {
                addingValue = 0;
            }
            uint newindex = supplyState.index + addingValue;
            armSupplyState[lendToken] = TheMarketState({
                index: newindex,    // setting new updated index
                lastTimestamp: currentTime //and also timestamp
            });
        } else if (deltaTime > 0) {
            supplyState.lastTimestamp = currentTime;
        }
    }

    //Update the ARM distribute to Borrower
    //same as above function but interact with Borrower variables
    function updateARMBorrowIndex(address lendToken, uint marketBorrowIndex) external onlyComptroller {
        TheMarketState storage borrowState = armBorrowState[lendToken];
        uint borrowSpeed = aurumSpeeds[lendToken];
        uint currentTime = block.timestamp;
        uint deltaTime = currentTime - borrowState.lastTimestamp;
        if (deltaTime > 0 && borrowSpeed > 0) {
            //borrowAmount is 1e18  :: e18 * 1e18 / e18
            uint borrowAmount = LendTokenInterface(lendToken).totalBorrows() * 1e18 / marketBorrowIndex;
            uint armAcc = deltaTime * borrowSpeed;

            uint addingValue;
            if (borrowAmount > 0){
                addingValue = armAcc * 1e36 / borrowAmount;  // calculate index and stored in Double
            } else {
                addingValue = 0;
            }
            uint newindex = borrowState.index + addingValue;
            armBorrowState[lendToken] = TheMarketState({
                index: newindex,    // setting new updated index
                lastTimestamp: currentTime //and also timestamp
            });
        } else if (deltaTime > 0) {
            borrowState.lastTimestamp = currentTime;
        }
    }

    //Distribute function will update armAccrued depends on the State.index which update by  updateARM  function
    //armAccrued will later claim by claimARM function
    function distributeSupplierARM(address lendToken, address supplier) external onlyComptroller {
        TheMarketState storage supplyState = armSupplyState[lendToken];
        uint supplyIndex = supplyState.index; // stored in 1e36
        uint supplierIndex = aurumSupplierIndex[lendToken][supplier];  // stored in 1e36
        aurumSupplierIndex[lendToken][supplier] = supplyIndex;  // update the user's index to the current state

        if (supplierIndex == 0 && supplyIndex > 0) {    
        //This happen when first time minting lendToken (mintingAllowed function) 
        //or receiving a lendToken but currently don't have this token (transferAllowed function)
            supplierIndex = armInitialIndex; // 1e36
        }
        //Calculate the new accrued arm since last update
        uint deltaIndex = supplyIndex - supplierIndex;

        uint supplierTokens = LendTokenInterface(lendToken).balanceOf(supplier); //e18
        uint supplierDelta = supplierTokens * deltaIndex / 1e36;   //e18  :: e18*e36/ 1e36
        uint supplierAccrued = armAccrued[supplier] + supplierDelta;
        armAccrued[supplier] = supplierAccrued;
        emit DistributedSupplierARM(LendTokenInterface(lendToken), supplier, supplierDelta, supplyIndex);
    }


    function distributeBorrowerARM(address lendToken, address borrower, uint marketBorrowIndex) external onlyComptroller {
        TheMarketState storage borrowState = armBorrowState[lendToken];
        uint borrowIndex = borrowState.index;  // stored in 1e36
        uint borrowerIndex = aurumBorrowerIndex[lendToken][borrower];  // stored in 1e36
        aurumBorrowerIndex[lendToken][borrower] = borrowIndex;  // update the user's index to the current state

        if (borrowerIndex > 0) {
            uint deltaIndex = borrowIndex - borrowerIndex; // e36

            uint borrowerAmount = LendTokenInterface(lendToken).borrowBalanceStored(borrower) * 1e18 / marketBorrowIndex;  // e18
            uint borrowerDelta = borrowerAmount * deltaIndex / 1e36;  // e18 ::  e18 * e36 / 1e36
            uint borrowerAccrued = armAccrued[borrower] + borrowerDelta;
            armAccrued[borrower] = borrowerAccrued;
            emit DistributedBorrowerARM(LendTokenInterface(lendToken), borrower, borrowerDelta, borrowIndex);
        }
    }



    function grantARM(address user, uint amount) external onlyComptroller returns (uint) {
        IERC20 arm = IERC20(armAddress);
        uint armRemaining = arm.balanceOf(address(this)); // when the ARM reward pool is nearly empty, admin should manually turn aurum speed to 0
        //Treasury reserves will be used when there is human error in reward process.
        if (amount > 0 && amount <= armRemaining) {
            armAccrued[user] = 0;
            arm.transfer(user, amount);
            return 0;
        }
        return amount;
    }

    function setMintedGOLD(address owner, uint amount) external onlyComptroller{
        mintedGOLDs[owner] = amount;
    }

    //
    // Admin function
    //
    function _setComptrollerAddress (address newComptroller) external {
        require(msg.sender == admin, "Only admin");

        comptrollerAddress = newComptroller;
    }

    // Maximum % of borrowing position can be liquidated (stored in 1e18)
    function _setCloseFactor(uint newCloseFactorMantissa) external {
        // Check caller is admin
    	require(msg.sender == admin, "only admin can set close factor");

        uint oldCloseFactorMantissa = closeFactorMantissa;
        closeFactorMantissa = newCloseFactorMantissa;
        emit NewCloseFactor(oldCloseFactorMantissa, newCloseFactorMantissa);
    }


    function _setCollateralFactor(LendTokenInterface lendToken, uint newCollateralFactorMantissa) external{
        // Check caller is admin
        require(msg.sender == admin, "Only admin");

        // Verify market is listed
        Market storage market = markets[address(lendToken)];
        if (!market.isListed) {
            revert ("Market not listed");
        }

        // Check collateral factor <= 0.9
        uint highLimit = collateralFactorMaxMantissa;
        require (highLimit > newCollateralFactorMantissa);

        // If collateral factor != 0, fail if price == 0
        if (newCollateralFactorMantissa != 0 && oracle.getUnderlyingPrice(lendToken) == 0) {
            revert ("Fail price oracle");
        }

        // Set market's collateral factor to new collateral factor, remember old value
        uint oldCollateralFactorMantissa = market.collateralFactorMantissa;
        market.collateralFactorMantissa = newCollateralFactorMantissa;

        // Emit event with asset, old collateral factor, and new collateral factor
        emit NewCollateralFactor(lendToken, oldCollateralFactorMantissa, newCollateralFactorMantissa);
    }

    // LiquidativeIncentive is > 1.00
    // if set 1.1e18 means liquidator get 10% of liquidated position
    function _setLiquidationIncentive(uint newLiquidationIncentiveMantissa) external{
        // Check caller is admin
        require(msg.sender == admin, "Only admin");
        require(newLiquidationIncentiveMantissa >= 1e18,"value must greater than 1e18");

        // Save current value for use in log
        uint oldLiquidationIncentiveMantissa = liquidationIncentiveMantissa;

        // Set liquidation incentive to new incentive
        liquidationIncentiveMantissa = newLiquidationIncentiveMantissa;

        // Emit event with old incentive, new incentive
        emit NewLiquidationIncentive(oldLiquidationIncentiveMantissa, newLiquidationIncentiveMantissa);
    }

    
    // Add the market to the markets mapping and set it as listed
    function _supportMarket(LendTokenInterface lendToken) external{
        require(msg.sender == admin, "Only admin");

        if (markets[address(lendToken)].isListed) {
            revert ("Already list");
        }

        require (lendToken.isLendToken(),"Not lendToken"); // Sanity check to make sure its really a LendTokenInterface

        markets[address(lendToken)].isListed = true;
        markets[address(lendToken)].collateralFactorMantissa = 0;

        for (uint i = 0; i < allMarkets.length; i ++) {
            require(allMarkets[i] != lendToken, "Already added");
        }
        allMarkets.push(lendToken);

        emit MarketListed(lendToken);
    }

    //Set borrowCaps
    function _setMarketBorrowCaps(LendTokenInterface[] calldata lendTokens, uint[] calldata newBorrowCaps) external {
        require(msg.sender == admin, "Only admin");

        uint numMarkets = lendTokens.length;
        uint numBorrowCaps = newBorrowCaps.length;

        require(numMarkets != 0 && numMarkets == numBorrowCaps, "invalid input");

        for(uint i = 0; i < numMarkets; i++) {
            borrowCaps[address(lendTokens[i])] = newBorrowCaps[i];
            emit NewBorrowCap(lendTokens[i], newBorrowCaps[i]);
        }
    }



    /**
     * Set whole protocol pause/unpause state
     */
    function _setProtocolPaused(bool state) external {
        require(msg.sender == admin, "Only admin");
        protocolPaused = state;
        emit ActionProtocolPaused(state);
    }
    function _setTransferPaused(bool state) external {
        require(msg.sender == admin, "Only admin");
        transferGuardianPaused = state;
        emit ActionTransferPaused(state);
    }
    function _setSeizePaused(bool state) external {
        require(msg.sender == admin, "Only admin");
        seizeGuardianPaused = state;
        emit ActionSeizePaused(state);
    }

    function _setMintPaused(address lendToken, bool state) external {
        require(msg.sender == admin, "Only admin");
        mintGuardianPaused[lendToken] = state;
        emit ActionMintPaused(lendToken, state);
    }
    function _setBorrowPaused(address lendToken, bool state) external {
        require(msg.sender == admin, "Only admin");
        borrowGuardianPaused[lendToken] = state;
        emit ActionBorrowPaused(lendToken, state);
    }
    function _setMintGoldPause(bool state) external {
        require(msg.sender == admin, "Only admin");
        mintGOLDGuardianPaused = state;
        emit MintGOLDPause(state);
    }



    function _setGOLDMintRate(uint16 newGOLDMintRate) external{
        require(msg.sender == admin, "Only admin");
        // Input: 0-10000, percentage with 2 decimals
        // 1 = 0.01%
        // 100 = 1%
        // 10000 = 100%

        // Check caller is admin
        require (newGOLDMintRate > 0 && newGOLDMintRate <= 10000,"Mintable GOLD rate must value 0-10000");

        uint oldGOLDMintRate = goldMintRate;
        goldMintRate = newGOLDMintRate;
        emit NewGOLDMintRate(oldGOLDMintRate, newGOLDMintRate);
    }

    
    /**
      * @notice Sets a new price oracle for the comptroller
      * @dev Admin function to set a new price oracle
      */
    function _setPriceOracle(PriceOracle newOracle) external{
        // Check caller is admin
        require(msg.sender == admin, "Only admin");

        // Track the old oracle for the comptroller
        PriceOracle oldOracle = oracle;

        // Set comptroller's oracle to newOracle
        oracle = newOracle;

        // Emit NewPriceOracle(oldOracle, newOracle)
        emit NewPriceOracle(oldOracle, newOracle);
    }

    
    // function _setARMAddress(address newARMAddress) external{
    //     require (msg.sender == admin, "Only admin function");
    //     address oldARMAddress = armAddress;
    //     armAddress = newARMAddress;
    //     emit NewARMAddress(oldARMAddress, newARMAddress);
    // }


}