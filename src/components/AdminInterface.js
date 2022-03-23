import React, {Component} from 'react'
import Web3 from 'web3'
import Comptroller from '../truffle_abis/Comptroller.json'
import CompStorage from '../truffle_abis/ComptrollerStorage.json'
import CompCalculate from '../truffle_abis/ComptrollerCalculation.json'

class AdminInterface extends Component {
    constructor(props){
        super(props)
        this.state = {}
        this.handleInputChange = this.handleInputChange.bind(this)
    }

    handleInputChange(event) {
        const value = event.target.value;
        const name = event.target.name;

        console.log(name,"  ", value)
        this.setState({[name]: value})
    }
    render() {
        const web3 = window.web3
        const accounts = this.props.mainstate.account
        const networkId = this.props.mainstate.networkId

        const _setPendingAdmin = () => {

        }
        return (
            <div className='mainbox'>
                <div className='info'>
                    <h1>Comptroller function</h1>
                    <ul>
                        <li>
                            <form>
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
                            </form>
                        </li>
                        <li>
                            <form>
                                <h5>_confirmNewAdmin</h5>
                                <div className="form-group flex">
                                    <label htmlFor="Input1">Address</label>
                                    <input type="text" id="Input1" placeholder="0x.." />
                                    <button type="submit" className="btn btn-primary">Submit</button>
                                </div>
                            </form>
                        </li>
                    </ul>
                </div>
            </div>
        )
    }

}

export default AdminInterface