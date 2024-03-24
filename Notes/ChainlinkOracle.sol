// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ChainlinkOracle is ChainlinkClient {
    using Chainlink for Chainlink.Request;

    uint256 public _balanceOfLink;
    bytes32 public jobId;
    uint256 public fee;
    uint256 public fxRateResponse;
    uint256 public fxRateResponseTimestamp;
    uint256 public responseExpiryTime = 180; // Set the expiration time in seconds

    event RequestVolume(bytes32 indexed requestId, uint256 fxRateResponse);

    constructor() {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0x40193c8518BB267228Fc409a613bDbD8eC5a97b3);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0.1 * 10**18 (Varies by network and job)
    }

    function requestFxRate(string memory fromCurrency, string memory toCurrency)
        public
        virtual
        returns (bytes32 requestId)
    {
        // Set the timeout duration in seconds (30 seconds in this example)
        // uint256 timeout = 30;
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );
        req.add(
            "get",
            string(
                abi.encodePacked(
                    "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=",
                    fromCurrency,
                    "&tsyms=",
                    toCurrency
                )
            )
        );
        req.add(
            "path",
            string(
                abi.encodePacked(
                    "RAW,",
                    fromCurrency,
                    ",",
                    toCurrency,
                    ",PRICE"
                )
            )
        );

        int256 timesAmount = 10**18;
        req.addInt("times", timesAmount);
        // req.addUint("until", block.timestamp + timeout);
        fxRateResponseTimestamp = block.timestamp;
        return sendChainlinkRequest(req, fee);
    }

    function fulfill(bytes32 _requestId, uint256 _fxRateResponse)
        public
        virtual
        recordChainlinkFulfillment(_requestId)
    {
        emit RequestVolume(_requestId, _fxRateResponse);
        fxRateResponse = _fxRateResponse;
        fxRateResponseTimestamp = block.timestamp;
    }

    function isFxRateResponseValid() public view virtual returns (bool) {
        return (block.timestamp <=
            fxRateResponseTimestamp + responseExpiryTime);
    }

    function withdrawLink() public virtual{
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    function balanceOfLink() public virtual {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        _balanceOfLink = link.balanceOf(address(this));
    }
}
