import React, {Component} from 'react'
import Loading from './Loading.js'
import BTC from '../truffle_abis/BTC.json'
import BUSD from '../truffle_abis/BUSD.json'
import USDT from '../truffle_abis/Tether.json'

class MintMain extends Component {
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

        //Comptroller
        const mintTokens = () => {
            const web3 = window.web3
            const networkId = this.props.mainstate.networkId
            const accounts = this.props.mainstate.account
            

            const btc = new web3.eth.Contract(BTC.abi, BTC.networks[networkId].address)
            const busd = new web3.eth.Contract(BUSD.abi, BUSD.networks[networkId].address)
            const usdt = new web3.eth.Contract(USDT.abi, USDT.networks[networkId].address)

            let amount = web3.utils.toWei(this.state.input2, 'Ether')
            if(this.state.input1 === 'BTC'){
                btc.methods.mint(amount).send({from: accounts}).on('transactionHash', (hash) => {})
            } else if(this.state.input1 === 'USDT') {
                usdt.methods.mint(amount).send({from: accounts}).on('transactionHash', (hash) => {})
            } else if(this.state.input1 === 'BUSD') {
                busd.methods.mint(amount).send({from: accounts}).on('transactionHash', (hash) => {})
            }
        }

        return (
            <div className='info'>
                <h1>Mint tokens for testnet</h1>
                <ul>
                    <li>
                        <h5>Interface .... no need to beautify ^^</h5>
                        <div className="form-group flex">
                            <label className="my-1 mr-2" htmlFor="input1">LendToken</label>
                            <select className="custom-select my-1 mr-sm-2" name="input1" onChange={this.handleInputChange}>
                                <option>Choose...</option>
                                <option value='BTC'> BTC </option>
                                <option value='USDT'> USDT </option>
                                <option value='BUSD'> BUSD </option>
                            </select>
                            <label htmlFor="input2">Number</label>
                            <input 
                                type="text" 
                                name="input2" 
                                placeholder="amount" 
                                onChange={this.handleInputChange}
                            />
                            <button className="btn btn-primary" onClick={mintTokens}>Submit</button>
                        </div>
                    </li>
                </ul>
            </div>
        )
    }

}

class MintTestTokens extends Component {
    render() {

        let content    
        
        if(this.props.mainstate.loadMarket === false || this.props.mainstate.loading === true){
            content = <Loading/>
        }
        else {
            content = <MintMain mainstate={this.props.mainstate}/>
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

export default MintTestTokens