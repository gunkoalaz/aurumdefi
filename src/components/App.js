import React, {Component} from 'react';
import {BrowserRouter, Routes, Route} from "react-router-dom";

//Web components
import ParticleSettings from './ParticleSettings.js';
import Navbar from './Navbar.js';
import Header from './Header.js';
import Main from './Main.js';
import Lending from './Lending.js';
import AurumMinter from './AurumMinter.js';
import ArmVault from './ArmVault.js';
import Liquidate from './Liquidate.js';
import AdminInterface from './AdminInterface.js';
import MintTestTokens from './MintTestTokens.js';
import NoMatch from './NoMatch.js';

//Blockchain components
import Web3 from 'web3';
import ARM from '../truffle_abis/ARM.json';
import StakingARM from '../truffle_abis/StakingARM.json';
import Comptroller from '../truffle_abis/Comptroller.json';
import ComptrollerStorage from '../truffle_abis/ComptrollerStorage.json';
import ComptrollerCalculation from '../truffle_abis/ComptrollerCalculation.json';
import AurumController from '../truffle_abis/AurumController.json';
import AurumPriceOracle from '../truffle_abis/AurumOracleCentralized.json';
import LendToken from '../truffle_abis/LendToken.json';
import LendREI from '../truffle_abis/LendREI.json';
import AURUM from '../truffle_abis/AURUM.json';
import ERC20 from '../truffle_abis/ERC20.json';

// const e18 = 1000000000000000000
const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935";
const TREASURY = '0xa94E41461C508F227fdF061EB9a056A54678b93B';


const initialState = {
    account: '0x0',
    chainId: 0,
    networkId: 0,
    price: {armPrice: '0', goldPrice: '0'},
    markets: [] ,
    allShortage: [],
    comptrollerState: {},

    loadedMarket: false,
    loadedVault: false,
    loadingNow: 0,
    loading: true,
    autoupdate: false,
}

const networks = {
    TestnetRei: {
      chainId: `0x${Number(55556).toString(16)}`,
      chainName: "Rei - testnet",
      nativeCurrency: {
        name: "Rei coin",
        symbol: "tREI",
        decimals: 18
      },
      rpcUrls: ["https://rei-testnet-rpc.moonrhythm.io"],
      blockExplorerUrls: ["https://testnet.reiscan.com"]
    },
    Rei: {
      chainId: `0x${Number(55555).toString(16)}`,
      chainName: "REI chain",
      nativeCurrency: {
        name: "REI",
        symbol: "REI",
        decimals: 18
      },
      rpcUrls: [
        "https://rei-rpc.moonrhythm.io"
      ],
      blockExplorerUrls: ["https://reiscan.com"]
    },
    Local: {
        chainId: `0x${Number(1337).toString(16)}`,
        chainName: "localhost",
        nativeCurrency: {
          name: "Ethereum",
          symbol: "ETH",
          decimals: 18
        },
        rpcUrls: ["http://127.0.0.1:7545"],
        blockExplorerUrls: ["http://127.0.0.1"]
      },
};

const changeNetwork = async ({ networkName, setError }) => {
    try {
        if (!window.ethereum) throw new Error("No crypto wallet found");
        await window.ethereum.request({
            method: "wallet_addEthereumChain",
            params: [
                {
                ...networks[networkName]
                }
            ]
        });
    } 
    catch (err) {
        setError(err.message);
    }
};


class App extends Component {

    constructor(props){
        super(props)
        this.loadArmVault = this.loadArmVault.bind(this)
        this.loadComptroller = this.loadComptroller.bind(this)
        this.loadMarketsInfo = this.loadMarketsInfo.bind(this)
        this.loadLiquidateList = this.loadLiquidateList.bind(this)
        this.state = initialState;
    }

    
    componentWillUnmount() {
        // clearInterval(this.interval);
        // clearInterval(this.marketInterval);
    }
    async loadArmVault() {
        let res;
        try {
                const web3 = window.web3
                const networkId = await web3.eth.net.getId()
            // Load ARM data
            const armLoader = ARM.networks[networkId]
            const arm = new web3.eth.Contract(ARM.abi, armLoader.address)
            // Load stakingARM data
            const stakingARMLoader = StakingARM.networks[networkId]
            const stakingARM = new web3.eth.Contract(StakingARM.abi, stakingARMLoader.address)
            if(stakingARMLoader) {
                let stakingARMBalance = await stakingARM.methods.getStakingBalance(this.state.account).call()
                let getRewardRemaining = await stakingARM.methods.getRewardRemaining().call()
                let getRewardSpendingDuration = await stakingARM.methods.getRewardSpendingDuration().call()
                let getTotalStakedARM = await stakingARM.methods.getTotalStakedARM().call()
                let getRewardBalanceOf = await stakingARM.methods.getRewardBalanceOf(this.state.account).call()
                let armAllowanceToVault = await arm.methods.allowance(this.state.account, stakingARM._address).call()
                let getLastRewardTimestamp = await stakingARM.methods.getLastRewardTimestamp().call()
                let getAccRewardPerShare = await stakingARM.methods.getAccRewardPerShare().call()
                let armBalance = await arm.methods.balanceOf(this.state.account).call()
                
                let armVault = {
                    contract: stakingARM,
                    armContract: arm,
                    armBalance: armBalance.toString(),
                    getTotalStakedARM: getTotalStakedARM.toString(),
                    userStakingBalance: stakingARMBalance.toString(),
                    totalAvailableReward: getRewardRemaining.toString(),
                    rewardDistributionIndex: getRewardSpendingDuration.toString(),
                    getRewardBalanceOf: getRewardBalanceOf.toString(),
                    armAllowanceToVault: armAllowanceToVault.toString(),
                    getLastRewardTimestamp: getLastRewardTimestamp.toString(),
                    getAccRewardPerShare: getAccRewardPerShare.toString(),
                }
                this.setState({armVault})
            } else {
                window.alert('Error! no stakingARM contract found')
            }
        } catch (err) {
            console.log(err);
        }
        res = true;
        this.setState({loadedVault: true});
        return res;
    }
    async loadComptroller() {
        let res;
        try {
        const web3 = window.web3
        const networkId = await web3.eth.net.getId()
        // Load comptroller data
        const comptrollerLoader = Comptroller.networks[networkId]
        const comptrollerStorageLoader = ComptrollerStorage.networks[networkId]
        const comptrollerCalculationLoader = ComptrollerCalculation.networks[networkId]
        const AURUMLoader = AURUM.networks[networkId]
        const AurumControllerLoader = AurumController.networks[networkId]
        const armLoader = ARM.networks[networkId]
        let currentTime = parseInt(Date.now() / 1000)

            const comptroller = new web3.eth.Contract(Comptroller.abi, comptrollerLoader.address);
            const compStorage = new web3.eth.Contract(ComptrollerStorage.abi, comptrollerStorageLoader.address);
            const compCalculation = new web3.eth.Contract(ComptrollerCalculation.abi, comptrollerCalculationLoader.address);
            const aurum = new web3.eth.Contract(AURUM.abi, AURUMLoader.address)
            const aurumController = new web3.eth.Contract(AurumController.abi, AurumControllerLoader.address)
            const arm = new web3.eth.Contract(ARM.abi, armLoader.address)
            let isProtocolPaused = await comptroller.methods.isProtocolPaused().call()
            let goldMintRate = await compStorage.methods.goldMintRate().call()
            let getMintedGOLDs = await comptroller.methods.getMintedGOLDs(this.state.account).call()
            let goldBalance = await aurum.methods.balanceOf(this.state.account).call()
            let getAssetsIn = await comptroller.methods.getAssetsIn(this.state.account).call()
            let aurumAllowance = await aurum.methods.allowance(this.state.account, aurumController._address).call()
            let liquidationIncentive = await compStorage.methods.liquidationIncentiveMantissa().call()
            let closeFactor = await compStorage.methods.closeFactorMantissa().call()
            let getArmAccrued = await compCalculation.methods.getUpdateARMAccrued(this.state.account, currentTime).call()
            let totalMintedAURUM = await aurum.methods.totalSupply().call()
            let compARMBalance = await arm.methods.balanceOf(compStorage._address).call()
            let treasuryARMBalance = await arm.methods.balanceOf(TREASURY).call()

            let comptrollerState = {
                contract: comptroller,
                storage: compStorage,
                AURUM: aurum,
                aurumController: aurumController,
                isProtocolPaused: isProtocolPaused,
                goldMintRate: (goldMintRate / 10000),
                getMintedGOLDs: getMintedGOLDs.toString(),
                goldBalance: goldBalance.toString(),
                aurumAllowance: aurumAllowance.toString(),
                getAssetsIn: getAssetsIn,
                getArmAccrued: getArmAccrued,
                liquidationIncentive: liquidationIncentive,
                closeFactor: closeFactor,
                totalMintedAURUM: totalMintedAURUM,
                compARMBalance: compARMBalance,
                treasuryARMBalance: treasuryARMBalance,
            }
            res = true;
            this.setState({comptrollerState});
            
        } catch(err) {
            console.log('Fail load comptroller.' + err);
            res = false;
        }

        this.setState({autoupdate: false})
        return res;
    }
    async loadMarketsInfo() {
        let res;
        this.setState({autoupdate: true})
        try {
            const web3 = window.web3
            const networkId = await web3.eth.net.getId()

            // Load all LendToken data to markets[]

            const arm = new web3.eth.Contract(ARM.abi, ARM.networks[networkId].address)
            const compStorage = new web3.eth.Contract(ComptrollerStorage.abi, ComptrollerStorage.networks[networkId].address)
            const aurumPriceOracleLoader = AurumPriceOracle.networks[networkId]
            const aurumPriceOracle = new web3.eth.Contract(AurumPriceOracle.abi, aurumPriceOracleLoader.address)

            let armPrice = await aurumPriceOracle.methods.assetPrices(arm._address).call()
            let goldPrice = await aurumPriceOracle.methods.getGoldPrice().call()
            let price = {
                armPrice: armPrice.toString(),
                goldPrice: goldPrice.toString(),
            }
            this.setState({price})
            
            let markets = []
            let i
            let getAllMarkets = await compStorage.methods.getAllMarkets().call()

            this.setState({loadingNow: 50});
            for(i=0; i< getAllMarkets.length; i++) {
                    let lendToken = new web3.eth.Contract(LendToken.abi, getAllMarkets[i])
                    let name = await lendToken.methods.name().call();
                    let symbol = await lendToken.methods.symbol().call();
                    let decimals = await lendToken.methods.decimals().call();
                    let borrowRatePerSeconds = await lendToken.methods.borrowRatePerSeconds().call();
                    let supplyRatePerSeconds = await lendToken.methods.supplyRatePerSeconds().call();
                    let reserveFactorMantissa = await lendToken.methods.reserveFactorMantissa().call();
                    let accrualTimestamp = await lendToken.methods.accrualTimestamp().call();
                    let totalBorrows = await lendToken.methods.totalBorrows().call();
                    let totalReserves = await lendToken.methods.totalReserves().call();
                    let getCash = await lendToken.methods.getCash().call();
                    let exchangeRateStored = await lendToken.methods.exchangeRateStored().call();
                    let borrowAddress = await lendToken.methods.getBorrowAddress().call();
                    let balanceOf = await lendToken.methods.balanceOf(this.state.account).call();
                    let borrowBalanceStored = await lendToken.methods.borrowBalanceStored(this.state.account).call();
                    let collateralFactorMantissa = await compStorage.methods.getMarketCollateralFactorMantissa(lendToken._address).call();
                    let getUnderlyingPrice = await aurumPriceOracle.methods.getUnderlyingPrice(lendToken._address).call();
                    let borrowCaps = await compStorage.methods.getBorrowCaps(lendToken._address).call();
                    let membership = await compStorage.methods.checkMembership(this.state.account, lendToken._address).call();
                    let allowance = await lendToken.methods.allowance(this.state.account, lendToken._address).call();
                    let aurumSpeeds = await compStorage.methods.getAurumSpeeds(lendToken._address).call();
                    let mintPause = await compStorage.methods.getMintGuardianPaused(lendToken._address).call();
                    let borrowPause = await compStorage.methods.getBorrowGuardianPaused(lendToken._address).call();
        
                    //Underlying parameters
                    let underlyingAddress 
                    let underlying 
                    let underlyingBalance
                    let underlyingSymbol
                    let underlyingAllowance
                    if(symbol !== 'lendREI') {
                        underlyingAddress = await lendToken.methods.underlying().call()
                        underlying = new web3.eth.Contract(ERC20.abi, underlyingAddress)
                        underlyingSymbol = await underlying.methods.symbol().call()
                        underlyingBalance = await underlying.methods.balanceOf(this.state.account).call()
                        underlyingAllowance = await underlying.methods.allowance(this.state.account, lendToken._address).call()
                    } else {
                        lendToken = new web3.eth.Contract(LendREI.abi, getAllMarkets[i])
                        underlyingAddress = ''
                        underlying = ''
                        underlyingSymbol = 'REI'
                        underlyingBalance = await web3.eth.getBalance(this.state.account)
                        underlyingAllowance = MAX_UINT.toString()
                    }
        
                    let marketsInfo = {
                        index: parseInt(i),
                        contract: lendToken,
                        underlyingContract: underlying,
                        
                        borrowAddress: borrowAddress,
                        
                        name: name.toString(), 
                        symbol: symbol.toString(), 
                        underlyingSymbol: underlyingSymbol.toString(),
                        decimals: decimals.toString(), 
        
                        //Personal info
                        membership: membership,
                        balanceOf: balanceOf.toString(),
                        allowance: allowance.toString(),
                        underlyingAllowance: underlyingAllowance.toString(),
                        underlyingBalance: underlyingBalance.toString(),
                        borrowBalanceStored: borrowBalanceStored.toString(),
        
        
        
        
                        //Market calculating variables
                        borrowRatePerSeconds: borrowRatePerSeconds.toString(),
                        supplyRatePerSeconds: supplyRatePerSeconds.toString(),
                        reserveFactorMantissa: reserveFactorMantissa.toString(),
                        collateralFactorMantissa: collateralFactorMantissa.toString(),
                        accrualTimestamp: accrualTimestamp.toString(),
                        exchangeRateStored: exchangeRateStored.toString(),
                        underlyingPrice: getUnderlyingPrice.toString(),
                        
                        //Market variables
                        mintPause: mintPause,
                        borrowPause: borrowPause,
                        totalBorrows: totalBorrows.toString(),
                        totalReserves: totalReserves.toString(),
                        cash: getCash.toString(),
                        borrowCaps: borrowCaps.toString(),
        
                        aurumSpeeds: aurumSpeeds.toString(),
                    }
                    markets.push(marketsInfo)
                    this.setState({loadingNow: this.state.loadingNow+6});
            }
            res = true;
            this.setState({loadingNow: 100});
            this.setState({markets});
            this.setState({autoupdate: false})
        } catch {
            res = false;
            clearInterval(this.marketInterval)
            this.setState(initialState)
        }
        if( res === true ) {
            this.setState({loadedMarket: true})
            clearInterval(this.marketInterval);
            this.marketInterval = setInterval(
                async() => {
                    if(this.state.account !== '0x0') {
                        if(this.state.networkId === 55555 || this.state.networkId === 55556 || this.state.networkId === 5777){
                            this.updateWeb3();
                        }
                    }
                },
                5000
            )
        }
        return res;
    }

    async loadLiquidateList() {
        this.setState({loading: true})
        const web3 = window.web3
        const networkId = await web3.eth.net.getId()
        const compStorage = new web3.eth.Contract(ComptrollerStorage.abi, ComptrollerStorage.networks[networkId].address)
        const aurumController = new web3.eth.Contract(AurumController.abi, AurumController.networks[networkId].address)
        const compCalculate = new web3.eth.Contract(ComptrollerCalculation.abi, ComptrollerCalculation.networks[networkId].address)
        const aurumPriceOracle = new web3.eth.Contract(AurumPriceOracle.abi, AurumPriceOracle.networks[networkId].address)

        // Load all account borrow on each markets
        let i
        let allBorrower = []
        
        let getAllMarkets = await compStorage.methods.getAllMarkets().call()

        for(i=0; i< getAllMarkets.length; i++) {
            let lendToken = new web3.eth.Contract(LendToken.abi, getAllMarkets[i])
            let getBorrowAddress = await lendToken.methods.getBorrowAddress().call()
            let j
            for(j=0; j< getBorrowAddress.length; j++){
                if(!allBorrower.includes(getBorrowAddress[j])){
                    allBorrower.push(getBorrowAddress[j])
                }
            }

        }
        let getGoldMinter = await aurumController.methods.getGoldMinter().call()
        for(i=0; i< getGoldMinter.length; i++){
            if(!allBorrower.includes(getGoldMinter[i])){
                allBorrower.push(getGoldMinter[i])
            }
        }
        // this.setState({allBorrower: allBorrower})
        let isShortage = []
        // Check each borrower position
        for(i=0; i< allBorrower.length; i++){
            isShortage[i] = await compCalculate.methods.isShortage(allBorrower[i]).call()
        }
        Promise.all(isShortage).then( async(isShortage)=> {
            let allShortage = []
            for(i=0; i<allBorrower.length; i++){
                
                if(isShortage[i]){
                    
                    let markets = await compStorage.methods.getAssetsIn(allBorrower[i]).call()
                    let j
                    let borrowAsset = []
                    let collateralAsset = []
                    // Get info in each markets for liquidating Borrow and Balance
                    for(j=0; j<markets.length ; j++){
                        let lendToken = new web3.eth.Contract(LendToken.abi, markets[j])
                        let symbol = await lendToken.methods.symbol().call()
                        let borrowAmount = await lendToken.methods.borrowBalanceStored(allBorrower[i]).call()
                        let collateralAmount = await lendToken.methods.balanceOf(allBorrower[i]).call()
                        let exchangeRate = await lendToken.methods.exchangeRateStored().call()
                        let price = await aurumPriceOracle.methods.getUnderlyingPrice(lendToken._address).call()
                        let underlyingAddress 
                        let underlying 
                        let underlyingSymbol
                        if(symbol === 'lendREI'){
                            underlyingAddress = ''
                            underlying = ''
                            underlyingSymbol = 'REI'

                        } else {
                            underlyingAddress = await lendToken.methods.underlying().call()
                            underlying = new web3.eth.Contract(ERC20.abi, underlyingAddress)
                            underlyingSymbol = await underlying.methods.symbol().call()

                        }
                        if(borrowAmount > 0) {
                            borrowAsset.push({
                                asset: lendToken._address,
                                symbol: underlyingSymbol,
                                amount: borrowAmount,
                                price: price,
                            })
                        }
                        if(collateralAmount > 0) {
                            collateralAsset.push({
                                asset: lendToken._address,
                                symbol: symbol,
                                amount: collateralAmount,
                                price: price,
                                exchangeRate: exchangeRate,
                            })
                        }
                    }
                    let mintedGold = await compStorage.methods.getMintedGOLDs(allBorrower[i]).call()


                    let info = {
                        index: i,
                        borrower: allBorrower[i],
                        borrowAsset: borrowAsset,
                        collateralAsset: collateralAsset,
                        mintedGold: mintedGold,
                    }
                    allShortage.push(info)
                }
            }
            this.setState({allShortage})
            this.setState({loading: false})
        })
    }
    //
    // Common Web3 function
    //
    async loadWeb3() {
        let connect;
        if(window.ethereum){
            window.web3 = new Web3(window.ethereum)
            connect = true
            // const accounts = await window.ethereum.send('eth_requestAccounts');
        } else if(window.web3){
                window.web3 = new Web3(window.web3.currentProvider)
                connect = true
            }
            else {
                window.alert('No ethereum browser detected.')
                connect = false
            }
        return connect;
    }
    async loadBlockchainData() {
        const web3 = window.web3
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        let networkId = await web3.eth.net.getId()
        const chainId = await web3.eth.getChainId()
        this.setState({account: accounts[0], networkId: networkId, chainId: chainId})

        //Only allowed to load the data if the chainId is localhost
        //else switch the chain to BSC(testnet)
        if(chainId === 1337 || chainId === 55556 || chainId === 55555){
            let currentTime = parseInt(Date.now() / 1000)   //Compatible with blockchain timestamp
            this.setState({time: currentTime})
        } else {
            console.log("Wrong network")
        }
        return networkId;
    }

    //
    // Functions
    //
    updateWeb3 = async () => {
        // this.setState({loading: true})
        let res
        try {
            const comptroller = await this.loadComptroller()
            const armVault = this.loadArmVault()
            const markets = this.loadMarketsInfo()
            Promise.all([comptroller, armVault, markets]).then( (value) => 
                {
                    if(value[0] === true && value[1] === true && value[2] === true){
                        res = true;
                        this.setState({loading: false});
                    } else {
                        res = false;
                    }
    
                })
        } catch {
            res = false
        }
        return res
    }


    connectAurumDeFi = async () =>{
        clearInterval(this.marketInterval);
        const LoadWeb3 = await this.loadWeb3()
        if(LoadWeb3 === true) {
            this.setState({loadingNow: 10});
            let networkId = await this.loadBlockchainData()
            this.setState({loadingNow: 20});
            if(networkId === 5777 || networkId === 55556 || networkId === 55555){
                const web3load = this.updateWeb3()
                Promise.all([web3load]).then( (value)=> {
                    this.interval = setInterval(
                        async () => {
                            if(this.state.account !== '0x0' && this.state.loading === false && this.state.autoupdate === false) {
                                if(this.state.networkId === 55555 || this.state.networkId === 55556 || this.state.networkId === 5777){
                                    let currentTime = parseInt(Date.now() / 1000)
                                    this.setState({time: currentTime})
                                }
                            }
                        },
                        1000
                    )
                })
            } else {
                await changeNetwork({networkName: 'Rei'})
                this.connectAurumDeFi();
            }        
            
        }
    }

    disconnectAurumDeFi = async () =>{
        clearInterval(this.marketInterval);
        this.setState(initialState);
    }



    
    render() {
        if(window.ethereum) {
            window.ethereum.on('accountsChanged', (accounts) => {
                if(this.state.loading === false){
                    this.setState(initialState)
                    this.connectAurumDeFi();
                }
            })
            window.ethereum.on('chainChanged',  (networkId) => {
                if(this.state.loading === false){
                    this.setState(initialState)
                    this.connectAurumDeFi();
                }
            })
        }
        
        return(
            <div style={{height: '100vh'}}>
                <div style={{position: 'fixed'}}>
                    <ParticleSettings/>
                </div>
                <BrowserRouter>
                    <Navbar price={this.state.price} networkId={this.state.networkId}/>
                    <Header 
                        mainstate={this.state}
                        connectMetamask={this.connectAurumDeFi}
                        disconnectMetamask={this.disconnectAurumDeFi}
                    />
                    <Routes>
                        <Route path='/' element={<Main mainstate={this.state}/>} />
                        <Route path='/lending' element={<Lending mainstate={this.state} updateWeb3={this.updateWeb3}/>} />
                        <Route path='/aurum' element={<AurumMinter mainstate={this.state} updateWeb3={this.updateWeb3} />} />
                        <Route path='/armvault' element={<ArmVault mainstate={this.state} updateWeb3={this.updateWeb3}/>} />
                        <Route path='/liquidate' element={<Liquidate mainstate={this.state} updateWeb3={this.updateWeb3} loadLiquidateList={this.loadLiquidateList}/>} />
                        <Route path='/admin' element={<AdminInterface mainstate={this.state}/>} />
                        <Route path='/mint' element={<MintTestTokens mainstate={this.state}/>} />

                        <Route path='*' element={<NoMatch />} />
                    </Routes>
                </BrowserRouter>
            </div>

        )
    }
}

export default App;