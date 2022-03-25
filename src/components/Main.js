import React, {Component} from 'react'
import './css/Main.css'
import Loading from './Loading'
import BTClogo from '../btclogo.png'
import USDTlogo from '../tetherlogo.png'
import BUSDlogo from '../busdlogo.png'
import BNBlogo from '../bnblogo.png'
import REIlogo from '../reilogo.png'
import unassignedlogo from '../unassignedlogo.png'

const MainInfoList = (props) => {

    let logo
    switch(props.markets.underlyingSymbol) {
        case 'BTC'  : logo = BTClogo; break;
        case 'USDT' : logo = USDTlogo; break;
        case 'BUSD' : logo = BUSDlogo; break;
        case 'REI'  : logo = REIlogo; break;
        case 'BNB'  : logo = BNBlogo; break;
        default     : logo = unassignedlogo; break;
    }

    return (
        <tr> 
            <td className='asset-name'>
                <img src={logo} alt='tokens' className='logoimg' />
                <h3>{props.symbol}</h3>    
            </td>
            <td className='asset-number'>
                <h5>2</h5>
            </td>
            <td className='asset-number'>
                <h5>3</h5>
            </td>
            <td className='asset-number'>
                <h5>4</h5>
            </td>
            <td>
                <h5>5</h5>
            </td>
        </tr>
    )
}
const MainInfo = (props) => {
    return (
        <div>
            <div className='main-info-top'>

            </div>
            <div>
                <table className='table table-hover'>
                    <thead className='table-head'>
                        <tr>
                            <th> Assets </th>
                            <th> Supply ARM/sec </th>
                            <th> Borrow ARM/sec </th>
                            <th> PriceOracle </th>
                            <th> TVL </th>
                        </tr>
                    </thead>
                    <tbody className='table-body'>
                        {props.mainstate.markets.map ((element) => 
                            <MainInfoList 
                                key={element.index} 
                                markets={element} 
                                symbol={element.symbol}
                            />
                        )}

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