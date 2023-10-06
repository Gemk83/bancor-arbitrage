// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { BancorArbitrage } from "../arbitrage/BancorArbitrage.sol";
import { Token } from "../token/Token.sol";

/**
 * @dev token contract which attempts to re-enter bancorArbitrage
 */
contract TestReentrantToken is ERC20 {
    BancorArbitrage private immutable _bancorArbitrage;

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        BancorArbitrage bancorArbitrageInit
    ) ERC20(name, symbol) {
        _bancorArbitrage = bancorArbitrageInit;
        _mint(msg.sender, totalSupply);
    }

    /// @dev Standard transfer function
    function standardTransfer(address to, uint256 amount) public returns (bool) {
        return super.transfer(to, amount);
    }

    /// @dev Override ERC-20 transfer function to reenter bancorArbitrage
    function transfer(address to, uint256 amount) public override(ERC20) returns (bool) {
        bool success = super.transfer(to, amount);

        BancorArbitrage.Flashloan[] memory flashloans = new BancorArbitrage.Flashloan[](0);
        BancorArbitrage.TradeRoute[] memory routes = new BancorArbitrage.TradeRoute[](0);
        // re-enter
        _bancorArbitrage.flashloanAndArbV2(flashloans, routes);

        return success;
    }

    /// @dev Override ERC-20 transferFrom function to reenter bancorArbitrage
    function transferFrom(address from, address to, uint256 amount) public override(ERC20) returns (bool) {
        bool success = super.transferFrom(from, to, amount);

        BancorArbitrage.TradeRoute[] memory routes = new BancorArbitrage.TradeRoute[](0);
        Token token = Token(address(0));
        // re-enter
        _bancorArbitrage.fundAndArb(routes, token, amount);

        return success;
    }
}
