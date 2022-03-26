import React from "react"
import { useState } from "react"
import './css/Header.css'
import logo from '../logo.png'

const Header = (props) => {
    let mainstate = props.mainstate
    let connectButton
    let shortAddress
    if (mainstate.account !== '0x0') {
        shortAddress = mainstate.account.substr(0,5)+".."+mainstate.account.substr(38,4)
        connectButton = 
            <button className="button" onClick={props.disconnectMetamask}>{shortAddress}</button>
    }
    else {
        connectButton =
            <button className="button" onClick={props.connectMetamask}>Connect</button>
    }
    const [toggleState, setToggle] = useState(false)
    const toggle = (x) => {
        if(toggleState === true){
            setToggle(false)
        } else {
            setToggle(true)
        }
    }

    return (
        <div className="header">
            <div className="hd-box">
                <div className="logo">
                    <a href='./'>
                        <img src={logo} alt='aurum defi' style={{height: '7vh'}}/>
                        <span className="m-2">Aurum DeFi</span>
                    </a>
                </div>
                <div className="hd-space">
                </div>
                <div className="web3connect">
                    {connectButton}
                </div>
                <div className={toggleState === true ? "change container menuNav" : "container menuNav"} onClick={toggle}>
                    <div className="bar1"></div>
                    <div className="bar2"></div>
                    <div className="bar3"></div>
                </div>
            </div>
            <div className={toggleState === true ? "menuToggleShow" : "menuToggleHide"}>
                <ul className="topnavbar">
                    <a href="/"><li className="menulist">Info</li></a>
                    <a href="/lending"><li className="menulist">Lending</li></a>
                    <a href="/aurum"><li className="menulist">Aurum</li></a>
                    <a href="/armvault"><li className="menulist">ARM vault</li></a>
                    <a href="/liquidate"><li className="menulist">Liquidate</li></a>
                    <a href="/mint"><li className="menulist">MINT test tokens</li></a>
                </ul>
            </div>
        </div>
    )
}

export default Header