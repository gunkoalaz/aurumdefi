import React from 'react'
import { ProgressBar } from 'react-bootstrap';
import { XCircle } from 'react-bootstrap-icons';
import './css/Main.css'

const Loading = (props) => {
    let content;

    if(props.mainstate.account === '0x0'){
        content = 
        <div>
            <div>
                <br></br>
                <h1>Welcome to AurumDeFi</h1>
                <p>please login with metamask.</p>
            </div>
        </div>
    } else { 
        if(props.mainstate.networkId === 5777 || props.mainstate.networkId === 55555 || props.mainstate.networkId === 55556){
            content = 
            <div>
                <div>
                    <br></br>
                    <h1>Loading data..</h1>
                    <div className="spinner-border text-warning m-5" style={{width: '10vh', height: '10vh'}} role="status">
                        <span className="sr-only m-5">Loading...</span>
                    </div>
                    <div style={{width: '50%', margin: 'auto'}}>
                        <ProgressBar animated variant='warning' now={props.mainstate.loadingNow} />
                    </div>
                    <p>this may take upto a minute.</p>
                </div>
            </div>
        } else {

            content = 
            <div>
                <div>
                    <br></br>
                    <h1 style={{color: 'red'}}><XCircle /> Wrong network </h1>
                    <p>please connect to REI chain or REI testnet.</p>
                </div>
            </div>
        }
    }


    return (
        content
    )
}

export default Loading