// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { BancorArbitrage } from "../arbitrage/BancorArbitrage.sol";
import { Token } from "../token/Token.sol";
import { TokenLibrary } from "../token/TokenLibrary.sol";

/**
 * @dev test re-entrancy protection for BancorArbitrage
 */
contract TestReentrancy {
    using TokenLibrary for Token;

    BancorArbitrage private immutable _bancorArbitrage;

    constructor(BancorArbitrage bancorArbitrageInit) {
        _bancorArbitrage = bancorArbitrageInit;
    }

    receive() external payable {
        BancorArbitrage.TradeRoute[] memory routes = new BancorArbitrage.TradeRoute[](0);
        Token token = Token(address(0));
        uint256 amount = 1;

        // re-enter fundAndArb, reverting the tx
        _bancorArbitrage.fundAndArb{ value: amount }(routes, token, amount);
    }

    /// @dev try to reenter flashloan and arb v2
    function tryReenterFlashloanAndArbV2(
        BancorArbitrage.Flashloan[] calldata flashloans,
        BancorArbitrage.TradeRoute[] calldata routes
    ) external {
        _bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /// @dev try to reenter fund and arb
    function tryReenterFundAndArb(
        BancorArbitrage.TradeRoute[] calldata routes,
        Token token,
        uint256 amount
    ) external payable {
        _bancorArbitrage.fundAndArb{ value: msg.value }(routes, token, amount);
    }

    /// @dev approve tokens to bancor arbitrage
    function approveTokens(Token token, uint256 amount) external {
        token.safeApprove(address(_bancorArbitrage), amount);
    }
}
