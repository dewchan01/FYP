// SPDX-License-Identifier: UNLICENSED

//Do not use for actual funds

pragma solidity ^0.8.9;

contract SealedBidAuction {
    // State of the auction
    address public immutable beneficiary;
    uint256 public biddingEnd;
    uint256 public revealedEnd;

    uint256 public highestBid;
    address public highestBidder;
    bool public hasEnded;

    mapping(address => uint256) pendingReturns;

    struct Bid {
        bytes32 sealedBid;
        uint256 deposit;
    }

    mapping(address => Bid[]) public bids;

    event AuctionEnded(address winner, uint256 amount);

    modifier onlyBefore(uint256 time) {
        require(block.timestamp < time, "too late");
        _;
    }

    modifier onlyAfter(uint256 time) {
        require(block.timestamp > time, "too early");
        _;
    }

    constructor(
        address _beneficiary,
        uint256 _durationBiddingMinutes,
        uint256 _durationRevealMinutes
    ) {
        beneficiary = _beneficiary;
        biddingEnd = block.timestamp + _durationBiddingMinutes * 1 minutes;
        revealedEnd = biddingEnd + _durationRevealMinutes * 1 minutes;
    }

    function bid(bytes32 _sealedBid) external payable onlyBefore(biddingEnd) {
        Bid memory newBid = Bid({sealedBid: _sealedBid, deposit: msg.value});

        bids[msg.sender].push(newBid);
    }

    function updateBid(address _bidder, uint256 _bidAmount)
        internal
        returns (bool success)
    {
        if (_bidAmount <= highestBid) {
            return false;
        }
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }
        highestBid = _bidAmount;
        highestBidder = _bidder;
        return true;
    }

    function reveal(
        uint256[] calldata _bidAmounts,
        bool[] calldata _areLegit,
        string[] calldata _secrets
    ) external onlyAfter(biddingEnd) onlyBefore(revealedEnd) {
        uint256 nBids = bids[msg.sender].length;
        require(_bidAmounts.length == nBids, "invalid number of bid amount");
        require(
            _areLegit.length == nBids,
            "invalid number of bid legitimacy indicators"
        );
        require(_secrets.length == nBids, "invalid number of bid secrets");

        uint256 totalRefund;

        for (uint256 i = 0; i < nBids; i++) {
            Bid storage bidToCheck = bids[msg.sender][i];
            (uint256 bidAmounts, bool isLegit, string memory secret) = (
                _bidAmounts[i],
                _areLegit[i],
                _secrets[i]
            );
            bytes32 hashedInput = generateSealedBid(
                bidAmounts,
                isLegit,
                secret
            );
            if (bidToCheck.sealedBid != hashedInput) {
                continue;
            }
            totalRefund += bidToCheck.deposit;
            if (isLegit && bidToCheck.deposit >= bidAmounts) {
                bool success = updateBid(msg.sender, bidAmounts);
                if (success) {
                    totalRefund -= bidAmounts;
                }
            }
            bidToCheck.sealedBid = bytes32(0);
        }

        if (totalRefund >= 0) {
            payable(msg.sender).transfer(totalRefund);
        }
    }

    function auctionEnd() external onlyAfter(revealedEnd) {
        require(!hasEnded, "Auction already ended");
        emit AuctionEnded(highestBidder, highestBid);
        hasEnded = true;
        payable(beneficiary).transfer(highestBid);
    }

    function withdraw() external returns (uint256 amount) {
        amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            payable(msg.sender).transfer(amount);
        }
    }

    function generateSealedBid(
        uint256 _bidAmount,
        bool _isLegit,
        string memory _secret
    ) public pure returns (bytes32 sealedBid) {
        sealedBid = keccak256(abi.encodePacked(_bidAmount, _isLegit, _secret));
    }
}
