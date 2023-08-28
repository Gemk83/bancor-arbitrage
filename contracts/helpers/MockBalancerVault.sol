// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import { Token } from "../token/Token.sol";
import { TokenLibrary } from "../token/TokenLibrary.sol";
import { BancorArbitrage } from "../arbitrage/BancorArbitrage.sol";
import { IFlashLoanRecipient } from "../exchanges/interfaces/IBalancerVault.sol";
import { IBalancerVault, IAsset as IBalancerAsset } from "../exchanges/interfaces/IBalancerVault.sol";

import { TradeAction } from "../exchanges/interfaces/ICarbonController.sol";

contract MockBalancerVault is IBalancerVault {
    using SafeERC20 for IERC20;
    using TokenLibrary for Token;

    error InsufficientFlashLoanReturn();
    error NotEnoughBalanceForFlashloan();
    error InputLengthMismatch();

    // what amount is added or subtracted to/from the input amount on swap
    uint private _outputAmount;

    // true if the gain amount is added to the swap input, false if subtracted
    bool private _profit;

    /**
     * @dev Emitted for each individual flash loan performed by `flashLoan`.
     */
    event FlashLoan(IFlashLoanRecipient indexed recipient, IERC20 indexed token, uint256 amount, uint256 feeAmount);

    constructor(uint initOutputAmount, bool initProfit) {
        _outputAmount = initOutputAmount;
        _profit = initProfit;
    }

    receive() external payable {}

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory, // funds,
        uint256 limit,
        uint256 deadline
    )
        external
        payable
        override
        returns (uint256)
    {
        Token sourceToken = address(singleSwap.assetIn ) != address(0) ? Token(address(singleSwap.assetIn )) : TokenLibrary.NATIVE_TOKEN;
        Token targetToken = address(singleSwap.assetOut) != address(0) ? Token(address(singleSwap.assetOut)) : TokenLibrary.NATIVE_TOKEN;
        uint256 amount = singleSwap.amount;
        address trader = msg.sender;
        uint minTargetAmount = limit;

        require(deadline >= block.timestamp, "Swap timeout");
        require(sourceToken != targetToken, "Invalid swap");
        require(amount > 0, "Source amount should be > 0");
        // withdraw source amount
        sourceToken.safeTransferFrom(trader, address(this), amount);

        // transfer target amount
        // receive outputAmount tokens per swap
        uint targetAmount;
        if (_profit) {
            targetAmount = amount + _outputAmount;
        } else {
            targetAmount = amount - _outputAmount;
        }
        require(targetAmount >= minTargetAmount, "InsufficientTargetAmount");
        targetToken.safeTransfer(trader, targetAmount);
        return targetAmount;
    }

    /**
     * @dev Handles Flash Loans through the Vault. Calls the `receiveFlashLoan` hook on the flash loan recipient
     * contract, which implements the `IFlashLoanRecipient` interface.
     */
    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external {
        if (tokens.length != amounts.length) {
            revert InputLengthMismatch();
        }
        uint256[] memory feeAmounts = new uint256[](tokens.length);
        uint256[] memory prevBalances = new uint256[](tokens.length);
        // store current balances and fee amounts
        for (uint256 i = 0; i < tokens.length; ++i) {
            prevBalances[i] = Token(address(tokens[i])).balanceOf(address(this));
            feeAmounts[i] = 0;
        }

        // transfer funds to flashloan recipient
        for (uint256 i = 0; i < tokens.length; ++i) {
            if (amounts[i] > prevBalances[i]) {
                revert NotEnoughBalanceForFlashloan();
            }
            Token(address(tokens[i])).safeTransfer(payable(address(recipient)), amounts[i]);
        }

        // trigger flashloan callback
        recipient.receiveFlashLoan(tokens, amounts, feeAmounts, userData);

        // check each of the tokens has been returned with the fee amount
        for (uint256 i = 0; i < tokens.length; ++i) {
            IERC20 token = tokens[i];

            if (Token(address(token)).balanceOf(address(this)) < prevBalances[i] + feeAmounts[i]) {
                revert InsufficientFlashLoanReturn();
            }
            emit FlashLoan(recipient, token, amounts[i], feeAmounts[i]);
        }
    }
}
