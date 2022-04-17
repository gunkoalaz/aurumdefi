import React from 'react';
import Popup from 'reactjs-popup';
import { useState } from 'react';

import BTClogo from '../btclogo.png';
import USDTlogo from '../tetherlogo.png';
import BUSDlogo from '../busdlogo.png';
import BNBlogo from '../bnblogo.png';
import REIlogo from '../reilogo.png';
import NEARlogo from '../nearlogo.png';
import KUMAlogo from '../kumalogo.png';
import KUBlogo from '../kublogo.png';
import ETHlogo from '../ethlogo.png';
import unassignedlogo from '../unassignedlogo.png';

import './css/Popup.css'
import Web3 from 'web3'
const BigNumber = require('bignumber.js');


const e18 = 1000000000000000000
const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935"
const secToYear = 60*60*24*365


const Toggleswitch = (props) => {
    function activateCollateral() {
        props.comptroller.methods.addToMarket(props.lendToken._address).send({from: props.account}).on('transactionHash', (hash) => {

        })
    }
    function deactivateCollateral() {
        props.comptroller.methods.exitMarket(props.lendToken._address).send({from: props.account}).on('transactionHash', (hash) => {

        })
    }
    return (
        <label className="switch">
            {props.checker === true /*Checking membership*/ ?
                <input type="checkbox" checked onChange={deactivateCollateral}/>
                :
                <input type="checkbox" onChange={activateCollateral}/>
            }
            <span className="slider"></span>
        </label>
    )
}
const PopupSupply = (props) => {    
    const [valueStake, setStake] = useState()
    const [valueUnstake, setUnstake] = useState()
    const floatRegExp = new RegExp('^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$')
    let balance = props.balance.toFixed(6,1)
    let deposit = props.deposit.toFixed(6,1)

    //Input manipulator
    const stakeAmountChange = (e) => {
        let oldAmount = valueStake;
        let newAmount = e.target.value
        let oldfloat = parseFloat(oldAmount)
        let newfloat = parseFloat(newAmount)
        let max = e.target.max
        if (floatRegExp.test(newAmount)){
            if(newfloat > max) {
                setStake(max)
            }else {
                if(newfloat===oldfloat){
                    if((newAmount.length<=2 && newAmount.charAt(newAmount.length-1) === '.') || newAmount.charAt(newAmount.length-1) === '0') {
                        if(newAmount==='00'){
                            setStake(0)
                        } else {
                            setStake(newAmount)
                        }
                    } else {
                        setStake(newAmount)
                    }
                } else {
                    setStake(newAmount)
                }
            }
        } else {
            if(newAmount===''){
                setStake('')
            } else {
                setStake(valueStake)
            }
        }
    }
    //Input manipulator
    const unstakeAmountChange = (e) => {
        let oldAmount = valueUnstake;
        let newAmount = e.target.value
        let oldfloat = parseFloat(oldAmount)
        let newfloat = parseFloat(newAmount)
        let max = e.target.max
        if (floatRegExp.test(newAmount)){
            if(newfloat > max) {
                setUnstake(max)
            }else {
                if(newfloat===oldfloat){
                    if((newAmount.length<=2 && newAmount.charAt(newAmount.length-1) === '.') || newAmount.charAt(newAmount.length-1) === '0') {
                        if(newAmount==='00'){
                            setUnstake(0)
                        } else {
                            setUnstake(newAmount)
                        }
                    } else {
                        setUnstake(newAmount)
                    }
                } else {
                    setUnstake(newAmount)
                }
            }
        } else {
            if(newAmount===''){
                setUnstake('')
            } else {
                setUnstake(valueUnstake)
            }
        }
    }

    //
    //Smart contract interact function
    //
    const underlyingApprove = () => {
        props.markets.underlyingContract.methods.approve(props.markets.contract._address, MAX_UINT).send({from: props.account}).on('transactionHash', (hash) => {
            props.update()
        })
    }
    // const approve = () => {
    //     props.markets.contract.methods.approve(props.markets.contract._address, MAX_UINT).send({from: props.account}).on('transactionHash', (hash) => {
    //         props.update()
    //     })
    // }
    const staking = () => {
        let amount
        amount = valueStake.toString()
        amount = Web3.utils.toWei(amount, 'Ether')
        if(props.markets.underlyingSymbol === 'REI' || props.markets.underlyingSymbol === 'tREI') {
            props.markets.contract.methods.mint().send({from: props.account, value: amount, gas: '400000'}).on('transactionHash', (hash) => {
                props.update()
            })
        } else {
            props.markets.contract.methods.mint(amount).send({from: props.account, gas: '400000'}).on('transactionHash', (hash) => {
                props.update()
            })
        }
    }
    const unstaking = () => {
        let amount
        amount = valueUnstake.toString()
        amount = Web3.utils.toWei(amount, 'Ether')
        props.markets.contract.methods.redeemUnderlying(amount).send({from: props.account, gas: '400000'}).on('transactionHash', (hash) => {
            props.update()
        })
    }

    const setMaxStake = () => {
        if(props.markets.underlyingSymbol === 'REI' || props.markets.underlyingSymbol === 'tREI') {
            if(balance > 0.006) {
                setStake(balance - 0.006)
            }
        }
        else {
            setStake(balance)
        }
    }
    const setMaxUnstake = () => {
        setUnstake(deposit)
    }


    let depositButton
    if( parseInt(props.markets.underlyingAllowance) === 0 ){
        depositButton = <button className='button' onClick={underlyingApprove}>Approve</button>
    } else {
        if (valueStake === '' || valueStake === null || isNaN(valueStake) || valueStake === '0'){
            depositButton = <button className='button-inactive'>Deposit</button>
        } else {
            if (props.markets.underlyingAllowance / e18 >= valueStake) {
                depositButton = <button className='button' onClick={staking}>Deposit</button>
            } else {
                depositButton = <button className='button' onClick={underlyingApprove}>Approve</button>
            }
        }
    }

    let withdrawButton
    if (valueUnstake === '' || valueUnstake === null || isNaN(valueUnstake) || valueUnstake === '0'){
        withdrawButton = <button className='button-inactive'>Withdraw</button>
    } else {
        withdrawButton = <button className='button' onClick={unstaking}>Withdraw</button>
    } 

    return (
        
        <div className='popup-box'>
            <div className='popup-head'>
                <h3 style={{textAlign: 'center', color: 'darkgreen'}}>Deposit/Withdraw</h3>
                <div className='popup-head-symbol'>
                    <img src={props.logo} alt='tokens' className='logoimg' />
                    <h1>{props.markets.underlyingSymbol} </h1>
                </div>
                <p>To deposit, you will get the 'lendToken' in return. 
                    The lendToken will gradually increase in exchange rate depends on how much the borrower pay for interest.
                </p>
            </div>
            <div className='popup-body'>
                <div className='popup-body-box'>
                    <div className='popup-body-box-detail'>
                        <h3>Your balance</h3>
                        <p className='maxbutton' onClick={setMaxStake}>{balance}</p>
                    </div>
                    <div className='popup-body-box-detail'>
                        <input 
                            type='text' 
                            className='input' 
                            onChange = {stakeAmountChange}
                            min = {'0'}
                            max = {balance}
                            value={valueStake}/>
                        {depositButton}
                    </div>
                </div>
                <div className='popup-body-box'>
                    <div className='popup-body-box-detail'>
                        <h3>Your deposit</h3>
                        <p className='maxbutton' onClick={setMaxUnstake}>{deposit}</p>
                    </div>
                    <div className='popup-body-box-detail'>
                        <input 
                            type='text' 
                            className='input' 
                            onChange={unstakeAmountChange}
                            min = {'0'}
                            max = {deposit}
                            value={valueUnstake}
                        />
                        {withdrawButton}
                    </div>
                </div>
                <div>
                    <button className="closeButton" onClick={props.close}>
                        &times;
                    </button>
                </div>
            </div>
        </div>
    )
}
const PopupBorrow = (props) => {    
    const [valueBorrow, setBorrow] = useState()
    const [valueRepay, setRepay] = useState()
    const floatRegExp = new RegExp('^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$')

    let debt = props.debt.toFixed(6,1)
    let balance = props.balance.toFixed(6,1)
    let maxBorrow = props.maxBorrow.toFixed(6,1)
    let safeBorrow = props.safeBorrow.toFixed(6,1)

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
    const underlyingApprove = () => {
        props.markets.underlyingContract.methods.approve(props.markets.contract._address, MAX_UINT).send({from: props.account}).on('transactionHash', (hash) => {
            props.update()
        })
    }
    const borrow = () => {
        let amount
        amount = valueBorrow.toString()
        amount = Web3.utils.toWei(amount, 'Ether')
        props.markets.contract.methods.borrow(amount).send({from: props.account, gas: '1200000'}).on('transactionHash', (hash) => {
            props.update()
        })
    }
    const repay = () => {
        let amount
        amount = valueRepay.toString()
        amount = Web3.utils.toWei(amount, 'Ether')
        if(props.markets.symbol==='lendREI'){
            props.markets.contract.methods.repayBorrow().send({from: props.account, value:amount, gas: '1200000'}).on('transactionHash', (hash) => {
                props.update()
            })
        } else {
            props.markets.contract.methods.repayBorrow(amount).send({from: props.account, gas: '1200000'}).on('transactionHash', (hash) => {
                props.update()
            })
        }
    }

    const setMaxBorrow = () => {
        setBorrow(maxBorrow)
    }
    const setMaxSafeBorrow = () => {
        setBorrow(safeBorrow)
    }
    const setMaxRepay = () => {
        if(parseFloat(debt) > parseFloat(balance)) {
            setRepay(balance)
        } else {
            setRepay(debt)
        }
    }
    const setMaxBalanceRepay = () => {
            setRepay(balance)
    }

//Button modifier

    let borrowButton
    if (valueBorrow === '' || valueBorrow === null || isNaN(valueBorrow) || valueBorrow === '0'){
        borrowButton = <button className='button-inactive'>Borrow</button>
    } else {
        borrowButton = <button className='button' onClick={borrow}>Borrow</button>
    }

    let repayButton
    
    if( props.markets.underlyingAllowance === '0' || BigNumber(props.markets.underlyingAllowance).isLessThan(valueRepay) ){
        repayButton = <button className='button' onClick={underlyingApprove}>Approve</button>
    } else {
        if (valueRepay === '' || valueRepay === null || isNaN(valueRepay) || valueRepay === '0'){
            repayButton = <button className='button-inactive'>Repay</button>
        } else {
            repayButton = <button className='button' onClick={repay}>Repay</button>
        } 
    }

// Main
    return (
        
        <div className='popup-borrow-box'>
            <div className='popup-head'>
                <h3 style={{color: 'maroon', textAlign: 'center'}}> Borrow/Repay </h3>
                <div className='popup-head-symbol'>
                    <img src={props.logo} alt='tokens' className='logoimg' />
                    <h1>{props.markets.underlyingSymbol}</h1>
                </div>
                <p>To borrow or repay, you need to have collateral which can be gain by deposit assets in 'Deposit/Withdraw' function and mark them as 'Collateral'.
                    Then you will get the 'Credits' for borrowing assets.
                </p>
                {/* <p style={{color: 'yellow'}}>Tips :: You can put a little extra repay to fully close position, you will got repay the excess amount</p> */}
                <p style={{color: 'darkred'}}>Warning :: if your credits is shortage (below 0) your asset might be liquidate.</p>
            </div>
            <div className='popup-body'>
                <div className='popup-body-box'>
                    <div className='popup-body-box-detail'>
                        <h3>Available Credits</h3>
                        <p className='maxbutton' onClick={setMaxBorrow}>{maxBorrow}</p>
                    </div>
                    <div className='popup-body-box-detail'>
                        <h3>Safe Borrow</h3>
                        <p className='maxbutton' onClick={setMaxSafeBorrow}>{safeBorrow}</p>
                    </div>
                    <div className='popup-body-box-detail'>
                        <input 
                            type='text' 
                            className='input' 
                            onChange = {stakeAmountChange}
                            min = {'0'}
                            max = {maxBorrow}
                            value={valueBorrow}/>
                        {borrowButton}
                    </div>
                </div>
                <div className='popup-body-box'>
                    <div className='popup-body-box-detail'>
                        <h3>Your Debt</h3>
                        <p className='maxbutton' onClick={setMaxRepay}>{debt}</p>
                    </div>
                    <div className='popup-body-box-detail'>
                        <h3>Your Balance</h3>
                        <p className='maxbutton' onClick={setMaxBalanceRepay}>{balance}</p>
                    </div>
                    <div className='popup-body-box-detail'>
                        <input 
                            type='text' 
                            className='input' 
                            onChange={unstakeAmountChange}
                            min = {'0'}
                            max = {balance}
                            value={valueRepay}
                        />
                        {repayButton}
                    </div>
                </div>
                <div>
                    <button className="closeButton" onClick={props.close}>
                        &times;
                    </button>
                </div>
            </div>
        </div>
    )
}

const AssetList = (props) => {

    //deltaTime is 'seconds' after last asset update
    //borrowRatePerSeconds   and  SupplyRatePerSeconds   will be multiply by deltaTime to get real-time update position
    let deltaTime = props.mainstate.time - props.markets.accrualTimestamp;

    // APR and interest COMPLETE, NO BUG calculation
    let apr = BigNumber(props.markets.supplyRatePerSeconds).div(e18).times(secToYear).times(100);
    let totalSupply = BigNumber(props.markets.cash).plus(props.markets.totalBorrows).minus(props.markets.totalReserves);
    let supplyRewardAPR = BigNumber(props.markets.aurumSpeeds).times(secToYear).div(totalSupply).div(props.markets.underlyingPrice).times(props.mainstate.price.armPrice).times(100)
    if(supplyRewardAPR.isNaN()){
        supplyRewardAPR = BigNumber(0);
    }
    let totalSupplyAPR = supplyRewardAPR.plus(apr);

    let interest = BigNumber(props.markets.borrowRatePerSeconds).div(e18).times(secToYear).times(100);
    let borrowRewardAPR = BigNumber(props.markets.aurumSpeeds).times(secToYear).div(props.markets.totalBorrows).div(props.markets.underlyingPrice).times(props.mainstate.price.armPrice).times(100)
    if(borrowRewardAPR.isNaN()){
        borrowRewardAPR = BigNumber(0);
    }
    let totalBorrowAPR = borrowRewardAPR.minus(interest)

    // apr = apr.toFormat(2)
    // supplyRewardAPR = supplyRewardAPR.toFormat(2)
    // totalSupplyAPR = totalSupplyAPR.toFormat(2)

    // interest = interest.toFormat(2)
    // borrowRewardAPR = borrowRewardAPR.toFormat(2)
    // totalBorrowAPR = totalBorrowAPR.toFormat(2)


    const EXCHANGE_RATE = props.markets.exchangeRateStored

    let tempDeposit = new BigNumber(props.markets.balanceOf)
    tempDeposit = tempDeposit.div(e18)
    tempDeposit = tempDeposit.times(EXCHANGE_RATE)
    let deposit = (tempDeposit.div(e18).times(props.markets.supplyRatePerSeconds).times(deltaTime).plus(tempDeposit)).div(e18)
    let updateDeposit = deposit.toFormat(3, 1)

    let debt = new BigNumber(props.markets.borrowBalanceStored)
    debt = debt.div(e18).times(props.markets.borrowRatePerSeconds).times(deltaTime).plus(props.markets.borrowBalanceStored).integerValue()
    debt = debt.div(e18)
    let updateDebt = debt.toFormat(3, 1)

    // User balance
    let balance = new BigNumber(props.markets.underlyingBalance).div(e18)
    let displayBalance = balance.toFormat(3, 1)

    //Calculate assets available borrow balance
    //use the minumum value of
    // - cash
    // - borrowCaps
    let cashMinusReserve = new BigNumber(props.markets.cash).minus(props.markets.totalReserves)
    let borrowCaps = new BigNumber(props.markets.borrowCaps).minus(props.markets.totalBorrows)
    let availableBorrow

    if (cashMinusReserve.isGreaterThan(borrowCaps)){
        availableBorrow = borrowCaps
    } else {
        availableBorrow = cashMinusReserve
    }
    if (BigNumber(props.markets.borrowCaps).isEqualTo(0)) {
        availableBorrow = cashMinusReserve
    }
    //Turn availableBorrow to USD
    let showAvailableBorrow = availableBorrow.div(e18).toFormat(2, 1)
    availableBorrow = availableBorrow.times(props.markets.underlyingPrice).div(e18).div(e18)

    //Calculate maxBorrow
    //use the minimum of
    // - availableBorrows
    // - calculated remaining credits
    let maxBorrow

    if(availableBorrow.isGreaterThan(props.remainingCredits)){
        maxBorrow = new BigNumber(props.remainingCredits)
    } else {
        maxBorrow = availableBorrow
    }
    maxBorrow = maxBorrow.div(props.markets.underlyingPrice).times(e18)

    //Not yet modified
    let safeBorrow = new BigNumber(props.totalCredits).times(0.6).minus(props.totalBorrows)
    safeBorrow = safeBorrow.div(props.markets.underlyingPrice).times(e18)

    if (safeBorrow.isGreaterThan(maxBorrow)) {
        safeBorrow = maxBorrow
    }
    if (safeBorrow < 0){
        safeBorrow = 0
    }

    let logo
    switch(props.markets.underlyingSymbol) {
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

        default     : logo = unassignedlogo; break;
    }

        
        return (
            <Popup modal lockScroll nested trigger={
                <tr className={props.markets.mintPause || props.markets.borrowPause ? 'pause':''}> 
                    <td className='asset-name'>
                        <img src={logo} alt='tokens' className='logoimg' />
                        <h3>{props.markets.underlyingSymbol}</h3>    
                    </td>
                    <td className={props.page === 'borrow' && totalBorrowAPR.isLessThan(0) ? 'asset-number-negative' : 'asset-number-positive'}>
                        <h5>{props.page === 'supply' ? totalSupplyAPR.toFormat(2) : totalBorrowAPR.toFormat(2)} %</h5>
                        <p>{props.page === 'supply' ? '('+apr.toFormat(2)+'+'+ supplyRewardAPR.toFormat(2)+')' : '('+borrowRewardAPR.toFormat(2)+'-'+interest.toFormat(2)+')'}</p>
                    </td>
                    <td className='asset-number mobile'>
                        <h5>{cashMinusReserve.div(e18).toFormat(2)}</h5>
                    </td>
                    <td className='asset-number mobile'>
                        <h5>{BigNumber(props.markets.totalBorrows).div(e18).toFormat(2)}</h5>
                    </td>
                    <td className='asset-number mobile'>
                        <h5>{props.page === 'supply' ? updateDeposit : showAvailableBorrow}</h5>
                    </td>
                    <td className='asset-number mobile'>
                        <h5>{props.page === 'supply' ? displayBalance : updateDebt}</h5>
                    </td>
                    <td>
                        {props.page === 'supply' ? 
                            <Toggleswitch 
                                checker={props.markets.membership} 
                                comptroller={props.mainstate.comptrollerState.contract} 
                                account={props.mainstate.account} 
                                lendToken={props.markets.contract}
                            /> : <h5>{displayBalance}</h5>
                        }
                    </td>
                </tr>
            } >
            {/* Popup content start here */}
            { close => (
                props.page === 'supply' ? <PopupSupply 
                    logo = {logo}
                    account = {props.mainstate.account}
                    markets = {props.markets}
                    close = {close}
                    deposit = {deposit}
                    balance = {balance}
                    update = {props.updateWeb3}
                />
                :
                <PopupBorrow
                    logo = {logo}
                    account = {props.mainstate.account}
                    markets = {props.markets}
                    close = {close}

                    debt = {debt}
                    balance = {balance}
                    maxBorrow = {maxBorrow}
                    safeBorrow = {safeBorrow}

                    update = {props.updateWeb3}
                />
            )}
            </Popup>

        )
}

export default AssetList