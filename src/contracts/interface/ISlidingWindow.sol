// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISlidingWindow {

    struct Observation {
        uint timestamp;
        uint price0Cumulative;
        uint price1Cumulative;
    }

    function factory() external view returns(address);
    function windowSize() external view returns(uint);
    function granularity() external view returns(uint8);
    function periodSize() external view returns(uint);

    function observationIndexOf(uint timestamp) external view returns (uint8 index);

    function update(address tokenA, address tokenB) external; //Update price of pair tokens

    function consult(address tokenIn, uint amountIn, address tokenOut) external view returns (uint);  //get the price of tokenIn to tokenOut

}