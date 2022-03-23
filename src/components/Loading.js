import React from 'react'
import './css/Main.css'

const Loading = () => {
    return (
        <div>
            <div className='mainbox'>
                <h1>Loading data..</h1>
                <div className="spinner-border text-warning m-5" style={{width: '10vw', height: '10vw'}} role="status">
                    <span className="sr-only">Loading...</span>
                </div>
                <p>please login with metamask.</p>
            </div>
        </div>
    )
}

export default Loading