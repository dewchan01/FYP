// SPDX-License-Identifier: UNLICENSED

//Do not use for actual funds

pragma solidity ^0.8.9;
contract SealedBidAuction {
// State of the auction
address public immutable beneficiary;
uint public biddingEnd;
uint public revealedEnd;

uint public highestBid;
address public highestBidder ;
bool public hasEnded;

mapping (address => uint) pendingReturns;

constructor (address _beneficiary,uint _durationBiddingMinutes,uint _durationRevealMinutes){
    beneficiary = _beneficiary;
    biddingEnd = block.timestamp + _durationBiddingMinutes * 1 minutes;
    revealedEnd = biddingEnd + _durationRevealMinutes * 1 minutes;
}

event AuctionEnded(address winner, uint amount);

function withdraw() external returns (uint amount){
    amount = pendingReturns[msg.sender];
    if (amount>0){
        pendingReturns[msg.sender] = 0;
        payable (msg.sender).transfer(amount);
    }
}

   function generateSealedBid(uint _bidAmount, bool _isLegit, string memory _secret) public pure returns (bytes32 sealedBid){
    sealedBid = keccak256(abi.encodePacked(_bidAmount,_isLegit,_secret));
   }
}