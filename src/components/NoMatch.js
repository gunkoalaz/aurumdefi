import React from 'react'
import { ExclamationTriangle } from 'react-bootstrap-icons'
import './css/Main.css'

const NoMatch = () => {
    return (
        <div className='mainbox'>
            <div>
                <br></br>
                <h1 style={{fontSize: '35vh'}}>
                    <ExclamationTriangle />
                </h1>
                <h1>404 Not Found</h1>
            </div>
        </div>
    )
}

export default NoMatch