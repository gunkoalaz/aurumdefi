// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interface/IAurumOracleCentralized.sol";


contract MultisigAurumOracle {

    event Submit(uint indexed txId);
    event Approve(uint indexed txId, address indexed approveBy);
    event Reject(uint indexed txId, address indexed revokeBy);
    event Execute(uint indexed txId);

    struct Transaction {
        address token;
        uint128 price;
        uint8 callswitch; // this will trigger different function, 0 = updateAssetPrice, 1 = updateAssetPriceFromWindow, 2 = updateGoldPrice
        bool executed;
        uint expireTimestamp; // set expire time, in case the system fetch multiple submit, first submit can be execute others will expire before reach the period time
    }
    Transaction[] public transactions;

    IAurumOracleCentralized public oracle;
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint8 public required; // Amount of approve wallet to execute transaction
    mapping (uint => mapping(address => bool)) public approved; //[transaction][owner] => boolean
    mapping (uint => mapping(address => bool)) public voted; //[transaction][owner] => boolean


    constructor (address oracle_, address[] memory owners_, uint8 required_) {
        require(owners_.length > 0, "owners invalid");
        require(required_ > 0 && required_ <= owners_.length, "required invalid");

        oracle = IAurumOracleCentralized(oracle_);
        
        for(uint i; i< owners_.length; i++){
            address owner = owners_[i];

            require (owner != address(0), "owner is address 0");
            require (!isOwner[owner], "owner is not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = required_;
    }

    modifier onlyOwner {
        require(isOwner[msg.sender], "only owner");
        _;
    }

    modifier txExists(uint txId_){
        require (txId_ < transactions.length, "tx does not exist");
        _;
    }
    modifier notVoted(uint txId_){
        require (!voted[txId_][msg.sender], "tx already approved");
        _;
    }
    modifier notExecuted(uint txId_){
        require (!transactions[txId_].executed, "tx already executed");
        _;
    }

    modifier notExpire(uint txId_){
        require (transactions[txId_].expireTimestamp >= block.timestamp, "tx expired");
        _;
    }

    function submit(address token_, uint128 price_, uint8 callswitch_) external onlyOwner{
        uint expire = block.timestamp + 10 minutes; // set expire time of the transaction = 10 minutes
        //Create new transaction waiting others to confirm.
        transactions.push(
            Transaction({
                token: token_,
                price: price_,
                callswitch: callswitch_,
                executed: false,
                expireTimestamp: expire
            })
        );
        emit Submit(transactions.length -1); //emit the recent transaction.
    }

    //Approve function is to vote approve to the transaction
    function approve(uint txId_) external onlyOwner txExists(txId_) notVoted(txId_) notExecuted(txId_) notExpire(txId_) {
        approved[txId_][msg.sender] = true; //Vote approve
        voted[txId_][msg.sender] = true;
        emit Approve(txId_, msg.sender);
    }

    //Reject function is to vote reject to the transaction
    function reject(uint txId_) external onlyOwner txExists(txId_) notVoted(txId_) notExecuted(txId_) notExpire(txId_) {
        approved[txId_][msg.sender] = false; //Vote reject
        voted[txId_][msg.sender] = true;
        emit Reject(txId_, msg.sender);
    }

    //This will count approve
    function getApprovalCount(uint txId_) public view returns (uint){
        uint count;
        for(uint i; i< owners.length; i++){
            if (approved[txId_][owners[i]]){
                count += 1;
            }
        }
        return count;
    }

    function execute(uint txId_) external txExists(txId_) notExecuted(txId_) notExpire(txId_) {
        require(getApprovalCount(txId_) >= required, "approvals < required"); //Whenever the signer approve reach 'required' the tx. can be executed by anyone
        Transaction storage transaction = transactions[txId_];
        transaction.executed = true; // This will also prevent reentrance


        uint8 callswitch = transaction.callswitch; //gas optimizer

        if(callswitch == 0) {
            oracle.updateAssetPrice(transaction.token, transaction.price);
            emit Execute(txId_);
            return; //Short circuit out
        }
        if(callswitch == 1) {
            oracle.updateAssetPriceFromWindow(transaction.token);
            emit Execute(txId_);
            return; //Short circuit out
        }
        if(callswitch == 2) {
            oracle.updateGoldPrice(transaction.price);
            emit Execute(txId_);
            return; //Short circuit out
        }
    }
}