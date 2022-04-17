import React, {Component} from "react"
import { useState } from "react"
import './css/AurumMinter.css'
import AURUMlogo from '../aurum.png'
import Loading from './Loading.js'
import Constructing from "./Constructing"
import Web3 from "web3"

const BigNumber = require('bignumber.js');
const e18 = 1000000000000000000
const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
// const secToYear = 60*60*24*365

const AurumMinterMain = (props) => {
    
    const [valueBorrow, setBorrow] = useState()
    const [valueRepay, setRepay] = useState()
    const floatRegExp = new RegExp('^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$')

    // let maxBorrow = props.maxBorrow.toFixed(6)
    // let safeBorrow = props.safeBorrow.toFixed(6)

    //Input manipulator
    const stakeAmountChange = (e) => {
        let oldAmount = valueBorrow;
        let newAmount = e.target.value
        let oldfloat = parseFloat(oldAmount)
        let newfloat = parseFloat(newAmount)
        let max = e.target.max
        if (floatRegExp.test(newAmount)){
            if(newfloat > max) {
                setBorrow(max)
            }else {
                if(newfloat===oldfloat){
                    if((newAmount.length<=2 && newAmount.charAt(newAmount.length-1) === '.') || newAmount.charAt(newAmount.length-1) === '0') {
                        if(newAmount==='00'){
                            setBorrow(0)
                        } else {
                            setBorrow(newAmount)
                        }
                    } else {
                        setBorrow(newAmount)
                    }
                } else {
                    setBorrow(newAmount)
                }
            }
        } else {
            if(newAmount===''){
                setBorrow('')
            } else {
                setBorrow(valueBorrow)
            }
        }
    }
    //Input manipulator
    const unstakeAmountChange = (e) => {
        let oldAmount = valueRepay;
        let newAmount = e.target.value
        let oldfloat = parseFloat(oldAmount)
        let newfloat = parseFloat(newAmount)
        let max = e.target.max
        if (floatRegExp.test(newAmount)){
            if(newfloat > max) {
                setRepay(max)
            }else {
                if(newfloat===oldfloat){
                    if((newAmount.length<=2 && newAmount.charAt(newAmount.length-1) === '.') || newAmount.charAt(newAmount.length-1) === '0') {
                        if(newAmount==='00'){
                            setRepay(0)
                        } else {
                            setRepay(newAmount)
                        }
                    } else {
                        setRepay(newAmount)
                    }
                } else {
                    setRepay(newAmount)
                }
            }
        } else {
            if(newAmount===''){
                setRepay('')
            } else {
                setRepay(valueRepay)
            }
        }
    }

    //
    //Smart contract interact function
    //
    const aurumApprove = () => {
        props.mainstate.comptrollerState.AURUM.methods.approve(props.mainstate.comptrollerState.aurumController._address, MAX_UINT).send({from: props.mainstate.account}).on('transactionHash', (hash) => {
            props.update()
        })
    }
    const borrow = () => {
        let amount
        amount = valueBorrow.toString()
        amount = Web3.utils.toWei(amount, 'Ether')
        props.mainstate.comptrollerState.aurumController.methods.mintGOLD(amount).send({from: props.mainstate.account}).on('transactionHash', (hash) => {
            props.update()
        })
    }
    const repay = () => {
        let amount
        amount = valueRepay.toString()
        amount = Web3.utils.toWei(amount, 'Ether')
        props.mainstate.comptrollerState.aurumController.methods.repayGOLD(amount).send({from: props.mainstate.account}).on('transactionHash', (hash) => {
            props.update()
        })
    }

    const setMaxBorrow = () => {
        setBorrow(maxMint)
    }
    // const setMaxSafeBorrow = () => {
    //     setBorrow(safeMint)
    // }
    const setMaxRepay = () => {
        if(parseFloat(mintedAurum) > parseFloat(goldBalance)) {
            setRepay(goldBalance)
        } else {
            setRepay(mintedAurum)
        }
    }
    const setMaxBalanceRepay = () => {
            setRepay(goldBalance)
    }

    const superState = props.mainstate
    // let totalBorrow = []
    let oraclePrice = []
    // let floatUserTotalBorrow
    // let floatUserTotalSupply
    let floatUserRemainingCredits

    let userTotalBorrow = new BigNumber(0)
    let userTotalSupply = new BigNumber(0)
    let userTotalCredits = new BigNumber(0)
    let userRemainingCredits = new BigNumber(0)
    let aurumCredits = new BigNumber(0)
    let i
    let danger = false
    //TotalBorrow --> sum (borrowBalanceStored)
    //TotalSupply --> sum (balanceOf * exchangeRateStored * oraclePrice)
    //RemainingCredits = sum (Credits) => Credit = Supply * CollateralFactor


    for(i = 0 ; i < superState.markets.length ; i++){
        let deltaTime = props.mainstate.time - superState.markets[i].accrualTimestamp
        // supplyBalance[i] = parseFloat(superState.markets[i].balanceOf)
        // supplyBalance[i] = parseFloat(supplyBalance[i] / 1e18)
        // borrowBalance[i] = parseFloat(superState.markets[i].borrowBalanceStored / e18)
        // totalBorrow[i] = parseFloat(superState.markets[i].totalBorrow) / e18
        // totalSupply[i] = parseFloat(parseFloat(superState.markets[i].totalBorrow) + superState.getCash - superState.totalReserves)
        oraclePrice[i] = parseFloat(superState.markets[i].underlyingPrice ) / e18

        // userTotalBorrow = BigNumber(superState.markets[i].borrowBalanceStored).times(superState.markets[i].exchangeRateStored).div(e18).times(oraclePrice[i]).plus(userTotalBorrow)

        userTotalSupply = BigNumber(superState.markets[i].balanceOf).times(oraclePrice[i]).plus(userTotalSupply)

        let thisBorrow = (BigNumber(superState.markets[i].borrowBalanceStored).div(e18).times(superState.markets[i].borrowRatePerSeconds).times(deltaTime) ).plus(superState.markets[i].borrowBalanceStored)
        thisBorrow = thisBorrow.times(oraclePrice[i])
        userTotalBorrow = userTotalBorrow.plus(thisBorrow)
        if(superState.markets[i].membership === true){
            aurumCredits = BigNumber(superState.markets[i].balanceOf).times(oraclePrice[i]).plus(aurumCredits)
            userTotalCredits = BigNumber(superState.markets[i].balanceOf).times(superState.markets[i].collateralFactorMantissa).times(oraclePrice[i]).div(e18).plus(userTotalCredits)
        }
    } 

    let mintedAurum = BigNumber(superState.comptrollerState.getMintedGOLDs)
    let goldPrice = BigNumber(superState.price.goldPrice).div(e18).toFixed(2)

    let goldBalance = BigNumber(props.mainstate.comptrollerState.goldBalance).div(e18).toFixed(6,1)

    userTotalBorrow = userTotalBorrow.plus(  mintedAurum.times(goldPrice)  )

    mintedAurum = mintedAurum.div(e18).toFixed(6,1)


    if(isNaN(userTotalBorrow)) {userTotalBorrow = 0}
    if(isNaN(userTotalSupply)) {userTotalSupply = 0}
    if(isNaN(userTotalCredits)) {userTotalCredits = 0}

    userTotalBorrow = userTotalBorrow.integerValue().div(e18)
    userTotalSupply = userTotalSupply.integerValue().div(e18)
    userTotalCredits = userTotalCredits.integerValue().div(e18)
    aurumCredits = aurumCredits.div(e18).times(superState.comptrollerState.goldMintRate)
    aurumCredits = aurumCredits.minus(userTotalBorrow)
    userRemainingCredits = userTotalCredits.minus(userTotalBorrow) //Minting aurum use GoldMintRate to calculate
    
    // floatUserTotalBorrow = userTotalBorrow.toFormat(2)
    // floatUserTotalSupply = userTotalSupply.toFormat(2)
    floatUserRemainingCredits = userRemainingCredits.toFormat(2,1) //total Credits
    
    if(BigNumber(floatUserRemainingCredits).isLessThan(userTotalCredits.times(0.2)) && userTotalCredits.isGreaterThan(0)){
        danger = true;
    }
    
    if(aurumCredits.isLessThan(0)){
        aurumCredits = BigNumber(0)
    }
    
    // let totalAurum = 0
    let maxMint = (aurumCredits / goldPrice).toFixed(6,1)
    // safeMint = safeMint.toFixed(6)
    // let mCaps = goldPrice * totalAurum


    let borrowButton
    if (valueBorrow === '' || valueBorrow === null || isNaN(valueBorrow) || valueBorrow === '0'){
        borrowButton = <button className='button-inactive'>Mint</button>
    } else {
        borrowButton = <button className='button' onClick={borrow}>Mint</button>
    }

    let repayButton
    
    if( props.mainstate.comptrollerState.aurumAllowance === '0' || BigNumber(props.mainstate.comptrollerState.aurumAllowance).isLessThan(valueRepay) ){
        repayButton = <button className='button' onClick={aurumApprove}>Approve</button>
    } else {
        if (valueRepay === '' || valueRepay === null || isNaN(valueRepay) || valueRepay === '0'){
            repayButton = <button className='button-inactive'>Repay</button>
        } else {
            repayButton = <button className='button' onClick={repay}>Repay</button>
        } 
    }


    // const testFunction = () => {
        // set Rely === FINISHED
        // superState.comptrollerState.AURUM.methods.rely(superState.comptrollerState.aurumController._address).send({from: superState.account}).on('transactionHash', (hash) => {
        //     props.update()
        // })

        // set AURUM address  === FINISHED
        // console.log(superState.comptrollerState.AURUM._address)
        // superState.comptrollerState.aurumController.methods._setAURUMAddress(superState.comptrollerState.AURUM._address).send({from: superState.account}).on('transactionHash', (hash) => {
        //     props.update()
        // })

        // set Comptroller for aurumController
        // superState.comptrollerState.aurumController.methods._setComptroller(superState.comptrollerState.contract._address).send({from: superState.account}).on('transactionHash', (hash) => {
        //     props.update()
        // })

        // set aurumController for Comptroller
        // superState.comptrollerState.contract.methods._setAurumController(superState.comptrollerState.aurumController._address).send({from: superState.account}).on('transactionHash', (hash) => {
        //     props.update()
        // })

        // set GoldMintRate for CompStorage  // GOLDMintRate 10000 = 100%,  100= 1%
    //     superState.comptrollerState.storage.methods._setGOLDMintRate('5000').send({from: superState.account}).on('transactionHash', (hash) => {
    //         props.update()
    //     })
    // }


    return (
        <div className='mint-aurum'>


            {/* <button onClick={testFunction}>Test function 1</button> */}


            <div className='minting-box'>
                <div className='mint-topic'>
                    <h1>
                        AURUM <img src={AURUMlogo} alt='aurum' height='100vw' />
                    </h1>
                    <p>AURUM is synthetic asset which algorithmic pegged with real 'Gold' price in unit of USD/ troy ounce. Minter should have deposited assets to get 'Credits' for minting Aurum. </p>
                    <p style={{color: 'red'}}>Warning :: The collateral asset can be liquidated if the user position is in liquidatable position </p>

                </div>
                <div className='mint-information'>
                    <div className='mint-information-price'>
                        <h3>Gold Oracle Price</h3>
                        <p>$ {goldPrice} /Oz</p>
                    </div>
                    <div className='mint-information-goldMintRate'>
                        <h3>Mint limit</h3>
                        <p>{(superState.comptrollerState.goldMintRate * 100).toFixed(2)} %</p>
                    </div>
                    <div className={danger === true ? 'mint-information-credits-danger' : 'mint-information-credits'}>
                        <h3>Credits remaining</h3>
                        <p>$ {floatUserRemainingCredits}</p>
                    </div>
                    <div className='mint-information-aurumCredits'>
                        <h3>Aurum credits</h3>
                        <p>$ {aurumCredits.toFormat(2)}</p>
                    </div>
                </div>
                <div className='mint-action'>
                    <div className='mint-action-box'>
                        <div className='flex'>
                            <div className="mint-action-info">
                                <h3>Max mint</h3>
                                <p className={'maxbutton'} onClick={setMaxBorrow}>{maxMint}</p>
                            </div>
                            {/* <div className="mint-action-info">
                                <h3>Safe mint</h3>
                                <p className={'maxbutton'} onClick={setMaxSafeBorrow}>{safeMint}</p>
                            </div> */}
                        </div>
                        <div className="flex">    
                            <input 
                                type='text' 
                                className='input' 
                                value={valueBorrow}
                                placeholder='0'
                                max={maxMint}
                                onChange={stakeAmountChange}
                            />
                            {borrowButton}
                        </div>
                    </div>
                    <div className='mint-action-box'>
                        <div className='mint-action-detail'>
                            <div className="mint-action-info">
                                <h3>Minted AURUM</h3>
                                <p className={'maxbutton'} onClick={setMaxRepay}>{mintedAurum}</p>
                            </div>
                            <div className="mint-action-info">
                                <h3>Wallet Balance</h3>
                                <p className={'maxbutton'} onClick={setMaxBalanceRepay}>{goldBalance}</p>
                            </div>
                        </div>
                        <div className="flex">    
                            <input 
                                type='text' 
                                className='input' 
                                value={valueRepay}
                                placeholder='0'
                                max={goldBalance}
                                onChange={unstakeAmountChange}/>
                            {repayButton}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}

class AurumMinter extends Component{

    render() {
        let content    
    
        if(this.props.mainstate.loadedMarket === false || this.props.mainstate.loading === true){
            content = <Loading mainstate={this.props.mainstate}/>
            // content = <Constructing />
        }
        else {
            if(this.props.mainstate.networkId === 55556) {
                content = <AurumMinterMain mainstate={this.props.mainstate} update={this.props.updateWeb3}/>
            } else {
                content = <Constructing />
            }
        }
        return (
            <div>
                <div className='mainbox'>
                    {content}
                </div>
            </div>
        )
    }
}
export default AurumMinter