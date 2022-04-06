// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interface/ComptrollerInterface.sol";
import "./AURUM.sol";

/**
 * == == == AURUM DeFi == == ==
 * these contracts are modified from Venus's Contract
 * 
 */
contract AurumController is AurumControllerInterface {

    event NewComptroller(ComptrollerInterface oldComptroller, ComptrollerInterface newComptroller);
    event MintGOLD(address minter, uint mintGoldAmount);
    event RepayGOLD(address payer, address borrower, uint repayGoldAmount);
    event LiquidateGold(address liquidator, address borrower, uint repayAmount, address LendTokenCollateral, uint seizeTokens);
    event NewTreasuryGuardian(address oldTreasuryGuardian, address newTreasuryGuardian);
    event NewTreasuryAddress(address oldTreasuryAddress, address newTreasuryAddress);
    event NewTreasuryPercent(uint oldTreasuryPercent, uint newTreasuryPercent);
    event MintFee(address minter, uint feeAmount);
    event NewAURUMAddress(address oldAURUMAddress, address newAURUMAddress);


    uint public constant goldInitialIndex = 1e36;

    ComptrollerInterface public comptroller;
    address public admin;
    address public aurumAddress;    //Must be set

    struct AurumGOLDState {
        /// @notice The last updated aurumGOLDMintIndex
        uint index;
        /// @notice The timestamp the index was last updated at
        uint lastTimestamp;
    }

    AurumGOLDState public aurumGOLDState;

    mapping(address => uint) public aurumGOLDMinterIndex;

        /// @notice Treasury Guardian
    address public treasuryGuardian;        //Guardian address
    address public treasuryAddress;         //treasury address
    uint public treasuryPercent;         //Fee percent with decimal 18

    /// @notice Guard variable for re-entrancy checks
    bool internal _notEntered;
    
    address[] public goldMinterAddress;
    function getGoldMinter() external view returns(address[] memory){
        return goldMinterAddress;
    }
    mapping(address => bool) hasMinted;

    /*** Main Actions ***/

    struct MintLocalVars {
        uint mintAmount;
        uint accountMintGOLDNew;
        uint accountMintableGOLD;
    }

    constructor(address aurum_){
        admin = msg.sender;
        aurumAddress = aurum_;
        _notEntered = true;
        
        uint goldTimestamp = getTimestamp();
        aurumGOLDState = AurumGOLDState({
            index: goldInitialIndex,
            lastTimestamp: goldTimestamp
        });
    }

    function maxUINT() internal pure returns (uint) {
        uint number = type(uint).max;
        return number;
    }

    function mintGOLD(uint mintGOLDAmount) external nonReentrant {
        require(address(comptroller) != address(0),"Comptroller did not set");
        require(mintGOLDAmount > 0, "mintGOLDAmount can not be zero");
        require(!ComptrollerInterface(address(comptroller)).isProtocolPaused(), "protocol is paused");

        MintLocalVars memory vars;

        address minter = msg.sender;

        vars.accountMintableGOLD = getMintableGOLD(minter);

        // check that user have sufficient mintableGOLD balance
        require (mintGOLDAmount <= vars.accountMintableGOLD, "Insufficient credits");

        // accountMintGOLDNew = minted gold + newMinting gold
        vars.accountMintGOLDNew = ComptrollerInterface(address(comptroller)).getMintedGOLDs(minter) + mintGOLDAmount;

        //Set new Minted GOLD value
        comptroller.setMintedGOLDOf(minter, vars.accountMintGOLDNew);

        uint feeAmount;
        uint remainedAmount;
        vars.mintAmount = mintGOLDAmount;
        //Fee calculation
        if (treasuryPercent != 0) {
            feeAmount = vars.mintAmount * treasuryPercent;  // feeAmount now in EXP state
            feeAmount = feeAmount / 1e18;                   // feeAmount now in UINT state
            remainedAmount = vars.mintAmount - feeAmount;   // Amount after fee reduction

            AURUM(aurumAddress).mint(treasuryAddress, feeAmount);
            emit MintFee(minter, feeAmount);

        } else {
            remainedAmount = vars.mintAmount;
        }

        if(hasMinted[minter] == false){     // List minter to the ledger.
            hasMinted[minter] = true;
            goldMinterAddress.push(minter);
        }
        AURUM(aurumAddress).mint(minter, remainedAmount);

        emit MintGOLD(minter, remainedAmount);
    }


    /**
     * repayGOLD is to pay debt and burn GOLD token
     */
    function repayGOLD(uint repayGOLDAmount) external nonReentrant returns (uint) {
        require(address(comptroller) != address(0),"Comptroller not set");
        require(repayGOLDAmount > 0, "Amount is Zero");
        require(!ComptrollerInterface(address(comptroller)).isProtocolPaused(), "Protocol paused");

        uint actualBurnAmount = repayGOLDFresh(msg.sender, msg.sender, repayGOLDAmount);
        return actualBurnAmount;
    }
    // repayGOLD action is executed here
    function repayGOLDFresh(address payer, address borrower, uint repayAmount) internal returns (uint) {
        uint actualBurnAmount;
        uint goldBalanceBorrower = ComptrollerInterface(address(comptroller)).getMintedGOLDs(borrower);

        if(goldBalanceBorrower > repayAmount) { // Check the debt, if repay more than debt convert value to the actual debt value
            actualBurnAmount = repayAmount;
        } else {
            actualBurnAmount = goldBalanceBorrower;
        }

        //BURN token, reduce debt of AurumController, set debt of Comptroller
        AURUM(aurumAddress).burn(payer, actualBurnAmount);

        uint accountGOLDNew = goldBalanceBorrower - actualBurnAmount;

        comptroller.setMintedGOLDOf(borrower, accountGOLDNew);

        emit RepayGOLD(payer, borrower, actualBurnAmount);
        return actualBurnAmount;
    }


    // To liquidate must check if the borrower is in liquidatable position
    function liquidateGOLD(address borrower, uint repayAmount, LendTokenInterface lendTokenCollateral) external nonReentrant returns (uint) {
        require(!ComptrollerInterface(address(comptroller)).isProtocolPaused(), "protocol is paused");
        lendTokenCollateral.accrueInterest();  // Update Interest of collateral lend token to current interest.

        return liquidateGOLDFresh(msg.sender, borrower, repayAmount, lendTokenCollateral);
    }
    // Liquidate GOLD is executed here
    function liquidateGOLDFresh(address liquidator, address borrower, uint repayAmount, LendTokenInterface lendTokenCollateral) internal returns (uint) {
        require(address(comptroller) != address(0),"Comptroller not set");
        /* This function will revert if NOT ALLOWED */
        comptroller.liquidateBorrowAllowed(address(this), address(lendTokenCollateral), borrower, repayAmount);

        /* Verify lendTokenCollateral market's block number equals current block number */
        // it must be upgraded since external function was run :: accrueInterest()
        require(lendTokenCollateral.accrualTimestamp() == getTimestamp(),"accrualTimestamp not update");
        require(borrower != liquidator,"Borrower equal Liquidator");
        require(repayAmount != 0,"Repay amount is zero");
        /* Fail if repayAmount = -1 */
        if (repayAmount == maxUINT()) {
            revert("CLOSE_AMOUNT_IS_UINT_MAX");
        }

        // Liquidator should pay the GOLD for the liquidating borrower  then seize the borrower collateral token
        // 1. Liquidator must have GOLD for Repay the liquidating GOLD
        // 2. Borrower collateral will be seize and pay to liquidator (including fee calculation)

        // repay GOLD
        uint actualRepayAmount = repayGOLDFresh(liquidator, borrower, repayAmount);

        // Calculate the seize token amount
        uint seizeTokens = comptroller.liquidateGOLDCalculateSeizeTokens(address(lendTokenCollateral), actualRepayAmount);

        /* Revert if borrower collateral token balance < seizeTokens */
        if(lendTokenCollateral.balanceOf(borrower) < seizeTokens) {
            revert ("Too much seize tokens");
        }

        //Execute token seize
        lendTokenCollateral.seize(liquidator, borrower, seizeTokens);

        emit LiquidateGold(liquidator, borrower, actualRepayAmount, address(lendTokenCollateral), seizeTokens);

        return actualRepayAmount;
    }



    /*** Admin Functions ***/

    /**
      * @notice Sets a new comptroller
      * @dev Admin function to set a new comptroller
      */
    function _setComptroller(ComptrollerInterface comptroller_) external{
        // Check caller is admin
        require(msg.sender == admin, "Only Admin");

        ComptrollerInterface oldComptroller = comptroller;
        comptroller = comptroller_;
        emit NewComptroller(oldComptroller, comptroller_);
    }

    /**
     * @dev Local vars for avoiding stack-depth limits in calculating account total supply balance.
     *  Note that `lendTokenBalance` is the number of lendTokens the account owns in the market,
     *  whereas `borrowBalance` is the amount of underlying that the account has borrowed.
     */
    struct AccountAmountLocalVars {
        uint sumSupply;
        uint sumBorrowPlusEffects;
        uint lendTokenBalance;
        uint borrowBalance;
        uint exchangeRateMantissa;
        uint oraclePriceMantissa;
        uint goldPriceMantissa;
        uint tokensToDenom;
    }


    //This function determine the mintable GOLD in current position
    function getMintableGOLD(address minter) public view returns (uint) {
        address oracleAddress = ComptrollerInterface(address(comptroller)).getComptrollerOracleAddress();
        PriceOracle oracle = PriceOracle(oracleAddress);
        LendTokenInterface[] memory enteredMarkets = ComptrollerInterface(address(comptroller)).getAssetsIn(minter);

        AccountAmountLocalVars memory vars;

        uint accountMintableGOLD;
        uint i;

        // Get the gold price from oracle stored in var.goldPrice
        vars.goldPriceMantissa = oracle.getGoldPrice();
        if (vars.goldPriceMantissa == 0) {
            revert("GOLD oracle is zero");
        }

        /**
         * We use this formula to calculate mintable GOLD amount.
         * totalSupplyAmount * GOLDMintRate - (totalBorrowAmount + mintedGOLDOf)
         */
        for (i = 0; i < enteredMarkets.length; i++) {
            //Get snapshot for each entered markets
            (vars.lendTokenBalance, vars.borrowBalance, vars.exchangeRateMantissa) = enteredMarkets[i].getAccountSnapshot(minter);

            // Get the normalized price of the asset
            vars.oraclePriceMantissa = oracle.getUnderlyingPrice(enteredMarkets[i]);

            vars.tokensToDenom = vars.exchangeRateMantissa * vars.oraclePriceMantissa / 1e18;   // e18*e18/1e18 => e18
            vars.tokensToDenom *= vars.lendTokenBalance;                                        // e18*e18  => e36
            vars.tokensToDenom /= 1e18;                                                         // e36/e18 => e18
            
            vars.sumSupply += vars.tokensToDenom;

            // sumBorrowPlusEffects += oraclePrice * borrowBalance
            vars.sumBorrowPlusEffects = (vars.oraclePriceMantissa * vars.borrowBalance / 1e18) + vars.sumBorrowPlusEffects;
        }

        //---------------------- This formula modified  => GoldMinted * GoldOraclePrice------------------
        // sumBorrowPlusEffects += GoldMinted * GoldOraclePrice
        //
        vars.sumBorrowPlusEffects = (vars.goldPriceMantissa * ComptrollerInterface(address(comptroller)).getMintedGOLDs(minter) /1e18) + vars.sumBorrowPlusEffects;

        accountMintableGOLD = vars.sumSupply * ComptrollerInterface(address(comptroller)).getGoldMintRate();
        accountMintableGOLD /= 10000; // goldMintRate is percentage of total value, 100 = 1%, 10000 = 100%
        
        accountMintableGOLD -= vars.sumBorrowPlusEffects;

        accountMintableGOLD = accountMintableGOLD * 1e18 / vars.goldPriceMantissa; // turnn unit USD to GOLD

        return (accountMintableGOLD);
    }


    //
    //  set Treasury information
    //  TreasuryPercent is minting 'fee' 1e18 = 100%
    //
    function _setTreasuryData(address newTreasuryGuardian, address newTreasuryAddress, uint newTreasuryPercent) external{
        // Check caller is admin
        require(msg.sender == admin || msg.sender == treasuryGuardian,"Only admin or treasury guardian");
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

    function getTimestamp() public view returns (uint) {
        return block.timestamp;
    }

    /**
     * @notice Return the address of the AURUM GOLD token
     * @return The address of AURUM GOLD
     */
    function getAURUMAddress() public view returns (address) {
        return aurumAddress;
    }
    function _setAURUMAddress(address newAURUMAddress) external {
        require (msg.sender == admin, "Only admin");
        address oldAURUMAddress = aurumAddress;
        aurumAddress = newAURUMAddress;

        emit NewAURUMAddress(oldAURUMAddress,newAURUMAddress);
    }

    /*** Reentrancy Guard ***/

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     */
    modifier nonReentrant() {
        require(_notEntered, "re-entered");
        _notEntered = false;
        _;
        _notEntered = true; // get a gas-refund post-Istanbul
    }
}