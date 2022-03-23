const Tether = artifacts.require('Tether')
const BUSD = artifacts.require('BUSD')
const BTC = artifacts.require('BTC')
const ARM = artifacts.require('ARM')
const StakingARM = artifacts.require('StakingARM')
const Comptroller = artifacts.require('Comptroller')
const Aurum = artifacts.require('AURUM')
const AurumController = artifacts.require('AurumController')
const ComptrollerStorage = artifacts.require('ComptrollerStorage')
const ComptrollerCalculation = artifacts.require('ComptrollerCalculation')
const LendToken = artifacts.require('LendToken')
const LendREI = artifacts.require('LendREI')
const AurumInterestRateModel = artifacts.require('AurumInterestRateModel')
const AurumPriceOracle = artifacts.require('AurumPriceOracle')

module.exports = async function (deployer, network, accounts) {
    const owner = accounts[0]
    const user1 = accounts[1]
    const user2 = accounts[2]
    const devAddress = '0x1AF04eD8835eaE2ed5e6c481ef192a7895DC8116'
    await deployer.deploy(Tether)
    const tether = await Tether.deployed()
    await deployer.deploy(BUSD)
    const busd = await BUSD.deployed()
    await deployer.deploy(BTC)
    const bitcoin = await BTC.deployed()


    //Deploy essential component
    await deployer.deploy(ARM)      //Gov token
    const arm = await ARM.deployed()
    await deployer.deploy(Aurum)    //Gold pegged token
    const aurum = await Aurum.deployed()

    //Deploy Background contract
    await deployer.deploy(AurumInterestRateModel, '70000000000000000', '150000000000000000', '800000000000000000', '800000000000000000')
    const aurumInterestRateModel = await AurumInterestRateModel.deployed()
    await deployer.deploy(AurumPriceOracle)
    const aurumPriceOracle = await AurumPriceOracle.deployed()

    //Deploy Operating contract
    await deployer.deploy(StakingARM,arm.address,busd.address)  // Staking Token (ARM) , and Reward token (BUSD)
    const stakingARM = await StakingARM.deployed()
    await deployer.deploy(AurumController, aurum.address) // set Aurum address
    const aurumController = await AurumController.deployed()
    aurum.rely(aurumController.address, {from: owner})
    console.log('AURUM token set aurumController as a reliable contract')

    //Deploy comptroller and storage
    await deployer.deploy(ComptrollerStorage,arm.address)
    const compStorage = await ComptrollerStorage.deployed()
    await deployer.deploy(ComptrollerCalculation,compStorage.address)
    const compCalculate = await ComptrollerCalculation.deployed()
    await deployer.deploy(Comptroller,compStorage.address)
    const comptroller = await Comptroller.deployed()
    await compStorage._setComptrollerAddress(comptroller.address, {from: owner})
    console.log("compStorage has set the comptroller.")
    await compStorage._setPriceOracle(aurumPriceOracle.address, {from: owner})
    console.log("compStorage has set the price oracle.")
    await comptroller._setComptrollerCalculation(compCalculate.address, {from: owner})
    console.log("comptroller has set the compCalculate.")
    await aurumController._setComptroller(comptroller.address, {from: owner})
    await comptroller._setAurumController(aurumController.address, {from: owner})
    console.log("AurumController is bind to Comptroller")
    await compStorage._setGOLDMintRate('5000', {from: owner})
    console.log("GoldMintRate is set to 50%")

// Asset deploy

    //Deploy lendToken Contracts
    await deployer.deploy(LendREI, 'lendToken REI', 'lendREI', 18, aurumInterestRateModel.address, comptroller.address)
    const lendTokenREI = await LendREI.deployed()
    await deployer.deploy(LendToken, 'lendToken Bitcoin', 'lendBTC', 18, bitcoin.address, aurumInterestRateModel.address, comptroller.address)
    const lendTokenBTC = await LendToken.deployed()
    await deployer.deploy(LendToken, 'lendToken Tether USD', 'lendUSDT', 18, tether.address, aurumInterestRateModel.address, comptroller.address)
    const lendTokenUSDT = await LendToken.deployed()
    await deployer.deploy(LendToken, 'lendToken Binance-pegged USD', 'lendBUSD', 18, busd.address, aurumInterestRateModel.address, comptroller.address)
    const lendTokenBUSD = await LendToken.deployed()


    //Rei setup
    await compStorage._supportMarket(lendTokenREI.address, {from: owner})
    console.log("LendToken REI has been bind to comptroller.")
    await lendTokenREI._setReserveFactor('50000000000000000', {from: owner})
    console.log("Reserve factor is set")
    
    //BTC setup
    await compStorage._supportMarket(lendTokenBTC.address, {from: owner})
    console.log("LendToken BTC has been bind to comptroller.")
    await lendTokenBTC._setReserveFactor('50000000000000000', {from: owner})
    console.log("Reserve factor is set")

    //USDT setup
    await compStorage._supportMarket(lendTokenUSDT.address, {from: owner})
    console.log("LendToken USDT has been bind to comptroller.")
    await lendTokenUSDT._setReserveFactor('50000000000000000', {from: owner})
    console.log("Reserve factor is set")

    //BUSD setup
    await compStorage._supportMarket(lendTokenBUSD.address, {from: owner})
    console.log("LendToken BUSD has been bind to comptroller.")
    await lendTokenBUSD._setReserveFactor('50000000000000000', {from: owner})
    console.log("Reserve factor is set")


//After deploy all asset -- set price oracle
    //Set oracle price
    console.log("Setting oracle price")
    await aurumPriceOracle.setGoldPrice('2000000000000000000000', {from: owner})
    console.log("Gold Price is set")
    await aurumPriceOracle.setUnderlyingPrice(lendTokenUSDT.address, '1000000000000000000', {from: owner})
    console.log("USDT price is set")
    await aurumPriceOracle.setUnderlyingPrice(lendTokenBUSD.address, '1000000000000000000', {from: owner})
    console.log("BUSD price is set")
    await aurumPriceOracle.setUnderlyingPrice(lendTokenBTC.address, '40000000000000000000000', {from: owner})
    console.log("BTC price is set")
    await aurumPriceOracle.setDirectPrice(arm.address, '2500000000000000000', {from: owner})
    console.log("ARM price is set")


    // Set Collateral Factor (After set oracle)
    await compStorage._setCollateralFactor(lendTokenBTC.address, '800000000000000000', {from: owner})
    console.log("LendToken BTC has set CollateralFactor to 80%.")
    await compStorage._setCollateralFactor(lendTokenUSDT.address, '800000000000000000', {from: owner})
    console.log("LendToken USDT has set CollateralFactor to 80%.")
    await compStorage._setCollateralFactor(lendTokenBUSD.address, '800000000000000000', {from: owner})
    console.log("LendToken BUSD has set CollateralFactor to 80%.")
    await compStorage._setCollateralFactor(lendTokenREI.address, '800000000000000000', {from: owner})
    console.log("LendToken REI has set CollateralFactor to 80%.")




    //Transfer tokens
    await arm.transfer(compStorage.address, web3.utils.toWei('700000'), {from: owner})
    console.log("Transfer ARM token to compStorage.")
    await arm.transfer(devAddress, web3.utils.toWei('100000'), {from:owner})
    console.log("Transfer ARM token to address " + devAddress)
    await busd.transfer(stakingARM.address, web3.utils.toWei('1000000'), {from: owner})
    console.log("Transfer BUSD to the reward vault.")
    // await tether.transfer(accounts[1], web3.utils.toWei('100000'), {from: owner})
    // console.log("Transfer USDT to " + accounts[1])
    // await bitcoin.transfer(accounts[1], web3.utils.toWei('100'), {from: owner})
    // console.log("Transfer BTC to " + accounts[1])
    // await tether.transfer(accounts[2], web3.utils.toWei('100000'), {from: owner})
    // console.log("Transfer USDT to " + accounts[2])
    // await bitcoin.transfer(accounts[2], web3.utils.toWei('100'), {from: owner})
    // console.log("Transfer BTC to " + accounts[2])
    // await tether.transfer(accounts[3], web3.utils.toWei('100000'), {from: owner})
    // console.log("Transfer USDT to " + accounts[3])
    // await bitcoin.transfer(accounts[3], web3.utils.toWei('100'), {from: owner})
    // console.log("Transfer BTC to " + accounts[3])

}