import React from 'react'
import { useState } from 'react'
import './css/Main.css'
import './css/ArmVault.css'
import armlogo from '../armlogo.png'
import Loading from './Loading.js'
// import Constructing from './Constructing.js'
import Web3 from 'web3'

const BigNumber = require('bignumber.js');
const e18 = 1000000000000000000
const MAX_UINT = "115792089237316195423570985008687907853269984665640564039457584007913129639935"

const MainArmVault = (props) => {
    const superState = props.mainstate.armVault
    // const armContract = superState.armContract
    const stakingArmContract = superState.contract


    const accRewardPerShare = superState.getAccRewardPerShare
    let rewardDistributionIndex = superState.rewardDistributionIndex / 60 / 60 / 24
    if(isNaN(rewardDistributionIndex)) {rewardDistributionIndex = BigNumber(0).toFixed(0)};

    let armBalance = new BigNumber(superState.armBalance);
    let armLPBalance = new BigNumber(superState.armLPBalance);
    let armLPAllowanceToVault = new BigNumber(superState.armLPAllowanceToVault)
    let userStakingBalance = new BigNumber(superState.userStakingBalance)
    let getTotalStakedARM = new BigNumber(superState.getTotalStakedARM)
    let totalAvailableReward = new BigNumber(superState.totalAvailableReward)
    let getRewardBalanceOf = new BigNumber(superState.getRewardBalanceOf)

    let armInLP = new BigNumber(superState.armInLP);
    let busdInLP = new BigNumber(superState.busdInLP);
    let totalSupplyLP = new BigNumber(superState.totalSupplyLP);

    if(isNaN(armBalance)) {armBalance = BigNumber(0)};
    if(isNaN(armLPBalance)) {armLPBalance = BigNumber(0)};
    if(isNaN(armLPAllowanceToVault)) {armLPAllowanceToVault = BigNumber(0)};
    if(isNaN(userStakingBalance)) {userStakingBalance = BigNumber(0)};
    if(isNaN(getTotalStakedARM)) {getTotalStakedARM = BigNumber(0)};
    if(isNaN(totalAvailableReward)) {totalAvailableReward = BigNumber(0)};
    if(isNaN(getRewardBalanceOf)) {getRewardBalanceOf = BigNumber(0)};

    const armPrice = props.mainstate.price.armPrice;


    let timeSinceLastReward = props.mainstate.time - superState.getLastRewardTimestamp
    let updatePendingReward = (timeSinceLastReward * accRewardPerShare / e18 * userStakingBalance / e18) + getRewardBalanceOf
    let updateTotalAvailableReward = totalAvailableReward.div(e18).minus(getTotalStakedARM.div(e18).times(accRewardPerShare).div(e18).times(timeSinceLastReward))
    let APR = (updateTotalAvailableReward.times(365).times(e18).div(rewardDistributionIndex).times(e18).div(getTotalStakedARM).div(armPrice).times(totalSupplyLP).div(armInLP).times(100)).toFixed(2)
    if(isNaN(updateTotalAvailableReward)) {updateTotalAvailableReward = BigNumber(0)};
    if(isNaN(APR)) {APR = BigNumber(0).toFixed(2)};
    if(isNaN(updatePendingReward)) {updatePendingReward = BigNumber(0)};
    updatePendingReward = parseFloat(updatePendingReward).toFixed(4)
    updateTotalAvailableReward = parseFloat(updateTotalAvailableReward).toFixed(4)

    getTotalStakedARM = getTotalStakedARM.div(e18);
    totalAvailableReward = totalAvailableReward.div(e18);
    totalAvailableReward = totalAvailableReward.toFixed(2,1)
    getRewardBalanceOf = getRewardBalanceOf.div(e18).toFixed(6,1);
    userStakingBalance = userStakingBalance.div(e18).toFixed(4,1);
    armLPAllowanceToVault = armLPAllowanceToVault.div(e18).toFixed(4,1);
    armBalance = armBalance.div(e18).toFixed(4,1);

    let stakedArmInLP = getTotalStakedARM.times(armInLP).div(totalSupplyLP)
    let stakedBUSDInLP = getTotalStakedARM.times(busdInLP).div(totalSupplyLP)
    if(isNaN(stakedArmInLP)) {stakedArmInLP = BigNumber(0)};
    if(isNaN(stakedBUSDInLP)) {stakedBUSDInLP = BigNumber(0)};

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
        superState.armLPContract.methods.approve(stakingArmContract._address, MAX_UINT).send({from: props.mainstate.account}).on('transactionHash', (hash) => {
            props.update()
        })
    }
    const staking = () => {
        let amount
        amount = valueStake.toString()
        amount = Web3.utils.toWei(amount, 'Ether')
        console.log(amount);
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
        setStake(armLPBalance.div(e18).toFixed(12,1))
    }
    const setMaxUnstake = () => {
        setUnstake(userStakingBalance)
    }

    //Component button
    let approveFirst
    if( parseInt(armLPAllowanceToVault) === 0 ){
        approveFirst = <button className='button' onClick={approve}>Approve</button>
    } else {
        if (valueStake === '' || valueStake === null || isNaN(valueStake) || valueStake === '0'){
            approveFirst = <button className='button-inactive'>Stake</button>
        } else {
            if (superState.armLPAllowanceToVault / e18 >= valueStake || valueStake === '' ) {
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
                        <h1>Vault ARM-LP staked</h1>
                        <p>{getTotalStakedARM.toFixed(4,1)} LP</p>
                        <p style={{color:'lightgray', fontSize: '1rem'}}>({stakedArmInLP.toFixed(2,1)} ARM + 
                        {stakedBUSDInLP.toFixed(2,1)} BUSD)
                         </p>

                        <h1>Available reward</h1>
                        <p>{updateTotalAvailableReward} kBUSD</p>

                        <h1>Staking APR</h1>
                        <p>{APR}%</p>
                        
                        <h1>Reward distribution index</h1>
                        <p>{rewardDistributionIndex} Days</p>
                    </div>
                    <div className='vault-stake'>
                        <div className='vault-stake-component'>
                            <div className='vault-stake-detail'>
                                <h5>Your available ARM LPToken</h5>
                                <p onClick={setMaxStake} className="maxbutton">{armLPBalance.div(e18).toFixed(6,1)}</p>
                            </div>
                            <div className='flexRt'>
                                <input className='input'
                                    type='text' 
                                    placeholder='0' 
                                    onChange={stakeAmountChange}
                                    min = {'0'}
                                    max = {parseFloat(armLPBalance.div(e18).toFixed(6,1))}
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
        content = <MainArmVault mainstate={superState} update={props.updateWeb3}/>
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