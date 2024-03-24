// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenManager is Ownable {
    struct TokenInfo {
        address tokenAddress;
        string tokenSymbol;
    }

    mapping(string => TokenInfo) public supportedTokens;

    event CurrencyAdded(string currency, address tokenAddress);

    constructor()Ownable(msg.sender) {}

    function addNewToken(string memory symbol, address tokenAddress) public onlyOwner{
        supportedTokens[symbol] = TokenInfo(tokenAddress, symbol);
        emit CurrencyAdded(symbol, tokenAddress);
    }

    function removeToken(string memory symbol) public onlyOwner{
        require(
            supportedTokens[symbol].tokenAddress != address(0),
            "Token not found"
        );
        delete supportedTokens[symbol];
    }

    function showToken(string memory token)
        public
        view
        returns (
            bool success,
            string memory symbol,
            address tokenAddress
        )
    {
        if (supportedTokens[token].tokenAddress != address(0)) {
            success = true;
            symbol = supportedTokens[token].tokenSymbol;
            tokenAddress = supportedTokens[token].tokenAddress;
        } else {
            success = false;
        }
    }

    function isTokenSupported(string memory token) public view returns (bool) {
        (bool success, , ) = showToken(token);
        return success;
    }

    function showTokenAddress(string memory token)public view returns(address){
        (, ,address tokenAddress ) = showToken(token);
        return tokenAddress;
    }
}
