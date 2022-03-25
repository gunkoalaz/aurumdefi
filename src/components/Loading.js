import React from 'react'
import './css/Main.css'

const Loading = () => {
    return (
        <div>
            <div>
                <br></br>
                <h1>Loading data..</h1>
                <div className="spinner-border text-warning m-5" style={{width: '10vw', height: '10vw'}} role="status">
                    <span className="sr-only m-5">Loading...</span>
                </div>
                <p>please login with metamask.</p>
            </div>
        </div>
    )
}

export default Loading