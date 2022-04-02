import React, {Component} from 'react'
import Loading from './Loading.js'
import tBNB from '../truffle_abis/tBNB.json'
import tETH from '../truffle_abis/tETH.json'
import tKUMA from '../truffle_abis/tKUMA.json'
import tKUB from '../truffle_abis/tKUB.json'
import tNEAR from '../truffle_abis/tNEAR.json'

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
            

            const BNB = new web3.eth.Contract(tBNB.abi, tBNB.networks[networkId].address)
            const ETH = new web3.eth.Contract(tETH.abi, tETH.networks[networkId].address)
            const KUB = new web3.eth.Contract(tKUB.abi, tKUB.networks[networkId].address)
            const KUMA = new web3.eth.Contract(tKUMA.abi, tKUMA.networks[networkId].address)
            const NEAR = new web3.eth.Contract(tNEAR.abi, tNEAR.networks[networkId].address)

            let amount = web3.utils.toWei(this.state.input2, 'Ether')
            if(this.state.input1 === 'tBNB'){
                BNB.methods.mint(amount).send({from: accounts}).on('transactionHash', (hash) => {})
            } else if(this.state.input1 === 'tKUB') {
                KUB.methods.mint(amount).send({from: accounts}).on('transactionHash', (hash) => {})
            } else if(this.state.input1 === 'tETH') {
                ETH.methods.mint(amount).send({from: accounts}).on('transactionHash', (hash) => {})
            } else if(this.state.input1 === 'tKUMA') {
                KUMA.methods.mint(amount).send({from: accounts}).on('transactionHash', (hash) => {})
            } else if(this.state.input1 === 'tNEAR') {
                NEAR.methods.mint(amount).send({from: accounts}).on('transactionHash', (hash) => {})
            }
        }

        return (
            <div className='info'>
                <h1>Mint tokens for testnet</h1>
                <ul>
                    <li>
                        <h5>Interface .... no need to beautify ^^</h5>
                        <div className="form-group">
                            <label className="my-1 mr-2" htmlFor="input1">LendToken</label>
                            <select className="custom-select my-1 mr-sm-2" name="input1" onChange={this.handleInputChange}>
                                <option>Choose...</option>
                                <option value='tBNB'> tBNB </option>
                                <option value='tETH'> tETH </option>
                                <option value='tKUB'> tKUB </option>
                                <option value='tKUMA'> tKUMA </option>
                                <option value='tNEAR'> tNEAR </option>
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