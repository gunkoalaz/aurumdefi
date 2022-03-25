import React, {Component} from 'react'
import './css/Main.css'
import './css/MainList.css'
import Loading from './Loading'
import BTClogo from '../btclogo.png'
import USDTlogo from '../tetherlogo.png'
import BUSDlogo from '../busdlogo.png'
import BNBlogo from '../bnblogo.png'
import REIlogo from '../reilogo.png'
import unassignedlogo from '../unassignedlogo.png'

const BigNumber = require('bignumber.js');
const e18 = 1000000000000000000
// const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935"

const MainInfoList = (props) => {

    let logo
    switch(props.symbol) {
        case 'BTC'  : logo = BTClogo; break;
        case 'USDT' : logo = USDTlogo; break;
        case 'BUSD' : logo = BUSDlogo; break;
        case 'REI'  : logo = REIlogo; break;
        case 'BNB'  : logo = BNBlogo; break;
        default     : logo = unassignedlogo; break;
    }

    let aurumSpeedsPerDay = BigNumber(props.aurumSpeeds).times(60).times(60).times(24).div(e18).times(2).toFormat(0)
    let price = BigNumber(props.price).div(e18).toFormat(2)
    let tvl = BigNumber(props.cash).plus(props.totalBorrows).minus(props.totalReserves).times(props.price).div(e18).div(e18).toFormat(2)

    return (
        <tr> 
            <td className='asset-name'>
                <img src={logo} alt='tokens' className='logoimg' />
                <h3>{props.symbol}</h3>    
            </td>
            <td className='asset-number'>
                <h5>{aurumSpeedsPerDay}</h5>
            </td>
            <td className='asset-number'>
                <h5>$ {price}</h5>
            </td>
            <td>
                <h5>$ {tvl}</h5>
            </td>
        </tr>
    )
}
const MainInfo = (props) => {

    let i
    let allMarkets = props.mainstate.markets
    let tvl = BigNumber(0)
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
        
        console.log('Borrows '+totalBorrows[i])
        console.log('Reserve '+totalReserves[i])
        console.log('Cash    '+totalCash[i])
        console.log('Price   '+price[i])
        addTVL[i] = BigNumber(totalCash[i]).plus(totalBorrows[i]).minus(totalReserves[i]).times(price[i]).div(e18).div(e18)

        tvl = tvl.plus(addTVL[i])
    }
    tvl = tvl.toFormat(2)
    let mCap

    return (
        <div>
            <div className='main-info-top'>
                <div className={'main-items tvl'}>
                    <h3>
                        TVL
                    </h3>
                    <p>
                        $ {tvl}
                    </p>
                </div>
                
            </div>
            <div className='main-info-bottom'>
                <div className={'main-items'}>
                    <h3>
                        ARM circulating
                    </h3>
                    <p>
                        0
                    </p>
                </div>
                <div className={'main-items'}>
                    <h3>
                        Market cap
                    </h3>
                    <p>
                        0
                    </p>
                </div>
                <div className={'main-items'}>
                    <h3>
                        AURUM minted
                    </h3>
                    <p>
                        {BigNumber(props.mainstate.comptrollerState.totalMintedAURUM).div(e18).toFormat(2)}
                    </p>
                </div>
            </div>
            <div>
                <table className='table table-hover'>
                    <thead className='table-head'>
                        <tr>
                            <th> Assets </th>
                            <th> Distribute ARM / day </th>
                            <th> PriceOracle </th>
                            <th> TVL </th>
                        </tr>
                    </thead>
                    <tbody className='table-body'>
                        {props.mainstate.markets.map ((element) => 
                            <MainInfoList 
                                key={element.index} 
                                symbol={element.underlyingSymbol}
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
                            aurumSpeeds = '0'
                            price = {props.mainstate.price.goldPrice}
                            totalBorrows = '0'
                            totalReserves = '0'
                            cash = '0'
                        />

                    </tbody>
                </table>
            </div>
        </div>
    )
}

class Main extends Component {
    render() {
        let content    
        
        if(this.props.mainstate.loadMarket === false || this.props.mainstate.loading === true){
            content = <Loading/>
        }
        else {
            content = <MainInfo mainstate={this.props.mainstate} />
        }
        return (
            <div>
                <div className='mainbox'>
                    <h1>Welcome to AurumDeFi</h1>
                    {content}
                </div>
            </div>
        )
    }
}

export default Main