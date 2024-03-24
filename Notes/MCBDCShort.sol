// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract MCBDC is ChainlinkClient, Ownable {
    using Chainlink for Chainlink.Request;

    struct Attribute {
        address sender;
        address recipient;
        uint256 amount;
        uint256 toAmount;
        string fromCurrency;
        string targetCurrency;
        string message;
    }
    address public TokenManager;
    string private chainlinkJobId;
    uint256 private chainlinkFee;
    bytes32 private jobId;
    uint256 private fee;
    uint256 public fxRateResponse;
    uint256 public _balanceOfLink;
    uint256 public fxRateResponseTimestamp;
    uint256 public responseExpiryTime = 180; // Set the expiration time in seconds

    mapping(address => Attribute[]) public history;
    mapping(address => Attribute[]) public requests;

    event CurrencyAdded(string currency, address tokenAddress);
    event RequestVolume(bytes32 indexed requestId, uint256 fxRateResponse);

    constructor(address tokenManager) Ownable(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0x40193c8518BB267228Fc409a613bDbD8eC5a97b3);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0.1 * 10**18 (Varies by network and job)
        TokenManager = tokenManager;
    }

    function addHistory(
        address sender,
        address recipient,
        uint256 amount,
        uint256 toAmount,
        string memory fromCurrency,
        string memory targetCurrency,
        string memory message
    ) public {
        Attribute memory newHistory;
        newHistory.sender = sender;
        newHistory.recipient = recipient;
        newHistory.amount = amount;
        newHistory.toAmount = toAmount;
        newHistory.fromCurrency = fromCurrency;
        newHistory.targetCurrency = targetCurrency;
        newHistory.message = message;
        history[sender].push(newHistory);
        history[recipient].push(newHistory);
    }

    function getMyHistory(address user)
        public
        view
        returns (Attribute[] memory)
    {
        require(user == msg.sender, "Not Authorized!");
        return history[user];
    }

    function swapToken(
        uint256 amount,
        address recipient,
        string memory fromCurrency,
        string memory toCurrency,
        string memory message
    ) public {
        // Add at least 0.1 link token to this contract
        // Request fx rate in client side
        address sender = msg.sender;
        (,bytes memory supportFromCurrency) = TokenManager.call(abi.encodeWithSignature("isTokenSupported(string)",fromCurrency));
        require( abi.decode(supportFromCurrency, (bool)), "From token not supported");

        (,bytes memory supportToCurrency)= TokenManager.call(abi.encodeWithSignature("isTokenSupported(string)",toCurrency));
        require(
           abi.decode(supportToCurrency, (bool)),
            "To token not supported"
        );

        (bool successSTFC,bytes memory fromToken) = TokenManager.call(abi.encodeWithSignature("showTokenAddress(string)",fromCurrency));
        require(
           successSTFC,
            "From token not supported"
        );
        address FromToken = abi.decode(fromToken, (address));

        (bool successSTTC,bytes memory toToken) = TokenManager.call(abi.encodeWithSignature("showTokenAddress(string)",toCurrency));
        require(
           successSTTC,
            "To token not supported"
        );
        address ToToken = abi.decode(toToken, (address));

        require(fxRateResponse > 0, "Invalid FX Rate!");
        require(isFxRateResponseValid(), "Fx Rate has expired!");

        (bool successBurn, ) = FromToken.call(
            abi.encodeWithSignature("burn(address,uint256)", sender, amount)
        );
        require(successBurn, "Burn failed");

        uint256 amountToMint = (amount * fxRateResponse) / 10**18;
        addHistory(
            sender,
            recipient,
            amount,
            amountToMint,
            fromCurrency,
            toCurrency,
            message
        );
        (bool successMint, ) = ToToken.call(
            abi.encodeWithSignature(
                "mint(address,uint256)",
                recipient,
                amountToMint
            )
        );
        require(successMint, "Mint failed");
    }

    function requestFxRate(string memory fromCurrency, string memory toCurrency)
        public
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
        recordChainlinkFulfillment(_requestId)
    {
        emit RequestVolume(_requestId, _fxRateResponse);
        fxRateResponse = _fxRateResponse;
        fxRateResponseTimestamp = block.timestamp;
    }

    function isFxRateResponseValid() public view returns (bool) {
        return (block.timestamp <=
            fxRateResponseTimestamp + responseExpiryTime);
    }

    function withdrawLink() external {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    function balanceOfLink() external {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        _balanceOfLink = link.balanceOf(address(this));
    }

    //Create a Request
    function createRequest(
        address sender,
        uint256 toAmount,
        string memory targetCurrency,
        string memory message
    ) public {
        Attribute memory newRequest;
        newRequest.sender = sender;
        newRequest.recipient = msg.sender;
        newRequest.toAmount = toAmount;
        (,bytes memory supportTargetCurrency) =  TokenManager.call(abi.encodeWithSignature("isTokenSupported(string)",targetCurrency));

        require(
            abi.decode(supportTargetCurrency, (bool)),
            "Target Currency not supported"
        );

        newRequest.amount = 0;
        newRequest.fromCurrency = "";
        newRequest.targetCurrency = targetCurrency;
        newRequest.message = message;
        requests[sender].push(newRequest);
    }

    function getMyRequests(address sender)
        public
        view
        returns (
            address[] memory _receipient,
            uint256[] memory _amount,
            uint256[] memory _toAmount,
            string[] memory _fromCurrency,
            string[] memory _targetCurrency,
            string[] memory _message
        )
    {
        require(sender == msg.sender, "Not Authorized");
        Attribute[] memory senderRequests = requests[sender];

        uint256 count = senderRequests.length;

        _receipient = new address[](count);
        _amount = new uint256[](count);
        _toAmount = new uint256[](count);
        _fromCurrency = new string[](count);
        _targetCurrency = new string[](count);
        _message = new string[](count);

        for (uint256 i = 0; i < count; i++) {
            Attribute memory request = senderRequests[i];
            _receipient[i] = request.recipient;
            _amount[i] = request.amount;
            _toAmount[i] = request.toAmount;
            _fromCurrency[i] = request.fromCurrency;
            _targetCurrency[i] = request.targetCurrency;
            _message[i] = request.message;
        }

        return (
            _receipient,
            _amount,
            _toAmount,
            _fromCurrency,
            _targetCurrency,
            _message
        );
    }

    // Pay a Request, RequestID => Request Index
    function payRequest(uint256 _requestID, string memory fromCurrency) public {
        require(_requestID < requests[msg.sender].length, "No Such Request");
        Attribute[] storage myRequests = requests[msg.sender];
        Attribute storage payableRequest = myRequests[_requestID];
        (,bytes memory supportFromCurrency)= TokenManager.call(abi.encodeWithSignature("isTokenSupported(string)",fromCurrency));
        require(
            abi.decode(supportFromCurrency, (bool)),
            "From token not supported"
        );

        payableRequest.fromCurrency = fromCurrency;

        //request rate fromCurrency -> targetCurrency
        if (!Strings.equal(fromCurrency, payableRequest.targetCurrency)) {
            require(fxRateResponse > 0, "Invalid FX Rate!");
            require(isFxRateResponseValid(), "Fx Rate has expired!");
            uint256 _amount = (payableRequest.toAmount * 10**18) /
                (fxRateResponse);
            payableRequest.amount = _amount;
            swapToken(
                payableRequest.amount,
                payableRequest.recipient,
                payableRequest.fromCurrency,
                payableRequest.targetCurrency,
                payableRequest.message
            );
        } else {
            localTransfer(
                payableRequest.recipient,
                payableRequest.toAmount,
                payableRequest.targetCurrency,
                payableRequest.message
            );
        }

        myRequests[_requestID] = myRequests[myRequests.length - 1];
        myRequests.pop();
    }

    function deleteRequest(uint256 _requestID) public {
        require(_requestID < requests[msg.sender].length, "No Such Request");
        Attribute[] storage myRequests = requests[msg.sender];
        myRequests[_requestID] = myRequests[myRequests.length - 1];
        myRequests.pop();
    }

    function localTransfer(
        address recipient,
        uint256 amount,
        string memory currency,
        string memory message
    ) public {
        (,bytes memory supportCurrency) = TokenManager.call(abi.encodeWithSignature("isTokenSupported(string)",currency));
        require(
            abi.decode(supportCurrency, (bool)),
            "Local Currency not supported"
        );
        (,bytes memory tokenAddress) = TokenManager.call(abi.encodeWithSignature("showTokenAddress(string)",currency));
        address TokenAddress = abi.decode(tokenAddress,(address));
        (bool successTransfer, ) = TokenAddress.call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                recipient,
                amount
            )
        );
        require(successTransfer, "Local Transaction Failed!");
        addHistory(
            msg.sender,
            recipient,
            amount,
            amount,
            currency,
            currency,
            message
        );
    }
}
//local transfer btn
//add delete req btn
//pay with local transfer -> rate and approve not required
