// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import { Token } from "../token/Token.sol";
import { TokenLibrary } from "../token/TokenLibrary.sol";
import { BancorArbitrage } from "../arbitrage/BancorArbitrage.sol";
import { IFlashLoanRecipient } from "../exchanges/interfaces/IBancorNetwork.sol";

import { TradeAction } from "../exchanges/interfaces/ICarbonController.sol";

contract MockExchanges {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using TokenLibrary for Token;

    IERC20 private immutable _weth;

    address private immutable _bnt;

    // what amount is added or subtracted to/from the input amount on swap
    uint256 private _outputAmount;

    // true if the gain amount is added to the swap input, false if subtracted
    bool private _profit;

    // mapping for flashloan-whitelisted tokens
    mapping(address => bool) public isWhitelisted;

    // mapping for tokens tradeable on v3
    mapping(Token => address) public collectionByPool;

    // mapping for tokens tradeable on curve
    mapping(int128 => Token) private _curveIndexToToken;

    error InsufficientFlashLoanReturn();
    error NotWhitelisted();
    error ZeroValue();
    error GreaterThanMaxInput();

    /**
     * @dev triggered when a flash-loan is completed
     */
    event FlashLoanCompleted(Token indexed token, address indexed borrower, uint256 amount, uint256 feeAmount);

    constructor(IERC20 weth, address bnt, uint256 initOutputAmount, bool initProfit) {
        _weth = weth;
        _bnt = bnt;
        _outputAmount = initOutputAmount;
        _profit = initProfit;
    }

    receive() external payable {}

    //solhint-disable-next-line func-name-mixedcase
    function WETH() external view returns (IERC20) {
        return _weth;
    }

    function outputAmount() external view returns (uint256) {
        return _outputAmount;
    }

    function profit() external view returns (bool) {
        return _profit;
    }

    /**
     * @dev v3 network flashloan mock
     */
    function flashLoan(Token token, uint256 amount, IFlashLoanRecipient recipient, bytes calldata data) external {
        // check if token is whitelisted
        if (!isWhitelisted[address(token)]) {
            revert NotWhitelisted();
        }
        uint256 feeAmount = 0;
        uint256 prevBalance = token.balanceOf(address(this));
        uint256 prevWethBalance = _weth.balanceOf(address(this));

        // transfer funds to flashloan recipient
        token.safeTransfer(payable(address(recipient)), amount);

        // trigger flashloan callback
        recipient.onFlashLoan(msg.sender, token.toIERC20(), amount, feeAmount, data);

        // account for net gain in the token which is sent from this contract
        // decode data to count the swaps
        (, BancorArbitrage.TradeRoute[] memory routes) = abi.decode(
            data,
            (BancorArbitrage.Flashloan[], BancorArbitrage.TradeRoute[])
        );
        uint256 swapCount = address(token) == _bnt ? routes.length : routes.length + 1;
        uint256 gain = swapCount * _outputAmount;
        uint256 expectedBalance;
        if (_profit) {
            expectedBalance = prevBalance - gain;
        } else {
            expectedBalance = prevBalance + gain;
        }
        // account for weth gains if token is native (uni v3 swaps convert eth to weth)
        if (token.isNative()) {
            uint256 wethBalance = _weth.balanceOf(address(this));
            uint256 wethGain = wethBalance - prevWethBalance;
            expectedBalance -= wethGain;
        }

        if (token.balanceOf(address(this)) < expectedBalance) {
            revert InsufficientFlashLoanReturn();
        }
        emit FlashLoanCompleted({ token: token, borrower: msg.sender, amount: amount, feeAmount: feeAmount });
    }

    /**
     * @dev set profit and output amount
     */
    function setProfitAndOutputAmount(bool newProfit, uint256 newOutputAmount) external {
        _profit = newProfit;
        _outputAmount = newOutputAmount;
    }

    /**
     * @dev add token to whitelist for flashloans
     */
    function addToWhitelist(address token) external {
        isWhitelisted[token] = true;
    }

    /**
     * @dev remove token from whitelist for flashloans
     */
    function removeFromWhitelist(address token) external {
        isWhitelisted[token] = false;
    }

    /**
     * @dev set collection by pool
     */
    function setCollectionByPool(Token token) external {
        collectionByPool[token] = address(token);
    }

    /**
     * @dev reset collection by pool
     */
    function resetCollectionByPool(Token token) external {
        collectionByPool[token] = address(0);
    }

    /**
     * Bancor v2 trade
     */
    function convertByPath(
        address[] memory _path,
        uint256 _amount,
        uint256 _minReturn,
        address /* _beneficiary */,
        address /* _affiliateAccount */,
        uint256 /* _affiliateFee */
    ) external payable returns (uint256) {
        Token sourceToken = Token(_path[0]);
        Token targetToken = Token(_path[_path.length - 1]);
        return mockSwap(sourceToken, targetToken, _amount, msg.sender, block.timestamp, _minReturn);
    }

    /**
     * Bancor v3 trade
     */
    function tradeBySourceAmountArb(
        Token sourceToken,
        Token targetToken,
        uint256 sourceAmount,
        uint256 minReturnAmount,
        uint256 deadline,
        address /* beneficiary */
    ) external payable returns (uint256) {
        if (minReturnAmount == 0) {
            revert ZeroValue();
        }
        return mockSwap(sourceToken, targetToken, sourceAmount, msg.sender, deadline, minReturnAmount);
    }

    /**
     * Carbon controller trade by source amount
     */
    function tradeBySourceAmount(
        Token sourceToken,
        Token targetToken,
        TradeAction[] calldata tradeActions,
        uint256 deadline,
        uint128 minReturn
    ) external payable returns (uint128) {
        // calculate total source amount from individual trade actions
        uint256 sourceAmount = 0;
        for (uint256 i = 0; i < tradeActions.length; ++i) {
            sourceAmount += uint128(tradeActions[i].amount);
        }
        return uint128(mockSwap(sourceToken, targetToken, sourceAmount, msg.sender, deadline, minReturn));
    }

    /**
     * Carbon controller trade by target amount
     */
    function tradeByTargetAmount(
        Token sourceToken,
        Token targetToken,
        TradeAction[] calldata tradeActions,
        uint256 deadline,
        uint128 maxInput
    ) external payable returns (uint128) {
        // calculate total source amount
        uint256 sourceAmount = calculateTradeSourceAmount(sourceToken, targetToken, tradeActions);
        // check if exceeding maxInput
        if (sourceAmount > maxInput) {
            revert GreaterThanMaxInput();
        }
        return uint128(mockSwap(sourceToken, targetToken, sourceAmount, msg.sender, deadline, 1));
    }

    /**
     * @dev CarbonController view function
     * @dev returns the source amount required when trading by target amount
     */
    function calculateTradeSourceAmount(
        Token /* sourceToken */,
        Token /* targetToken */,
        TradeAction[] calldata tradeActions
    ) public view returns (uint128) {
        uint256 targetAmount = 0;
        for (uint256 i = 0; i < tradeActions.length; ++i) {
            targetAmount += uint128(tradeActions[i].amount);
        }
        uint128 sourceAmount = 0;
        if (_profit) {
            sourceAmount = (targetAmount - _outputAmount).toUint128();
        } else {
            sourceAmount = (targetAmount + _outputAmount).toUint128();
        }
        return sourceAmount;
    }

    /**
     * Carbon POL trade return
     */
    function expectedTradeReturn(Token /* token */, uint128 sourceAmount) external view returns (uint128 targetAmount) {
        if (_profit) {
            targetAmount = (sourceAmount + _outputAmount).toUint128();
        } else {
            targetAmount = (sourceAmount - _outputAmount).toUint128();
        }
    }

    /**
     * Carbon POL trade input
     */
    function expectedTradeInput(Token /* token */, uint128 targetAmount) public view returns (uint128 sourceAmount) {
        if (_profit) {
            sourceAmount = (targetAmount - _outputAmount).toUint128();
        } else {
            sourceAmount = (targetAmount + _outputAmount).toUint128();
        }
    }

    /**
     * Carbon POL trade
     */
    function trade(Token token, uint128 amount) external payable returns (uint128) {
        // when trading for the native token, source token is always BNT for CarbonPOL (as of the latest update)
        Token sourceToken = token.isNative() ? Token(_bnt) : TokenLibrary.NATIVE_TOKEN;
        // get source amount
        uint128 sourceAmount = expectedTradeInput(token, amount);
        // trade
        return mockSwap(sourceToken, token, sourceAmount, msg.sender, block.timestamp, 0).toUint128();
    }

    function setCurveToken(int128 index, Token token) external {
        _curveIndexToToken[index] = token;
    }

    /**
     * ICurvePool function which performs an exchange between two coins
     */
    //solhint-disable-next-line var-name-mixedcase
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns (uint256) {
        return mockSwap(_curveIndexToToken[i], _curveIndexToToken[j], dx, msg.sender, block.timestamp, min_dy);
    }

    /**
     * Uniswap v2 like trades
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address /* to */,
        uint256 deadline
    ) external returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = mockSwap(Token(path[0]), Token(path[1]), amountIn, msg.sender, deadline, amountOutMin);
        return amounts;
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address /* to */,
        uint256 deadline
    ) external payable returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = msg.value;
        amounts[1] = mockSwap(TokenLibrary.NATIVE_TOKEN, Token(path[1]), msg.value, msg.sender, deadline, amountOutMin);
        return amounts;
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address /* to */,
        uint256 deadline
    ) external returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = mockSwap(Token(path[0]), TokenLibrary.NATIVE_TOKEN, amountIn, msg.sender, deadline, amountOutMin);
        return amounts;
    }

    /**
     * Uniswap v3 like trades
     */
    function exactInputSingle(ISwapRouter.ExactInputSingleParams memory params) external returns (uint256 amountOut) {
        return
            mockSwap(
                Token(params.tokenIn),
                Token(params.tokenOut),
                params.amountIn,
                msg.sender,
                params.deadline,
                params.amountOutMinimum
            );
    }

    function mockSwap(
        Token sourceToken,
        Token targetToken,
        uint256 amount,
        address trader,
        uint256 deadline,
        uint256 minTargetAmount
    ) private returns (uint256) {
        /* solhint-disable custom-errors */
        require(deadline >= block.timestamp, "Swap timeout");
        require(sourceToken != targetToken, "Invalid swap");
        require(amount > 0, "Source amount should be > 0");
        // withdraw source amount
        sourceToken.safeTransferFrom(trader, address(this), amount);

        // transfer target amount
        // receive outputAmount tokens per swap
        uint256 targetAmount;
        if (_profit) {
            targetAmount = amount + _outputAmount;
        } else {
            targetAmount = amount - _outputAmount;
        }
        require(targetAmount >= minTargetAmount, "InsufficientTargetAmount");
        /* solhint-enable custom-errors */
        targetToken.safeTransfer(trader, targetAmount);
        return targetAmount;
    }
}
