import React, {Component} from 'react'
import Loading from './Loading.js'
import Web3 from 'web3'
import Comptroller from '../truffle_abis/Comptroller.json'
import CompStorage from '../truffle_abis/ComptrollerStorage.json'
import CompCalculate from '../truffle_abis/ComptrollerCalculation.json'

class Admin extends Component {
    constructor(props){
        super(props)
        this.state = {}
        this.handleInputChange = this.handleInputChange.bind(this)
    }

    handleInputChange(event) {
        const value = event.target.value;
        const name = event.target.name;

        this.setState({[name]: value})
    }
    render() {
        const web3 = window.web3
        const accounts = this.props.mainstate.account
        const networkId = this.props.mainstate.networkId
        const comptroller = this.props.mainstate.comptrollerState.contract
        const compStorage = this.props.mainstate.comptrollerState.storage

        //Comptroller
        const _setPendingAdmin = () => {
            comptroller.methods._setPendingAdmin(this.state._setPendingAdmin).send({from: accounts}).on('transactionHash', (hash) => {})
        }
        const _confirmNewAdmin = () => {
            comptroller.methods._confirmNewAdmin(this.state._confirmNewAdmin).send({from: accounts}).on('transactionHash', (hash) => {})
        }
        const _setAurumController = () => {
            comptroller.methods._setAurumController(this.state._setAurumController).send({from: accounts}).on('transactionHash', (hash) => {})
        }
        const _setTreasuryData = () => {
            comptroller.methods._setTreasuryData(this.state._setTreasuryData1, this.state._setTreasuryData2, this.state._setTreasuryData3).send({from: accounts}).on('transactionHash', (hash) => {})
        }
        const _setComptrollerCalculation = () => {
            comptroller.methods._setComptrollerCalculation(this.state._setComptrollerCalculation).send({from: accounts}).on('transactionHash', (hash) => {})
        }
        const _setAurumSpeed = () => {
            comptroller.methods._setAurumSpeed(this.state._setAurumSpeed1, this.state._setAurumSpeed2).send({from: accounts}).on('transactionHash', (hash) => {})

        }


        //CompStorage
        const _setComptrollerAddress = () => {
            compStorage.methods._setComptrollerAddress(this.state._setComptrollerAddress).send({from: accounts}).on('transactionHash', (hash) => {})
        }
        const _setCloseFactor = () => {
            compStorage.methods._setCloseFactor(this.state._setCloseFactor).send({from: accounts}).on('transactionHash', (hash) => {})
        }
        const _setCollateralFactor = () => {
            comptroller.methods._setCollateralFactor(this.state._setCollateralFactor1, this.state._setCollateralFactor2).send({from: accounts}).on('transactionHash', (hash) => {})
        }
        const _setLiquidationIncentive = () => {
            compStorage.methods._setLiquidationIncentive(this.state._setLiquidationIncentive).send({from: accounts}).on('transactionHash', (hash) => {})
        }
        const _supportMarket = () => {
            compStorage.methods._supportMarket(this.state._supportMarket).send({from: accounts}).on('transactionHash', (hash) => {})
        }
        const _setMarketBorrowCaps = () => {
            comptroller.methods._setMarketBorrowCaps(this.state._setMarketBorrowCaps1, this.state._setMarketBorrowCaps2).send({from: accounts}).on('transactionHash', (hash) => {})
        }
        const _setGOLDMintRate = () => {
            compStorage.methods._setGOLDMintRate(this.state._setGOLDMintRate).send({from: accounts}).on('transactionHash', (hash) => {})
        }
        const _setPriceOracle = () => {
            compStorage.methods._setPriceOracle(this.state._setPriceOracle).send({from: accounts}).on('transactionHash', (hash) => {})
        }
        const _setProtocolPaused = () => {
            if(this.state._setProtocolPaused === 1) {
                compStorage.methods._setProtocolPaused(true).send({from: accounts}).on('transactionHash', (hash) => {})
            } else {
                compStorage.methods._setProtocolPaused(false).send({from: accounts}).on('transactionHash', (hash) => {})
            }
        }
        const _setMintGoldPause = () => {
            if(this.state._setMintGoldPause === 1) {
                compStorage.methods._setMintGoldPause(true).send({from: accounts}).on('transactionHash', (hash) => {})
            } else {
                compStorage.methods._setMintGoldPause(false).send({from: accounts}).on('transactionHash', (hash) => {})
            }
        }

        return (
            <div className='info'>
                <h1>Comptroller function</h1>
                <ul>
                    <li>
                        <h5>_setPendingAdmin</h5>
                        <div className="form-group flex">
                            <label htmlFor="_setPendingAdmin">address</label>
                            <input 
                                type="text" 
                                name="_setPendingAdmin" 
                                placeholder="0x.." 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setPendingAdmin}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_confirmNewAdmin</h5>
                        <div className="form-group flex">
                            <label htmlFor="_confirmNewAdmin">Address</label>
                            <input 
                                type="text" 
                                name="_confirmNewAdmin"
                                placeholder="0x.."
                                onChange={this.handleInputChange} 
                            />
                            <button className="btn btn-primary" onClick={_confirmNewAdmin}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_setAurumController</h5>
                        <div className="form-group flex">
                            <label htmlFor="_setAurumController">Address</label>
                            <input 
                                type="text" 
                                name="_setAurumController" 
                                placeholder="0x.." 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setAurumController}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_setTreasuryData</h5>
                        <div className="form-group flex">
                            <label htmlFor="_setTreasuryData1">Address</label>
                            <input 
                                type="text" 
                                name="_setTreasuryData1" 
                                placeholder="0x..Guardian" 
                                onChange={this.handleInputChange}
                            />
                            <label htmlFor="_setTreasuryData2">Address</label>
                            <input 
                                type="text" 
                                name="_setTreasuryData2" 
                                placeholder="0x..TreasuryAddress" 
                                onChange={this.handleInputChange}
                            />
                            <label htmlFor="_setTreasuryData3">Number</label>
                            <input 
                                type="text" 
                                name="_setTreasuryData3" 
                                placeholder="e18 ..TreasuryPercent" 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setTreasuryData}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_setComptrollerCalculation</h5>
                        <div className="form-group flex">
                            <label htmlFor="_setComptrollerCalculation">Address</label>
                            <input 
                                type="text" 
                                name="_setComptrollerCalculation" 
                                placeholder="0x.." 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setComptrollerCalculation}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_setAurumSpeed</h5>
                        <div className="form-group flex">
                            <label htmlFor="_setAurumSpeed2">Address</label>
                            <input 
                                type="text" 
                                name="_setAurumSpeed1" 
                                placeholder="0x.. LendToken" 
                                onChange={this.handleInputChange}
                            />
                            <label htmlFor="_setAurumSpeed2">Number</label>
                            <input 
                                type="text" 
                                name="_setAurumSpeed2" 
                                placeholder="rate per seconds" 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setAurumSpeed}>Submit</button>
                        </div>
                    </li>
                </ul>
                <h1>Comptroller Storage function</h1>
                <ul>
                    <li>
                        <h5>_setComptrollerAddress</h5>
                        <div className="form-group flex">
                            <label htmlFor="_setComptrollerAddress">address</label>
                            <input 
                                type="text" 
                                name="_setComptrollerAddress" 
                                placeholder="0x.." 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setComptrollerAddress}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_setCloseFactor</h5> <p>Maximum collateral asset can be liquidate</p>
                        <div className="form-group flex">
                            <label htmlFor="_setCloseFactor">Number</label>
                            <input 
                                type="text" 
                                name="_setCloseFactor" 
                                placeholder="value e18" 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setCloseFactor}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_setCollateralFactor</h5>  <p>Set each LendToken which can be used as collateral credits</p>
                        <div className="form-group flex">
                            <label htmlFor="_setCollateralFactor1">Address</label>
                            <input 
                                type="text" 
                                name="_setCollateralFactor1" 
                                placeholder="0x.. LendTokenAddress" 
                                onChange={this.handleInputChange}
                            />
                            <label htmlFor="_setCollateralFactor2">Number</label>
                            <input 
                                type="text" 
                                name="_setCollateralFactor2" 
                                placeholder="value e18" 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setCollateralFactor}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_setLiquidationIncentive</h5> <p>Liquidate bounty must greater than 1e18</p>
                        <div className="form-group flex">
                            <label htmlFor="_setLiquidationIncentive">Number</label>
                            <input 
                                type="text" 
                                name="_setLiquidationIncentive" 
                                placeholder="value e18" 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setLiquidationIncentive}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_supportMarket</h5> <p>List new LendToken</p>
                        <div className="form-group flex">
                            <label htmlFor="_supportMarket">Address</label>
                            <input 
                                type="text" 
                                name="_supportMarket" 
                                placeholder="0x.." 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_supportMarket}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_setMarketBorrowCaps</h5>
                        <div className="form-group flex">
                            <label htmlFor="_setMarketBorrowCaps1">Address</label>
                            <input 
                                type="text" 
                                name="_setMarketBorrowCaps1" 
                                placeholder="0x..LendToken Address" 
                                onChange={this.handleInputChange}
                            />
                            <label htmlFor="_setMarketBorrowCaps2">Number</label>
                            <input 
                                type="text" 
                                name="_setMarketBorrowCaps2" 
                                placeholder="e18" 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setMarketBorrowCaps}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_setGOLDMintRate</h5>
                        <div className="form-group flex">
                            <label htmlFor="_setGOLDMintRate">Number</label>
                            <input 
                                type="text" 
                                name="_setGOLDMintRate" 
                                placeholder="0-10000 in percent" 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setGOLDMintRate}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_setPriceOracle</h5>
                        <div className="form-group flex">
                            <label htmlFor="_setPriceOracle">Address</label>
                            <input 
                                type="text" 
                                name="_setPriceOracle" 
                                placeholder="0x..." 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setPriceOracle}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_setProtocolPaused</h5>
                        <div className="form-group flex">
                            <label htmlFor="_setProtocolPaused">Bool</label>
                            <input 
                                type="text" 
                                name="_setProtocolPaused" 
                                placeholder="True False" 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setProtocolPaused}>Submit</button>
                        </div>
                    </li>
                    <li>
                        <h5>_setMintGoldPause</h5>
                        <div className="form-group flex">
                            <label htmlFor="_setMintGoldPause">Bool</label>
                            <input 
                                type="text" 
                                name="_setMintGoldPause" 
                                placeholder="True False" 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={_setMintGoldPause}>Submit</button>
                        </div>
                    </li>
                </ul>
            </div>
        )
    }

}

class AdminInterface extends Component {
    render() {

        let content    
        
        if(this.props.mainstate.loadMarket === false || this.props.mainstate.loading === true){
            content = <Loading/>
        }
        else {
            content = <Admin mainstate={this.props.mainstate}/>
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

export default AdminInterface