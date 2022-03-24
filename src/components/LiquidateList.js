import React from "react";
import { useState } from "react";
import LendToken from '../truffle_abis/LendToken.json'
import LendREI from '../truffle_abis/LendREI.json'
import AurumController from '../truffle_abis/AurumController.json'

const BigNumber = require('bignumber.js');
const e18 = 1000000000000000000
// const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935"


const BorrowList = (props) => {
    let amount = BigNumber(props.amount).div(e18)
    return (
        <div className="form-check">
            <input className="form-check-input" type="radio" id={props.key} value={props.asset} checked={props.currentSelect === props.asset} onChange={props.update}/>
            <label className="form-check-label" for={props.key}>
                {props.symbol} ({amount.toFormat(2)})
            </label>
        </div>
    )
}
const CollateralList = (props) => {
    let amount = BigNumber(props.amount).div(e18)
    return (
        <div className="form-check">
            <input className="form-check-input" type="radio" id={props.key} value={props.asset} checked={props.currentSelect === props.asset} onChange={props.update}/>
            <label className="form-check-label" for={props.key}>
                {props.symbol} ({amount.toFormat(2)})
            </label>
        </div>
    )
}
const LiquidateList = (props) => {
    const [selectedBorrow, setBorrow] = useState('')
    const [selectedCollateral, setCollateral] = useState('')
    const updateBorrow = (changeEvent) => {
        setBorrow(changeEvent.target.value)
    }
    const updateCollateral = (changeEvent) => {
        setCollateral(changeEvent.target.value)
    }
    const execute = async () => {
        if(selectedBorrow !== '' && selectedCollateral !== ''){
            const web3 = window.web3
            let amount = payAmount.toString()
            amount = web3.utils.toWei(amount, 'Ether')
            if(selectedBorrow !== 'gold'){
                const lendToken = new web3.eth.Contract(LendToken.abi, selectedBorrow)
                const selectedBorrowSymbol = await lendToken.methods.symbol().call()
                
                if(selectedBorrowSymbol === 'lendREI'){
                    const lendREI = new web3.eth.Contract(LendREI.abi, selectedBorrow)
                    lendREI.methods.liquidateBorrow(props.account, selectedCollateral).send({from: props.mainstate.account, value: amount, gas: 2000000}).on('transactionHash', (hash) => {
                        props.update()
                    })
                } else { 
                        lendToken.methods.liquidateBorrow(props.account, amount, selectedCollateral).send({from: props.mainstate.account, gas:2000000}).on('transactionHash', (hash) => {
                            props.update()
                        })
                }
            } else {
                const aurumController = new web3.eth.Contract(AurumController.abi, AurumController.networks[props.mainstate.networkId].address)
                aurumController.methods.liquidateGOLD(props.account, amount, selectedCollateral).send({from: props.mainstate.account, gas: 2000000}).on('transactionHash', (hash) => {
                    props.update()
                })
            }
        }
    }
    let shortAddress = props.account.substr(0,6)+" . . . "+props.account.substr(37,7)

    let payAmount = 0
    let paySymbol = '?'
    let getAmount = 0
    let getSymbol = '?'

    if(selectedBorrow !== '' && selectedCollateral !== ''){
        //Calculation 'amount'
        let i
        let borrowMaxAmount = BigNumber(0)
        let borrowPrice
        let collateralMaxAmount = BigNumber(0)
        let collateralExchangeRate
        let collateralPrice
        let liquidationIncentive = props.mainstate.comptrollerState.liquidationIncentive
        //search array which match Borrow / Collateral address
        //set the collateral to unit of borrow asset
        if(selectedBorrow === 'gold'){
            borrowMaxAmount = BigNumber(props.mainstate.comptrollerState.closeFactor).div(e18).times(props.mintedGold)
            borrowPrice = props.mainstate.price.goldPrice
            paySymbol = 'AURUM'
        } else {
            for (i=0;i<props.borrowAsset.length;i++){
                if(props.borrowAsset[i].asset === selectedBorrow){
                    //Found borrow asset
                    //borrowMaxAmount = CloseFactor * borrowedAmount
                    borrowMaxAmount = BigNumber(props.mainstate.comptrollerState.closeFactor).div(e18).times(props.borrowAsset[i].amount)
                    borrowPrice = props.borrowAsset[i].price // Is used to convert the collateral asset
                    paySymbol = props.borrowAsset[i].symbol
                }
            }
        }
        for (i=0;i<props.collateralAsset.length;i++){
            if(props.collateralAsset[i].asset === selectedCollateral){
                //Found collateral asset
                //Convert collateral amount to borrow unit
                //Collateral amount * exchangeRateMantissa(/e18) * collateral price / borrow price
                collateralExchangeRate = props.collateralAsset[i].exchangeRate
                collateralPrice = props.collateralAsset[i].price
                collateralMaxAmount = BigNumber(props.collateralAsset[i].amount).times(collateralExchangeRate).div(e18).times(collateralPrice).div(borrowPrice)
                getSymbol = props.collateralAsset[i].symbol
            }
        }
        if(borrowMaxAmount.div(liquidationIncentive).times(e18).isGreaterThan(collateralMaxAmount)){
            payAmount = collateralMaxAmount.div(liquidationIncentive).toFixed(6) - 0.000001
            getAmount = collateralMaxAmount.div(collateralExchangeRate).div(collateralPrice).times(borrowPrice) // revert
            getAmount = getAmount.toFixed(6)
        } else {
            payAmount = borrowMaxAmount.div(e18).toFixed(6) - 0.000001
            getAmount = BigNumber(payAmount).times(liquidationIncentive).div(e18).times(borrowPrice).div(collateralPrice).times(e18).div(collateralExchangeRate)
            getAmount = getAmount.toFixed(6)
        }
    }

    return (
        <div>
            <div className='liq-user-box' key={props.index}>
                <div className={'liq-user-user'}>
                    <h3>Borrower</h3>
                    <p>{shortAddress}</p>
                </div>
                <div className={'liq-user-borrow'}>
                    <h3>Borrow</h3>
                    {props.borrowAsset.map( (element) => 
                        <BorrowList
                            key = {element.asset}
                            asset = {element.asset}
                            symbol = {element.symbol}
                            amount = {element.amount}
                            update = {updateBorrow}
                            currentSelect = {selectedBorrow}
                        />

                    )}
                    {props.mintedGold !== '0' ?
                        <BorrowList
                            key = {'gold'}
                            asset = {'gold'}
                            symbol = {'AURUM'}
                            amount = {props.mintedGold}
                            update = {updateBorrow}
                            currentSelect = {selectedBorrow}
                        />
                        : ''
                    }
                </div>
                <div className={'liq-user-collateral'}>
                    <h3>Collateral</h3>
                    {props.collateralAsset.map( (element) => 
                        <CollateralList
                            key = {element.asset}
                            asset = {element.asset}
                            symbol = {element.symbol}
                            amount = {element.amount}
                            update = {updateCollateral}
                            currentSelect = {selectedCollateral}
                        />

                    )}
                </div>
                <div className={'liq-user-result'}>
                    <h3>Result</h3>
                    <p>Pay {payAmount} {paySymbol}</p>
                    <p>Get {getAmount} {getSymbol}</p>
                </div>
                <div className={'liq-user-button'}>
                    <button className="button" onClick={execute}>Liquidate</button>
                </div>
            </div>
        </div>
    )
}

export default LiquidateList