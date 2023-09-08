// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import { Token } from "../../token/Token.sol";

/**
 * @notice CarbonPOL interface
 */
interface ICarbonPOL {
    /**
     * @notice trades ETH for *amount* of token based on the current token price (trade by source amount)
     */
    function trade(Token token, uint128 amount) external payable;
}
