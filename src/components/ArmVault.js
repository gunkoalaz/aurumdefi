import React from 'react'
import { useState } from 'react'
import './css/Main.css'
import './css/ArmVault.css'
import armlogo from '../armlogo.png'
import Loading from './Loading.js'
import Constructing from './Constructing.js'
import Web3 from 'web3'

const e18 = 1000000000000000000
const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935"

const MainArmVault = (props) => {
    const superState = props.mainstate.armVault
    const armContract = superState.armContract
    const stakingArmContract = superState.contract


    const accRewardPerShare = superState.getAccRewardPerShare
    const rewardDistributionIndex = superState.rewardDistributionIndex / 60 / 60 / 24

    let armBalance = superState.armBalance
    let armAllowanceToVault = superState.armAllowanceToVault
    let userStakingBalance = superState.userStakingBalance
    let getTotalStakedARM = superState.getTotalStakedARM
    let totalAvailableReward = superState.totalAvailableReward
    let getRewardBalanceOf = superState.getRewardBalanceOf

    const armPrice = props.mainstate.price.armPrice


    let timeSinceLastReward = props.mainstate.time - superState.getLastRewardTimestamp
    let updatePendingReward = (timeSinceLastReward * accRewardPerShare / e18 * userStakingBalance / e18) + getRewardBalanceOf
    let updateTotalAvailableReward = totalAvailableReward / e18 - (getTotalStakedARM / e18 * accRewardPerShare / e18 * timeSinceLastReward)
    let APR = parseFloat(updateTotalAvailableReward * 365 * e18 / rewardDistributionIndex * e18 / getTotalStakedARM / armPrice * 100).toFixed(2)
    updatePendingReward = parseFloat(updatePendingReward).toFixed(4)
    updateTotalAvailableReward = parseFloat(updateTotalAvailableReward).toFixed(4)

        getTotalStakedARM = Web3.utils.fromWei(getTotalStakedARM,'Ether')
        getTotalStakedARM = parseFloat(getTotalStakedARM).toFixed(4)
        totalAvailableReward = Web3.utils.fromWei(totalAvailableReward,'Ether')
        totalAvailableReward = parseFloat(totalAvailableReward).toFixed(4)
        getRewardBalanceOf = Web3.utils.fromWei(getRewardBalanceOf,'Ether')
        userStakingBalance = Web3.utils.fromWei(userStakingBalance,'Ether')
        armAllowanceToVault = Web3.utils.fromWei(armAllowanceToVault,'Ether')
        armBalance = Web3.utils.fromWei(armBalance,'Ether')

    const [valueStake, setStake] = useState()
    const [valueUnstake, setUnstake] = useState()
    const floatRegExp = new RegExp('^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$')

    //Input manipulator
    const stakeAmountChange = (e) => {
        let oldAmount = valueStake;
        let newAmount = e.target.value
        let oldfloat = parseFloat(oldAmount)
        let newfloat = parseFloat(newAmount)
        let max = e.target.max
        if (floatRegExp.test(newAmount)){
            if(newfloat > max) {
                setStake(max)
            }else {
                if(newfloat===oldfloat){
                    if((newAmount.length<=2 && newAmount.charAt(newAmount.length-1) === '.') || newAmount.charAt(newAmount.length-1) === '0') {
                        if(newAmount==='00'){
                            setStake(0)
                        } else {
                            setStake(newAmount)
                        }
                    } else {
                        setStake(newAmount)
                    }
                } else {
                    setStake(newAmount)
                }
            }
        } else {
            if(newAmount===''){
                setStake('')
            } else {
                setStake(valueStake)
            }
        }
    }
    //Input manipulator
    const unstakeAmountChange = (e) => {
        let oldAmount = valueUnstake;
        let newAmount = e.target.value
        let oldfloat = parseFloat(oldAmount)
        let newfloat = parseFloat(newAmount)
        let max = e.target.max
        if (floatRegExp.test(newAmount)){
            if(newfloat > max) {
                setUnstake(max)
            }else {
                if(newfloat===oldfloat){
                    if((newAmount.length<=2 && newAmount.charAt(newAmount.length-1) === '.') || newAmount.charAt(newAmount.length-1) === '0') {
                        if(newAmount==='00'){
                            setUnstake(0)
                        } else {
                            setUnstake(newAmount)
                        }
                    } else {
                        setUnstake(newAmount)
                    }
                } else {
                    setUnstake(newAmount)
                }
            }
        } else {
            if(newAmount===''){
                setUnstake('')
            } else {
                setUnstake(valueUnstake)
            }
        }
    }

    //
    //Smart contract interact function
    //
    const approve = () => {
        armContract.methods.approve(stakingArmContract._address, MAX_UINT).send({from: props.mainstate.account}).on('transactionHash', (hash) => {
            props.update()
        })
    }
    const staking = () => {
        let amount
        amount = valueStake.toString()
        amount = Web3.utils.toWei(amount, 'Ether')
        stakingArmContract.methods.stakeARM(amount).send({from: props.mainstate.account}).on('transactionHash', (hash) => {
            props.update()
        })
    }
    const unstaking = () => {
        let amount
        amount = valueUnstake.toString()
        amount = Web3.utils.toWei(amount, 'Ether')
        stakingArmContract.methods.unstakeARM(amount).send({from: props.mainstate.account}).on('transactionHash', (hash) => {
            props.update()
        })
    }
    const claimReward = () => {
        stakingArmContract.methods.manualClaimReward().send({from: props.mainstate.account}).on('transactionHash', (hash) => {
            props.update()
        })
    }

    const setMaxStake = () => {
        setStake(armBalance)
    }
    const setMaxUnstake = () => {
        setUnstake(userStakingBalance)
    }

    //Component button
    let approveFirst
    if( parseInt(armAllowanceToVault) === 0 ){
        approveFirst = <button className='button' onClick={approve}>Approve</button>
    } else {
        if (valueStake === '' || valueStake === null || isNaN(valueStake) || valueStake === '0'){
            approveFirst = <button className='button-inactive'>Stake</button>
        } else {
            if (superState.armAllowanceToVault / e18 >= valueStake || valueStake === '' ) {
                approveFirst = <button className='button' onClick={staking}>Stake</button>
            } else {
                approveFirst = <button className='button' onClick={approve}>Approve</button>
            }
        }
    }

    let unStakeButton
    if (valueUnstake === '' || valueUnstake === null || isNaN(valueUnstake) || valueUnstake === '0'){
        unStakeButton = <button className='button-inactive'>Unstake</button>
    } else {
        unStakeButton = <button className='button' onClick={unstaking}>Unstake</button>
    }

    let claimRewardButton
    if (updatePendingReward === '0.0000' || isNaN(updatePendingReward)){
        claimRewardButton = <button className='button-inactive'>Claim</button>
    } else {
        claimRewardButton = <button className='button' onClick={claimReward}>Claim</button>
    }

    // const testFunction = () => {
    //     //Set reward spendingDuration to 1 hr
    //     stakingArmContract.methods.setRewardDurationSpending('1').send({from: props.mainstate.account}).on('transactionHash', (hash) => {
    //         props.update()
    //     })
    // }


    //Main ArmVault
    return(
        <div className='armvault'>
            <div className='armvault-header'>
                <h1>Arm Vault</h1>
                <p>ArmVault let you stake ARM to be the stake holder of the project</p>
                <p>Benefit included governance voting, yield aggregate</p>
            </div>
            <div className='logopic-container'>
                <img src={armlogo} className="logopic" alt="armtokens"></img>
            </div>
            <div className='vault'>
                <div className='vault-head'>
                    <h3>ARM vault</h3>
                </div>
                <div className='vault-body'>
                    <div className='vault-info'>
                        <h1>Vault ARM staked</h1>
                        <p>{getTotalStakedARM}</p>

                        <h1>Available reward</h1>
                        <p>{updateTotalAvailableReward} BUSD</p>

                        <h1>Staking APR</h1>
                        <p>{APR}%</p>
                        
                        <h1>Reward distribution index</h1>
                        <p>{rewardDistributionIndex} Days</p>
                    </div>
                    <div className='vault-stake'>
                        <div className='vault-stake-component'>
                            <div className='vault-stake-detail'>
                                <h5>Your available ARM</h5>
                                <p onClick={setMaxStake} className="maxbutton">{armBalance}</p>
                            </div>
                            <div className='flexRt'>
                                <input className='input'
                                    type='text' 
                                    placeholder='0' 
                                    onChange={stakeAmountChange}
                                    min = {'0'}
                                    max = {armBalance}
                                    value={valueStake}
                                />
                                <div className='vault-button'>
                                    {approveFirst}
                                </div>
                            </div>
                        </div>
                        <div className='vault-stake-component'>
                            <div className='vault-stake-detail'>
                                <h5>Your Staking</h5>
                                <p onClick={setMaxUnstake} className="maxbutton">{userStakingBalance}</p>
                            </div>
                            <div className='flexRt'>
                                <input className='input'
                                    type='text' 
                                    placeholder='0' 
                                    onChange={unstakeAmountChange}
                                    min = {'0'}
                                    max = {userStakingBalance}
                                    value={valueUnstake}
                                />
                                <div className='vault-button'>
                                    {unStakeButton}
                                </div>
                            </div>
                        </div>
                        <div className='vault-stake-component'>
                            <div className='vault-stake-detail'>
                                <h5>Your Reward Pending</h5>
                                <p>{updatePendingReward}</p>
                                <div className='vault-button'>
                                    {claimRewardButton}
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}

//Loading screen switcher
const ArmVault = (props) => {
    let superState = props.mainstate
    let content
    if(superState.loading === true){
        // content = <Constructing />
        content = <Loading mainstate={props.mainstate}/>
    }
    else {
        if(props.mainstate.networkId === 55556) {
            content = <MainArmVault mainstate={superState} update={props.updateWeb3}/>
        } else {
            content = <Constructing />
        }
    }
    return (
        <div>
            <div className='mainbox'>
                {content}
            </div>
        </div>
    )
}

export default ArmVault