import React from "react"
import './css/Header.css'
import logo from '../logo.png'

const Header = (props) => {
    let mainstate = props.mainstate
    let connectButton
    let shortAddress
    if (mainstate.account !== '0x0') {
        shortAddress = mainstate.account.substr(0,5)+".."+mainstate.account.substr(38,4)
        connectButton = 
            <div>
                <button className="button" onClick={props.disconnectMetamask}>{shortAddress}</button>
            </div>
    }
    else {
        connectButton =
        <div>
            <button className="button" onClick={props.connectMetamask}>Connect</button>
        </div>
    }
    return (
        <div className="header">
            <div className="hd-box">
                <div className="logo">
                    <a href='./'>
                        <img src={logo} alt='aurum defi' style={{width: '4vw'}}/>
                        <span className="m-3">Aurum DeFi</span>
                    </a>
                </div>
                <div className="hd-space">

                </div>
                <div className="web3connect">
                    {connectButton}
                </div>
            </div>
        </div>
    )
}

export default Header