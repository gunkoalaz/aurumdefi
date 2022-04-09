import React from "react"
import './css/Navbar.css'
import { Link } from "react-router-dom"
import armlogo from "../armlogo.png"
import {Github, Book, Telegram} from "react-bootstrap-icons"

const e18 = 1000000000000000000
// const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935"

const Navbar = (props) => {
    let armPrice = props.price.armPrice
    armPrice /= e18
    armPrice = parseFloat(armPrice).toFixed(3)
    
    if(isNaN(armPrice)) { armPrice = '0.000'}
    return (
        <div className="lt-tab">
            <div>
                <ul className="navbar">
                    <li className="link"><Link to='/'>Info</Link></li>
                    <li className="link"><Link to='/lending'>Lending</Link></li>
                    <li className="link"><Link to='/aurum'>Aurum</Link></li>
                    <li className="link"><Link to='/armvault'>ARM Vault</Link></li>
                    <li className="link"><Link to='/liquidate'>Liquidate</Link></li>
                    {props.networkId === 55556 || props.networkId === 5777 ? <li className="link"><Link to='/mint'>=TEST:Mint=</Link></li> : ''}
                </ul>
            </div>
            <div className="lt-space"></div>
            <div className="bottom">
                <div className="nav-footer-box">
                    <div className="flex">
                        <img src={armlogo} alt='armtoken' width={"20%"} height={'20%'} className={"m-1"}/>
                        <p>${armPrice}</p>
                    </div>
                    <div className="flex">
                        {/* <button  onClick={(e) => {e.preventDefault(); window.location.href='https://reix.foodcourt.finance/#/swap';}} className="button">Buy ARM</button> */}
                        <a href="https://reix.foodcourt.finance/#/swap" target={"_blank"} className="button"> Buy ARM </a>
                    </div>
                    <div className="flex">
                        <a href="https://github.com/gunkoalaz/aurumdefi" target={"_blank"} className="iconlink"><Github /></a>
                        <a href="https://aurumdefi.gitbook.io/aurum-defi/" target={"_blank"} className="iconlink"><Book /></a>
                        <a href="https://t.me/aurumdefi" target={"_blank"} className="iconlink"><Telegram /></a>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default Navbar