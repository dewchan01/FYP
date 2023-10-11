// SPDX-License-Identifier: UNLICENSED

//Do not use for actual funds

pragma solidity ^0.8.9;
contract SimpleAuction {
// State of the auction
address public immutable beneficiary;
uint public endTime;
uint public highestBid = 100;
address public highestBidder ;
bool public hasEnded;

mapping (address => uint) pendingReturns;

constructor (address _beneficiary,uint _durationMinutes){
    beneficiary = _beneficiary;
    endTime = block.timestamp + _durationMinutes * 1 minutes;
}

event NewBid(address indexed bidder, uint amount);
event AuctionEnded(address winner, uint amount);

function bid()public payable {
    require(block.timestamp < endTime,'Auction ended!');
    require(msg.value > highestBid , 'Bid too small!');
    if (highestBid !=0){
        pendingReturns[highestBidder] += highestBid;
    }
    highestBid = msg.value;
    highestBidder = msg.sender;
    emit NewBid(msg.sender, msg.value);

}

function withdraw() external returns (uint amount){
    amount = pendingReturns[msg.sender];
    if (amount>0){
        pendingReturns[msg.sender] = 0;
        payable (msg.sender).transfer(amount);
    }
}

    function auctionEnd() external{
        require (!hasEnded, "Auction Ended");
        require(block.timestamp>=endTime,"Wait for auction to end");
        hasEnded = true;
        emit AuctionEnded(highestBidder, highestBid);
        payable(beneficiary).transfer(highestBid);

    }
}