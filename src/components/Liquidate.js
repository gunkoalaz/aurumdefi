import React, {Component} from "react";
import Loading from "./Loading.js";
import LiquidateList from "./LiquidateList"
import './css/Liquidate.css'

const BigNumber = require('bignumber.js');
const e18 = 1000000000000000000
// const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935"


const MainLiquidate = (props) => {

    let content
    if(props.mainstate.allShortage.length === 0) {
        content = 
        <h3>
            No liquidating borrower position
        </h3>

    } else {
        content = 
        <div>
            {props.mainstate.allShortage.map((element) => 
            <LiquidateList 
                key = {element.index}
                account = {element.borrower}
                borrowAsset = {element.borrowAsset}
                collateralAsset = {element.collateralAsset}
                mintedGold = {element.mintedGold}
                mainstate = {props.mainstate}
                update = {props.updateWeb3}
            />
            )
        }
        </div>
    }

    return (
        <div>
            <div className={'liq-header'}>
                <h3>Liquidation bounty</h3>
                <p>Liquidator will receive the liquidating bounty depends on the position size and borrower collateral tokens</p>
                <p>'Close Factor' is the maximum percentage of 'Borrowed asset' can be liquidated</p>
                <p>'Liquidation Bounty' is the benefit that liquidator will receive depends on how big is the closed position</p>
            </div>
            <div className={'liq-info'}>
                <div className={'liq-info-closefactor full'}>
                    <h3>
                        Close Factor
                    </h3>
                    <p>
                        {BigNumber(props.mainstate.comptrollerState.closeFactor).div(e18).times(100).toFormat(2)} %
                    </p>
                </div>
                <div className={'liq-info-liquidincentive full'}>
                    <h3>
                        Liquidation Bounty
                    </h3>
                    <p>
                        {BigNumber(props.mainstate.comptrollerState.liquidationIncentive).div(e18).minus(1).times(100).toFormat(2)} %
                    </p>
                </div>
            </div>
                <button className={'button'}onClick={props.loadLiquidateList}>Load list</button>
            <div className={'liq-box'}>
                <div>
                    {content}
                </div>
            </div>
        </div>
    )
}




class Liquidate extends Component{

    render() {

        let content    
        
        if(this.props.mainstate.loadMarket === false || this.props.mainstate.loading === true){
            content = <Loading/>
        }
        else {
            content = <MainLiquidate mainstate={this.props.mainstate} updateWeb3={this.props.updateWeb3} loadLiquidateList={this.props.loadLiquidateList} />
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
export default Liquidate