import React, {Component} from 'react'
import './css/Main.css'
import './css/MainList.css'
import './css/Lending.css'
import Loading from './Loading'

import BTClogo from '../btclogo.png';
import USDTlogo from '../tetherlogo.png';
import BUSDlogo from '../busdlogo.png';
import BNBlogo from '../bnblogo.png';
import REIlogo from '../reilogo.png';
import NEARlogo from '../nearlogo.png';
import KUMAlogo from '../kumalogo.png';
import KUBlogo from '../kublogo.png';
import ETHlogo from '../ethlogo.png';
import AURUMlogo from '../aurum.png';
import unassignedlogo from '../unassignedlogo.png';

const BigNumber = require('bignumber.js');
const e18 = 1000000000000000000
// const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935"

const MainInfoList = (props) => {

    let logo
    switch(props.symbol) {
        case 'BTC'  : logo = BTClogo; break;
        case 'USDT' : logo = USDTlogo; break;

        case 'kBUSD': 
        case 'BUSD' : logo = BUSDlogo; break;

        case 'NEAR' :
        case 'tNEAR': logo = NEARlogo; break;
        
        case 'KUMA' : 
        case 'tKUMA': logo = KUMAlogo; break;

        case 'REI'  : logo = REIlogo; break;

        case 'KUB'  :
        case 'tKUB' : logo = KUBlogo; break;

        case 'BNB'  : 
        case 'tBNB' : logo = BNBlogo; break;

        case 'ETH'  : 
        case 'tETH' : logo = ETHlogo; break;

        case 'AURUM': logo = AURUMlogo; break;

        default     : logo = unassignedlogo; break;
    }

    let aurumSpeedsPerDay = BigNumber(props.aurumSpeeds).times(60).times(60).times(24).div(e18).times(2).toFormat(0)
    let price = new BigNumber(props.price).div(e18);
    let totalSupply = new BigNumber(props.cash).plus(props.totalBorrows).minus(props.totalReserves).div(e18);
    let totalBorrow = new BigNumber(props.totalBorrows).div(e18);
    let tvl = new BigNumber(totalSupply).times(price);
    let borrowUSD = new BigNumber(totalBorrow).times(price);

    let utility = totalBorrow.div(totalSupply).times(100);
    if(utility.isNaN()){
        utility = new BigNumber(0);
    }

    return (
        <tr> 
            <td className='asset-name'>
                <img src={logo} alt='tokens' className='logoimg' />
                <h3>{props.symbol}</h3>    
            </td>
            <td className='mobile asset-number'>
                <h5>{BigNumber(props.collateralfactor).div(e18).times(100).toFormat(0)}%</h5>
            </td>
            <td className='asset-number'>
                <h5>{aurumSpeedsPerDay}</h5>
            </td>
            <td className='asset-number'>
                <h5 style={{textAlign: 'right'}}>{price.toFormat(2)} $</h5>
            </td>
            <td className='mobile asset-number'>
                <h5 style={{textAlign: 'right', color: 'gray'}}>{totalSupply.toFormat(2)}</h5>
                <h5 style={{textAlign: 'right'}}>{tvl.toFormat(2)} $</h5>
            </td>
            <td className='mobile asset-number'>
                <h5 style={{textAlign: 'right', color: 'gray'}}>{totalBorrow.toFormat(2)}</h5>
                <h5 style={{textAlign: 'right'}}>{borrowUSD.toFormat(2)} $</h5>
            </td>
            <td className='mobile asset-number'>
                <h5>{utility.toFormat(2)} %</h5>
            </td>
        </tr>
    )
}
const MainInfo = (props) => {

    let i
    let allMarkets = props.mainstate.markets
    let tvl = new BigNumber(0);
    let fee = new BigNumber(0);
    let totalBorrows = []
    let totalReserves = []
    let totalCash = []
    let price = []
    let addTVL = []
    for(i=0;i< allMarkets.length; i++){
        totalBorrows[i] = allMarkets[i].totalBorrows
        totalReserves[i] = allMarkets[i].totalReserves
        totalCash[i] = allMarkets[i].cash
        price[i] = allMarkets[i].underlyingPrice
        
        // console.log('Borrows '+totalBorrows[i])
        // console.log('Reserve '+totalReserves[i])
        // console.log('Cash    '+totalCash[i])
        // console.log('Price   '+price[i])
        addTVL[i] = new BigNumber(totalCash[i]).plus(totalBorrows[i]).minus(totalReserves[i]).times(price[i]).div(e18).div(e18)
        let borrowRatePerDay = new BigNumber(allMarkets[i].borrowRatePerSeconds).times(86400);
        let reserveFactor = new BigNumber(allMarkets[i].reserveFactorMantissa).div(e18);
        let addFee = borrowRatePerDay.times(totalBorrows[i]).div(e18).times(reserveFactor).times(price[i]).div(e18).div(e18);
        tvl = tvl.plus(addTVL[i]);
        fee = fee.plus(addFee);
    }
    tvl = tvl.toFormat(2);
    fee = fee.toFormat(2);
    let circulatingSupply = new BigNumber(10000000).minus(BigNumber(props.mainstate.comptrollerState.compARMBalance).plus(props.mainstate.comptrollerState.treasuryARMBalance).div(e18));
    let rewardPool = new BigNumber(props.mainstate.comptrollerState.compARMBalance).div(e18);
    let treasury = new BigNumber(props.mainstate.comptrollerState.treasuryARMBalance).div(e18);
    let marketCap = circulatingSupply.times(props.mainstate.price.armPrice).div(e18);
    
    let aurumMinted = new BigNumber(props.mainstate.comptrollerState.totalMintedAURUM).div(e18);
    let goldPrice = new BigNumber(props.mainstate.price.goldPrice).div(e18);
    let aurumMCap = aurumMinted.times(goldPrice);

    return (
        <div>
            <h1>Welcome to AurumDeFi</h1>
            <div className='main-info-bottom'>
                <div className={'main-items tvl'}>
                    <h3>
                        TVL
                    </h3>
                    <p>
                        {tvl} $
                    </p>
                </div>
                <div className={'main-items tvl mobile'}>
                    <h3>
                        Fee
                    </h3>
                    <p>
                        {fee} $/day
                    </p>
                </div>
            </div>
            <div className='main-info-bottom'>
                <div className={'main-items mobile'}>
                    <h3>
                        ARM pool
                    </h3>
                    <p>
                        {rewardPool.toFormat(2)}
                    </p>
                </div>
                <div className={'main-items mobile'}>
                    <h3>
                        ARM Treasury
                    </h3>
                    <p>
                        {treasury.toFormat(2)}
                    </p>
                </div>
                <div className={'main-items'}>
                    <h3>
                        ARM circulation
                    </h3>
                    <p>
                        {circulatingSupply.toFormat(2)}
                    </p>
                </div>
                <div className={'main-items mobile'}>
                    <h3>
                        ARM M.cap
                    </h3>
                    <p>
                        {marketCap.toFormat(2)}
                    </p>
                </div>
            </div>
            <div className='main-info-bottom'>
                <div className={'main-items'}>
                    <h3>
                        AURUM minted
                    </h3>
                    <p>
                        {aurumMinted.toFormat(2)}
                    </p>
                </div>
                <div className={'main-items mobile'}>
                    <h3>
                        Gold price
                    </h3>
                    <p>
                        {goldPrice.toFormat(2)}
                    </p>
                </div>
                <div className={'main-items mobile'}>
                    <h3>
                        AURUM M.Cap
                    </h3>
                    <p>
                        {aurumMCap.toFormat(2)}
                    </p>
                </div>
                
            </div>
            <div>
                <table className='table'>
                    <thead className='table-head'>
                        <tr>
                            <th> Assets </th>
                            <th className='mobile'> Collateral Factor</th>
                            <th> Reward/day </th>
                            <th style={{textAlign: 'right'}}> PriceOracle </th>
                            <th className='mobile' style={{textAlign: 'right'}}> Supply </th>
                            <th className='mobile' style={{textAlign: 'right'}}> Borrow </th>
                            <th className='mobile'> Utility </th>
                        </tr>
                    </thead>
                    <tbody>
                        {props.mainstate.markets.map ((element) => 
                            <MainInfoList 
                                key={element.index} 
                                symbol={element.underlyingSymbol}
                                collateralfactor = {element.collateralFactorMantissa}
                                aurumSpeeds = {element.aurumSpeeds}
                                price = {element.underlyingPrice}
                                totalBorrows = {element.totalBorrows}
                                totalReserves = {element.totalReserves}
                                cash = {element.cash}
                            />
                        )}
                        <MainInfoList 
                            key='gold' 
                            symbol='AURUM'
                            collateralfactor = '0'
                            aurumSpeeds = '0'
                            price = {props.mainstate.price.goldPrice}
                            totalBorrows = '0'
                            totalReserves = '0'
                            cash = '0'
                        />

                    </tbody>
                </table>
                <div>
                    <p className='m-3'>Price data provided by @
                        <a href='https://www.binance.com' target={'_blank'}>Binance</a>, @
                        <a href='https://www.bitkub.com' target={'_blank'}>Bitkub</a>, 
                        and @
                        <a href='https://www.coinmarketcap.com' target={'_blank'}>CoinMarketCap</a>.
                        
                    </p>
                </div>
            </div>
        </div>
    )
}

class Main extends Component {
    render() {
        let content    
        
        if(this.props.mainstate.loadMarket === false || this.props.mainstate.loading === true){
            content = <Loading mainstate={this.props.mainstate}/>
        }
        else {
            content = <MainInfo mainstate={this.props.mainstate} />
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

export default Main