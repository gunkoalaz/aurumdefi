import React from "react"
import './css/Navbar.css'
import { Link } from "react-router-dom"

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
                </ul>
            </div>
            <div className="lt-space"></div>
            <div className="bottom">
                <div>
                    <p>${armPrice}</p>
                    <div>BUY</div>

                </div>
            </div>
        </div>
    )
}

export default Navbar