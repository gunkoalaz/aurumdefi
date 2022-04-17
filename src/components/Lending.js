import React, {Component} from 'react'
import { useState } from 'react'
import './css/Main.css'
import './css/Lending.css'
import './css/Toggleswitch.css'
import AssetList from './AssetList.js'
import Loading from './Loading.js'

const BigNumber = require('bignumber.js');
const e18 = 1000000000000000000
// const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935"


const Menu = (props) => {

    return (
        <div className='menu'>
            <button className={props.page === 'supply' ? 'menu-item-active' : 'menu-item-inactive'} onClick={props.changePageSupply} > Deposit/Withdraw </button>
            <button className={props.page === 'borrow' ? 'menu-item-active' : 'menu-item-inactive'} onClick={props.changePageBorrow} >  Borrow/Repay </button>
        </div>
    )
}

const MainLending = (props) => {


    const superState = props.mainstate
    // let totalBorrow = []
    let oraclePrice = []
    let floatUserTotalBorrow
    let floatUserTotalSupply
    let floatUserRemainingCredits

    let userTotalBorrow = new BigNumber(0)
    let userTotalSupply = new BigNumber(0)
    let userTotalCredits = new BigNumber(0)
    let userRemainingCredits = new BigNumber(0)
    let i
    let danger = false
    //TotalBorrow --> sum (borrowBalanceStored)
    //TotalSupply --> sum (balanceOf * exchangeRateStored * oraclePrice)
    //RemainingCredits = sum (Credits) => Credit = Supply * CollateralFactor
    const [page, setPage] = useState('supply')

    for(i = 0 ; i < superState.markets.length ; i++){
        let deltaTime = props.mainstate.time - superState.markets[i].accrualTimestamp
        // supplyBalance[i] = parseFloat(superState.markets[i].balanceOf)
        // supplyBalance[i] = parseFloat(supplyBalance[i] / 1e18)
        // borrowBalance[i] = parseFloat(superState.markets[i].borrowBalanceStored / e18)
        // totalBorrow[i] = parseFloat(superState.markets[i].totalBorrow) / e18
        // totalSupply[i] = parseFloat(parseFloat(superState.markets[i].totalBorrow) + superState.getCash - superState.totalReserves)
        oraclePrice[i] = parseFloat(superState.markets[i].underlyingPrice ) / e18

        // userTotalBorrow = BigNumber(superState.markets[i].borrowBalanceStored).times(oraclePrice[i]).plus(userTotalBorrow)

        let userPendingTotalSupply = BigNumber(superState.markets[i].balanceOf).times(superState.markets[i].exchangeRateStored).div(e18).times(oraclePrice[i]).times(deltaTime).times(superState.markets[i].supplyRatePerSeconds).div(e18)
        userTotalSupply = BigNumber(superState.markets[i].balanceOf).times(oraclePrice[i]).times(superState.markets[i].exchangeRateStored).div(e18).plus(userTotalSupply).plus(userPendingTotalSupply);

        let thisBorrow = (BigNumber(superState.markets[i].borrowBalanceStored).div(e18).times(superState.markets[i].borrowRatePerSeconds).times(deltaTime) ).plus(superState.markets[i].borrowBalanceStored)
        thisBorrow = thisBorrow.times(oraclePrice[i])
        userTotalBorrow = userTotalBorrow.plus(thisBorrow)
        if(superState.markets[i].membership === true){
            userTotalCredits = BigNumber(superState.markets[i].balanceOf).times(superState.markets[i].collateralFactorMantissa).times(oraclePrice[i]).div(e18).plus(userTotalCredits)
        }
    } 

    let mintedAurum = BigNumber(superState.comptrollerState.getMintedGOLDs)
    let goldPrice = BigNumber(superState.price.goldPrice).div(e18).toFixed(2)
    // let mintedAurumPosition = mintedAurum.times(goldPrice).div(e18)

    userTotalBorrow = userTotalBorrow.plus(  mintedAurum.times(goldPrice)  )

    if(isNaN(userTotalBorrow)) {userTotalBorrow = 0}
    if(isNaN(userTotalSupply)) {userTotalSupply = 0}
    if(isNaN(userTotalCredits)) {userTotalCredits = 0}

    userTotalBorrow = userTotalBorrow.div(e18)
    userTotalSupply = userTotalSupply.div(e18)
    userTotalCredits = userTotalCredits.div(e18)
    userRemainingCredits = userTotalCredits.minus(userTotalBorrow)

    if(userRemainingCredits.isLessThan(userTotalCredits.times(0.2)) && userTotalCredits.isGreaterThan(0)){
        danger = true;
    }
    floatUserTotalBorrow = userTotalBorrow.toFormat(2)
    floatUserTotalSupply = userTotalSupply.toFormat(2)
    floatUserRemainingCredits = userRemainingCredits.toFormat(2)
    
    if(userRemainingCredits.isLessThan(0)){
        userRemainingCredits = 0
    }

    function manualClaimReward() {
        props.mainstate.comptrollerState.contract.methods.claimARMAllMarket(props.mainstate.account).send({from: props.mainstate.account, gas: '1000000'}).on('transactionHash', (hash) => {
            props.updateWeb3();
        })
    }

    // const test = () => {
    //     let borrower = '0x818D7848dC308520b931e7ad9DC93A7C18dfe557'.toString()
    //     // superState.markets[0].contract.methods.liquidateBorrow(borrower, superState.markets[1].contract._address).send({from: superState.account, value: '200000000000000000000'}).on('transactionHash', (hash) => {
    //         superState.markets[2].contract.methods.liquidateBorrow(borrower, '1000000000000000000000', superState.markets[1].contract._address).send({from: superState.account}).on('transactionHash', (hash) => {
    //     })
    // }
    function changePageSupply() {
        setPage('supply')
    }
    function changePageBorrow() {
        setPage('borrow')
    }
    return(
        <div className='lending'>
            <div className='lending-header'>
                <div style={{width: '70%', display:'flex'}}>
                    <h2 style={{textAlign: 'center', margin: 'auto'}}>Lending Market</h2>
                    {/* <p>Aurum DeFi lending is open market to lend and borrow digital assets.</p> 
                    <p>The AURUM token can be minted by using digital asset collateral.</p>
                    <p>AURUM is a synthetic token which pegged with the price of real gold</p> */}
                </div>
                <div className='claim-reward-box'>
                    <div>
                        <h3>ARM Reward</h3>
                    </div>
                    <div className='reward-value'>
                        <p>{BigNumber(props.mainstate.comptrollerState.getArmAccrued).div(e18).toFormat(2)}</p>
                        <button className='button' onClick={manualClaimReward}>Claim</button>
                    </div>
                </div>
            </div>
            <div className='user-info-box'>
                <div className='user-info-supply'>
                    <div className='user-info-detail'>
                        <h3>Total Supply</h3>
                    </div>
                    <div className='user-info-detail'>
                        <p>$ {floatUserTotalSupply}</p>
                    </div>
                </div>
                <div className='user-info-borrow'>
                    <div className='user-info-detail'>
                        <h3>Total Borrow</h3>
                    </div>
                    <div className='user-info-detail'>
                        <p>$ {floatUserTotalBorrow}</p>
                    </div>
                </div>
                <div className={danger === true ? 'user-info-credits-danger' : 'user-info-credits'} >
                    <div className='user-info-detail'>
                        <h3>Remaining Credits</h3>
                    </div>
                    <div className='user-info-detail'>
                        <p>$ {floatUserRemainingCredits}</p>
                    </div>
                </div>
            </div>
            <div className='lending-body'>
                <Menu changePageBorrow={changePageBorrow} changePageSupply={changePageSupply} page={page}/>
                <div className='lending-box'>
                    <table className='table table-hover'>
                        <thead className='table-head'>
                            <tr>
                                <th> Assets </th>
                                <th> APR </th>
                                <th className='mobile'> Supply </th>
                                <th className='mobile'> Borrow </th>
                                <th className='mobile'> {page==='supply' ? 'Your Deposit'          : 'Pool cash'} </th>
                                <th className='mobile'> {page==='supply' ? 'Your wallet balance'   : 'Your Debt'} </th>
                                <th> {page==='supply' ? 'Collateral'            : 'Wallet Balance'} </th>
                            </tr>
                        </thead>
                        <tbody className='table-body'>
                            {superState.markets.map ((element) => 
                                <AssetList 
                                    key={element.index} 
                                    markets={element} 
                                    page={page} 
                                    updateWeb3 = {props.updateWeb3}
                                    totalCredits = {userTotalCredits}
                                    remainingCredits = {userRemainingCredits}
                                    totalBorrows = {userTotalBorrow}
                                    mainstate = {superState}
                                />
                            )}

                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    )
}

class Lending extends Component{

    render() {
        let content    
    
        if(this.props.mainstate.loadMarket === false || this.props.mainstate.loading === true){
            content = <Loading mainstate={this.props.mainstate}/>
        }
        else {
            content = <MainLending mainstate={this.props.mainstate} updateWeb3={this.props.updateWeb3} />
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

export default Lending