const tBNB = artifacts.require('tBNB');
const tETH = artifacts.require('tETH');
const tKUB = artifacts.require('tKUB');
const tKUMA = artifacts.require('tKUMA');
const tNEAR = artifacts.require('tNEAR');
const tWREI = artifacts.require('tWREI');

const ARM = artifacts.require('ARM');
const StakingARM = artifacts.require('StakingARM');
const Comptroller = artifacts.require('Comptroller');
const Aurum = artifacts.require('AURUM');
const AurumController = artifacts.require('AurumController');
const ComptrollerStorage = artifacts.require('ComptrollerStorage');
const ComptrollerCalculation = artifacts.require('ComptrollerCalculation');
const LendToken = artifacts.require('LendToken');
const LendREI = artifacts.require('LendREI');
const AurumInterestRateModel = artifacts.require('AurumInterestRateModel');
// const AurumPriceOracle = artifacts.require('AurumPriceOracle');   Change to Centralized feed version.
const AurumOracleCentralized = artifacts.require('AurumOracleCentralized');

module.exports = async function (deployer, network, accounts) {

//Mainnet
    const WREI = '0x7539595ebdA66096e8913a24Cc3C8c0ba1Ec79a0';
    const KUMA = '0xbf2C56466213F553Fcf52810fE360dFe29E88471';
    const BUSD = '0xDD2bb4e845Bd97580020d8F9F58Ec95Bf549c3D9';
    const BNB  = '0xf8aB4aaf70cef3F3659d3F466E35Dc7ea10d4A5d';
    const NEAR = '0x1DE000831C053EA30f6B6760D9898d0bb830C1d9';
    const ETH  = '0xa969c32977589210E0234144410FB2d21867d215';
    const KUB  = '0x2eE5c5146368e4B2569b25E01Dcc9514757dA55e';


//Testnet
    // KUMA = '0x20c2aD0E490Da3070Ee3718F55C36BF7D7BAfd36'   //
    // ETH  = '0xf4a29654CaA42842138329154D3aF9921575b6c0'   //
    // BNB  = '0xB173e143F1FDC8f6bBAd9AD11322B7F0B53C7cd0'   //
    // NEAR = '0xDe9adfC9a5939F7cb92d8E42fBd18a3182E1A90e'   //
    // KUB  = '0xc749e8DC347064ee37555a3AD8B175636Fe23ca1'   //
    // WREI = '0xc36e5B0FDB4Ea9fBF045D46b4B4D9A5a88aa514e'   //


    const TreasuryWallet = '0xa94E41461C508F227fdF061EB9a056A54678b93B';
    const DevWallet  = '0x7419E1C2B7b473a418cC582aa40d8dfbb89b8224';
    const publicDead = '0xdead00000000000000000000000000000000dead';

    const owner = accounts[0];

    //TEST MOCKED TOKENs
    // await deployer.deploy(tWREI);      //Gov token
    // const wrei = await tWREI.deployed();
    // await deployer.deploy(tKUMA);      //Gov token
    // const kuma = await tKUMA.deployed();
    // await deployer.deploy(tBNB);      //Gov token
    // const bnb = await tBNB.deployed();
    // await deployer.deploy(tNEAR);      //Gov token
    // const near = await tNEAR.deployed();
    // await deployer.deploy(tETH);      //Gov token
    // const eth = await tETH.deployed();
    // await deployer.deploy(tKUB);      //Gov token
    // const kub = await tKUB.deployed();

    // const WREI = wrei.address;
    // const KUMA = kuma.address;
    // const BNB = bnb.address;
    // const NEAR = near.address;
    // const ETH = eth.address;
    // const KUB = kub.address;
    
    
    //Deploy essential component
    await deployer.deploy(ARM);      //Gov token
    const arm = await ARM.deployed();
    await deployer.deploy(Aurum);    //Gold pegged token
    const aurum = await Aurum.deployed();
    
    //Deploy Background contract
    await deployer.deploy(AurumInterestRateModel, '70000000000000000', '150000000000000000', '800000000000000000', '800000000000000000');
    const aurumInterestRateModel = await AurumInterestRateModel.deployed();
    await deployer.deploy(AurumOracleCentralized, WREI, KUMA);
    const oracle = await AurumOracleCentralized.deployed();
    
    //Deploy Operating contract
    // await deployer.deploy(StakingARM,arm.address,KUMA)  // Staking Token (ARM) , and Reward token (KUMA) /* Can it be Foodcourt LP ? */
    // const stakingARM = await StakingARM.deployed()
    await deployer.deploy(AurumController, aurum.address); // set Aurum address
    const aurumController = await AurumController.deployed();
    aurum.rely(aurumController.address, {from: owner});
    console.log('AURUM token set aurumController as a reliable contract');

    //Deploy comptroller and storage
    await deployer.deploy(ComptrollerStorage,arm.address);
    const compStorage = await ComptrollerStorage.deployed();
    await deployer.deploy(ComptrollerCalculation,compStorage.address);
    const compCalculate = await ComptrollerCalculation.deployed();
    await deployer.deploy(Comptroller,compStorage.address);
    const comptroller = await Comptroller.deployed();

    await compStorage._setComptrollerAddress(comptroller.address, {from: owner});
    console.log("compStorage has set the comptroller.");

    await compStorage._setPriceOracle(oracle.address, {from: owner});
    console.log("compStorage has set the price oracle.");

    await comptroller._setComptrollerCalculation(compCalculate.address, {from: owner});
    console.log("comptroller has set the compCalculate.");

    await aurumController._setComptroller(comptroller.address, {from: owner});
    await comptroller._setAurumController(aurumController.address, {from: owner});
    console.log("AurumController is bind to Comptroller");

    await compStorage._setGOLDMintRate('4000', {from: owner});
    console.log("GoldMintRate is set to 40%");

    await comptroller._setTreasuryData(TreasuryWallet, TreasuryWallet, web3.utils.toWei('0.0015','Ether'), {from: owner});
    console.log("Comptroller treasury is set to address " + TreasuryWallet);

    await aurumController._setTreasuryData(TreasuryWallet, TreasuryWallet, web3.utils.toWei('0.002','Ether'), {from: owner});
    console.log("AurumController treasury is set to address " + TreasuryWallet);


// Asset deploy

    //Deploy lendToken Contracts
    await deployer.deploy(LendREI, 'lendToken REI', 'lendREI', 18, aurumInterestRateModel.address, comptroller.address);
    const lendTokenREI = await LendREI.deployed();
    console.log("lendTokenREI address "+lendTokenREI.address);
    await deployer.deploy(LendToken, 'lendToken KUMA', 'lendKUMA', 18, KUMA, aurumInterestRateModel.address, comptroller.address);
    const lendTokenKUMA = await LendToken.deployed();
    console.log("lendTokenKUMA address "+lendTokenKUMA.address);
    await deployer.deploy(LendToken, 'lendToken BUSD', 'lendBUSD', 18, BUSD, aurumInterestRateModel.address, comptroller.address);
    const lendTokenBUSD = await LendToken.deployed();
    console.log("lendTokenBUSD address "+lendTokenBUSD.address);
    await deployer.deploy(LendToken, 'lendToken BNB (Binance)', 'lendBNB', 18, BNB, aurumInterestRateModel.address, comptroller.address);
    const lendTokenBNB = await LendToken.deployed();
    console.log("lendTokenBNB address "+lendTokenBNB.address);
    await deployer.deploy(LendToken, 'lendToken NEAR (Aurora)', 'lendNEAR', 18, NEAR, aurumInterestRateModel.address, comptroller.address);
    const lendTokenNEAR = await LendToken.deployed();
    console.log("lendTokenNEAR address "+lendTokenNEAR.address);
    await deployer.deploy(LendToken, 'lendToken ETH (Aurora)', 'lendETH', 18, ETH, aurumInterestRateModel.address, comptroller.address);
    const lendTokenETH = await LendToken.deployed();
    console.log("lendTokenETH address "+lendTokenETH.address);
    await deployer.deploy(LendToken, 'lendToken KUB (Bitkub)', 'lendKUB', 18, KUB, aurumInterestRateModel.address, comptroller.address);
    const lendTokenKUB = await LendToken.deployed();
    console.log("lendTokenKUB address "+lendTokenKUB.address);


    //Rei setup
    await compStorage._supportMarket(lendTokenREI.address, {from: owner});
    console.log("LendToken REI has been bind to comptroller.");
    // await lendTokenREI._setReserveFactor('200000000000000000', {from: owner});
    // console.log("Reserve factor is set 20%");
    
    //KUMA setup
    await compStorage._supportMarket(lendTokenKUMA.address, {from: owner});
    console.log("LendToken KUMA has been bind to comptroller.");
    await lendTokenKUMA._setReserveFactor('150000000000000000', {from: owner});
    console.log("Reserve factor is set 15%");

    //BUSD setup
    await compStorage._supportMarket(lendTokenBUSD.address, {from: owner});
    console.log("LendToken BUSD has been bind to comptroller.");
    await lendTokenBUSD._setReserveFactor('100000000000000000', {from: owner});
    console.log("Reserve factor is set 10%");
    
    //BNB setup
    await compStorage._supportMarket(lendTokenBNB.address, {from: owner});
    console.log("LendToken BNB has been bind to comptroller.");
    // await lendTokenBNB._setReserveFactor('200000000000000000', {from: owner});
    // console.log("Reserve factor is set 20%");

    //NEAR setup
    await compStorage._supportMarket(lendTokenNEAR.address, {from: owner});
    console.log("LendToken NEAR has been bind to comptroller.");
    // await lendTokenNEAR._setReserveFactor('200000000000000000', {from: owner});
    // console.log("Reserve factor is set 20%");

    //ETH setup
    await compStorage._supportMarket(lendTokenETH.address, {from: owner});
    console.log("LendToken ETH has been bind to comptroller.");
    // await lendTokenETH._setReserveFactor('200000000000000000', {from: owner});
    // console.log("Reserve factor is set 20%");

    //KUB setup
    await compStorage._supportMarket(lendTokenKUB.address, {from: owner});
    console.log("LendToken KUB has been bind to comptroller.");
    // await lendTokenKUB._setReserveFactor('200000000000000000', {from: owner});
    // console.log("Reserve factor is set 20%");


//After deploy all asset -- set price oracle
    //Initiate oracle price
    console.log("Initiating oracle price");
    await oracle.initializedGold(web3.utils.toWei('1900'), {from: owner});
    console.log("Gold Price is initialized");
    await oracle.initializedAsset(WREI, web3.utils.toWei('1'), {from: owner});
    console.log("WREI price is initialized");
    await oracle.initializedAsset(KUMA, web3.utils.toWei('1'), {from: owner});
    console.log("KUMA price is initialized");
    await oracle.initializedAsset(BUSD, web3.utils.toWei('1'), {from: owner});
    console.log("BUSD price is initialized");
    await oracle.initializedAsset(BNB, web3.utils.toWei('420'), {from: owner});
    console.log("BNB price is initialized");
    await oracle.initializedAsset(NEAR, web3.utils.toWei('15'), {from: owner});
    console.log("NEAR price is initialized");
    await oracle.initializedAsset(ETH, web3.utils.toWei('3400'), {from: owner});
    console.log("ETH price is initialized");
    await oracle.initializedAsset(KUB, web3.utils.toWei('8.5'), {from: owner});
    console.log("KUB price is initialized");


// Set Collateral Factor (After set oracle)
    await compStorage._setCollateralFactor(lendTokenREI.address,    '500000000000000000', {from: owner});
    console.log("LendToken REI has set CollateralFactor to 50%.");
    await compStorage._setCollateralFactor(lendTokenKUMA.address,   '700000000000000000', {from: owner});
    console.log("LendToken KUMA has set CollateralFactor to 70%.");
    await compStorage._setCollateralFactor(lendTokenBUSD.address,   '700000000000000000', {from: owner});
    console.log("LendToken BUSD has set CollateralFactor to 70%.");
    await compStorage._setCollateralFactor(lendTokenBNB.address,    '700000000000000000', {from: owner});
    console.log("LendToken BNB has set CollateralFactor to 70%.");
    await compStorage._setCollateralFactor(lendTokenNEAR.address,   '500000000000000000', {from: owner});
    console.log("LendToken NEAR has set CollateralFactor to 50%.");
    await compStorage._setCollateralFactor(lendTokenETH.address,    '700000000000000000', {from: owner});
    console.log("LendToken ETH has set CollateralFactor to 70%.");
    await compStorage._setCollateralFactor(lendTokenKUB.address,    '500000000000000000', {from: owner});
    console.log("LendToken KUB has set CollateralFactor to 50%.");




//Transfer tokens
    await arm.transfer(compStorage.address, web3.utils.toWei('7200000'), {from: owner});
    console.log("Transfer ARM token to compStorage.");
    await arm.transfer(DevWallet, web3.utils.toWei('800000'), {from: owner});
    console.log("Transfer ARM token to DevWallet.");
    await arm.transfer(TreasuryWallet, web3.utils.toWei('2000000'), {from: owner});
    console.log("Transfer ARM token to Treasury.");


// Pause protocol, manual setting everything before release
    // await compStorage._setProtocolPaused(true, {from: owner});
    // console.log("Protocol is currently pause.");
    await compStorage._setMintPaused(lendTokenREI.address, true, {from: owner});
    console.log("LendREI Minting is paused.")

// Lastly transfer admin to Dev (except oracle)
    await comptroller._setPendingAdmin(DevWallet, {from: owner});
    await comptroller._confirmNewAdmin({from: owner});  // This also set admin of compStorage.
    console.log("Set admin for Comptroller successful.");
    await aurumController._setAdmin(DevWallet, {from: owner});
    console.log("Set admin for AurumController.");
    await oracle._setAdmin(DevWallet, {from: owner});  //Manager not set yet (manager should be manual set later )
    console.log("Set admin for oracle successful.");
    
    await aurum.rely(DevWallet, {from: owner});    // Give authentication to DevWallet. In case changing the AurumController
    await aurum.deny(owner, {from: owner});
    console.log("Set admin for AURUM");

    await arm.transferOwnership(publicDead, {from: owner}); // bye bye ARM no more mint
    console.log("ARM admin is now public.");

    await lendTokenKUMA._setAdmin(DevWallet, {from: owner});
    console.log("Set admin for lendTokenKUMA.");
    await lendTokenBUSD._setAdmin(DevWallet, {from: owner});
    console.log("Set admin for lendTokenBUSD.");
    await lendTokenREI._setAdmin(DevWallet, {from: owner});
    console.log("Set admin for lendTokenREI.");
    await lendTokenBNB._setAdmin(DevWallet, {from: owner});
    console.log("Set admin for lendTokenBNB.");
    await lendTokenNEAR._setAdmin(DevWallet, {from: owner});
    console.log("Set admin for lendTokenNEAR.");
    await lendTokenETH._setAdmin(DevWallet, {from: owner});
    console.log("Set admin for lendTokenETH.");
    await lendTokenKUB._setAdmin(DevWallet, {from: owner});
    console.log("Set admin for lendTokenKUB.");


}