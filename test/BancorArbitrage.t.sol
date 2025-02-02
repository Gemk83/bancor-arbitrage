// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import { Token } from "../contracts/token/Token.sol";
import { TokenLibrary } from "../contracts/token/TokenLibrary.sol";
import { ZeroValue, InvalidAddress } from "../contracts/utility/Utils.sol";
import { TransparentUpgradeableProxyImmutable } from "../contracts/utility/TransparentUpgradeableProxyImmutable.sol";
import { Utilities } from "./Utilities.t.sol";
import { BancorArbitrage } from "../contracts/arbitrage/BancorArbitrage.sol";
import { Upgradeable } from "../contracts/utility/Upgradeable.sol";
import { MockExchanges } from "../contracts/helpers/MockExchanges.sol";
import { MockBalancerVault } from "../contracts/helpers/MockBalancerVault.sol";
import { TestBNT } from "../contracts/helpers/TestBNT.sol";
import { TestWETH } from "../contracts/helpers/TestWETH.sol";
import { TestReentrancy } from "../contracts/helpers/TestReentrancy.sol";
import { TestReentrantToken } from "../contracts/helpers/TestReentrantToken.sol";
import { IBancorNetworkV2 } from "../contracts/exchanges/interfaces/IBancorNetworkV2.sol";
import { IBancorNetwork, IFlashLoanRecipient } from "../contracts/exchanges/interfaces/IBancorNetwork.sol";
import { ICarbonController, TradeAction } from "../contracts/exchanges/interfaces/ICarbonController.sol";
import { IVault as IBalancerVault } from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import { ICarbonPOL } from "../contracts/exchanges/interfaces/ICarbonPOL.sol";
import { PPM_RESOLUTION } from "../contracts/utility/Constants.sol";
import { TestERC20Token } from "../contracts/helpers/TestERC20Token.sol";

/* solhint-disable max-states-count */
contract BancorArbitrageV2ArbsTest is Test {
    using TokenLibrary for Token;

    Utilities private utils;
    BancorArbitrage private bancorArbitrage;
    TestBNT private bnt;
    TestWETH private weth;
    TestERC20Token private arbToken1;
    TestERC20Token private arbToken2;
    TestERC20Token private nonWhitelistedToken;
    MockExchanges private exchanges;
    MockBalancerVault private balancerVault;
    ProxyAdmin private proxyAdmin;

    BancorArbitrage.Platforms private platformStruct;

    address[] private whitelistedTokens;

    address payable[] private users;
    address payable private admin;
    address payable private user1;
    address payable private protocolWallet;

    uint256 private constant BNT_VIRTUAL_BALANCE = 1;
    uint256 private constant BASE_TOKEN_VIRTUAL_BALANCE = 2;
    uint256 private constant MAX_SOURCE_AMOUNT = 100_000_000 ether;
    uint256 private constant DEADLINE = type(uint256).max;
    uint256 private constant AMOUNT = 1000 ether;
    uint256 private constant MIN_LIQUIDITY_FOR_TRADING = 1000 ether;
    uint256 private constant FIRST_EXCHANGE_ID = 1;
    uint256 private constant LAST_EXCHANGE_ID = 9;

    enum PlatformId {
        INVALID,
        BANCOR_V2,
        BANCOR_V3,
        UNISWAP_V2_FORK,
        UNISWAP_V3_FORK,
        SUSHISWAP,
        CARBON_FORK,
        BALANCER,
        CARBON_POL,
        CURVE,
        WETH
    }

    BancorArbitrage.Rewards private arbitrageRewardsDefaults =
        BancorArbitrage.Rewards({ percentagePPM: 30000, maxAmount: 100 ether });

    BancorArbitrage.Rewards private arbitrageRewardsUpdated =
        BancorArbitrage.Rewards({ percentagePPM: 40000, maxAmount: 200 ether });

    // Events

    /**
     * @dev triggered after a successful arb is executed
     */
    event ArbitrageExecuted(
        address indexed caller,
        uint16[] platformIds,
        address[] tokenPath,
        address[] sourceTokens,
        uint256[] sourceAmounts,
        uint256[] protocolAmounts,
        uint256[] rewardAmounts
    );

    /**
     * @dev triggered when the rewards settings are updated
     */
    event RewardsUpdated(
        uint32 prevPercentagePPM,
        uint32 newPercentagePPM,
        uint256 prevMaxAmount,
        uint256 newMaxAmount
    );

    /**
     * @dev triggered when a flash-loan is completed from Bancor V3
     */
    event FlashLoanCompleted(Token indexed token, address indexed borrower, uint256 amount, uint256 feeAmount);

    /**
     * @dev Emitted for each individual flash loan performed by `flashLoan` from Balancer
     */
    event FlashLoan(IFlashLoanRecipient indexed recipient, IERC20 indexed token, uint256 amount, uint256 feeAmount);

    /**
     * @dev emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev WETH deposit event
     */
    event Deposit(address indexed dst, uint256 wad);

    /**
     * @dev WETH withdrawal event
     */
    event Withdrawal(address indexed src, uint256 wad);

    /// @dev function to set up state before tests
    function setUp() public virtual {
        utils = new Utilities();
        // create 4 users
        users = utils.createUsers();
        admin = users[0];
        user1 = users[1];
        protocolWallet = users[3];

        // deploy contracts from admin
        vm.startPrank(admin);

        // deploy proxy admin
        proxyAdmin = new ProxyAdmin();
        // deploy BNT
        bnt = new TestBNT("Bancor Network Token", "BNT", 1_000_000_000 ether);
        // deploy WETH
        weth = new TestWETH();
        // deploy MockExchanges
        exchanges = new MockExchanges(IERC20(weth), address(bnt), 300 ether, true);
        // deploy MockBalancerVault
        balancerVault = new MockBalancerVault(300 ether, true);
        // init exchanges struct
        platformStruct = getPlatformStruct(address(exchanges), address(balancerVault));
        // Deploy arbitrage contract
        bancorArbitrage = new BancorArbitrage(bnt, weth, protocolWallet, platformStruct);

        bytes memory selector = abi.encodeWithSelector(bancorArbitrage.initialize.selector);

        // deploy arb proxy
        address arbProxy = address(
            new TransparentUpgradeableProxyImmutable(address(bancorArbitrage), payable(address(proxyAdmin)), selector)
        );
        bancorArbitrage = BancorArbitrage(payable(arbProxy));

        // deploy test tokens
        arbToken1 = new TestERC20Token("TKN1", "TKN1", 1_000_000_000 ether);
        arbToken2 = new TestERC20Token("TKN2", "TKN2", 1_000_000_000 ether);
        nonWhitelistedToken = new TestERC20Token("TKN", "TKN", 1_000_000_000 ether);

        // send some tokens to exchange
        nonWhitelistedToken.transfer(address(exchanges), MAX_SOURCE_AMOUNT);
        arbToken1.transfer(address(exchanges), MAX_SOURCE_AMOUNT);
        arbToken2.transfer(address(exchanges), MAX_SOURCE_AMOUNT);
        bnt.transfer(address(exchanges), MAX_SOURCE_AMOUNT * 5);
        // send some tokens to balancer vault
        nonWhitelistedToken.transfer(address(balancerVault), MAX_SOURCE_AMOUNT);
        arbToken1.transfer(address(balancerVault), MAX_SOURCE_AMOUNT);
        arbToken2.transfer(address(balancerVault), MAX_SOURCE_AMOUNT);
        bnt.transfer(address(balancerVault), MAX_SOURCE_AMOUNT * 5);
        // send eth to exchange
        vm.deal(address(exchanges), MAX_SOURCE_AMOUNT);
        // send eth to balancer vault
        vm.deal(address(balancerVault), MAX_SOURCE_AMOUNT);
        // send weth to exchange
        vm.deal(admin, MAX_SOURCE_AMOUNT * 3);
        weth.deposit{ value: MAX_SOURCE_AMOUNT * 3 }();
        weth.transfer(address(exchanges), MAX_SOURCE_AMOUNT);
        // send weth to balancer vault
        weth.transfer(address(balancerVault), MAX_SOURCE_AMOUNT);
        // send tokens to user
        nonWhitelistedToken.transfer(user1, MAX_SOURCE_AMOUNT * 2);
        arbToken1.transfer(user1, MAX_SOURCE_AMOUNT * 2);
        arbToken2.transfer(user1, MAX_SOURCE_AMOUNT * 2);
        bnt.transfer(user1, MAX_SOURCE_AMOUNT * 5);

        // whitelist tokens in exchanges mock
        exchanges.addToWhitelist(address(bnt));
        exchanges.addToWhitelist(address(arbToken1));
        exchanges.addToWhitelist(address(arbToken2));
        exchanges.addToWhitelist(address(TokenLibrary.NATIVE_TOKEN));
        // set pool collections for v3
        exchanges.setCollectionByPool(Token(address(bnt)));
        exchanges.setCollectionByPool(Token(address(arbToken1)));
        exchanges.setCollectionByPool(Token(address(arbToken2)));
        exchanges.setCollectionByPool(TokenLibrary.NATIVE_TOKEN);

        vm.stopPrank();
    }

    /**
     * @dev test should revert when deploying BancorArbitrage with an invalid weth address
     */
    function testShouldRevertWhenInitializingWithInvalidWethAddress() public {
        vm.expectRevert(InvalidAddress.selector);
        new BancorArbitrage(bnt, weth, address(0), platformStruct);
    }

    /**
     * @dev test should revert when deploying BancorArbitrage with an invalid protocol wallet
     */
    function testShouldRevertWhenInitializingWithInvalidProtocolWallet() public {
        vm.expectRevert(InvalidAddress.selector);
        new BancorArbitrage(bnt, weth, address(0), platformStruct);
    }

    /**
     * @dev test should revert when attempting to reinitialize implementation
     */
    function testShouldRevertWhenAttemptingToReinitializeImplementation() public {
        BancorArbitrage __bancorArbitrage = new BancorArbitrage(bnt, weth, protocolWallet, platformStruct);
        vm.expectRevert("Initializable: contract is already initialized");
        __bancorArbitrage.initialize();
    }

    /**
     * @dev test should revert when attempting to call postUpgrade on a newly deployed contract
     */
    function testShouldRevertWhenAttemptingToCallPostUpgrade() public {
        // init platforms struct
        platformStruct = getPlatformStruct(address(exchanges), address(balancerVault));
        // Deploy arbitrage contract
        BancorArbitrage __bancorArbitrage = new BancorArbitrage(bnt, weth, protocolWallet, platformStruct);

        // call postUpgrade on the implementation
        vm.expectRevert(Upgradeable.AlreadyInitialized.selector);
        __bancorArbitrage.postUpgrade("");

        bytes memory selector = abi.encodeWithSelector(bancorArbitrage.initialize.selector);

        // deploy arb proxy
        address arbProxy = address(
            new TransparentUpgradeableProxyImmutable(address(__bancorArbitrage), payable(address(proxyAdmin)), selector)
        );
        __bancorArbitrage = BancorArbitrage(payable(arbProxy));

        // call postUpgrade on the proxy
        vm.expectRevert(Upgradeable.AlreadyInitialized.selector);
        __bancorArbitrage.postUpgrade("");
    }

    /**
     * @dev test that bancorArbitrage should be initialized
     */
    function testShouldBeInitialized() public {
        uint256 version = bancorArbitrage.version();
        assertEq(version, 11);
    }

    /// --- Reward distribution and protocol transfer tests --- ///

    /**
     * @dev test reward distribution and token transfer on arbitrage execution
     * @dev test with different flashloan tokens
     */
    function testShouldCorrectlyDistributeRewardsAndProtocolAmounts(bool userFunded) public {
        BancorArbitrage.TradeRoute[] memory routes;
        address[4] memory tokens = [
            address(arbToken1),
            address(arbToken2),
            address(TokenLibrary.NATIVE_TOKEN),
            address(bnt)
        ];
        // try different flashloan tokens
        for (uint256 i = 0; i < 4; ++i) {
            // get flashloan data
            BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(IERC20(tokens[i]), AMOUNT);
            // first and second target tokens must be different from each other and the flashloan token
            routes = getRoutesCustomTokens(
                uint16(PlatformId.BANCOR_V2),
                tokens[(i + 1) % 4],
                tokens[(i + 2) % 4],
                tokens[i],
                AMOUNT,
                500
            );

            vm.prank(admin);
            bancorArbitrage.setRewards(arbitrageRewardsUpdated);
            (
                uint256[] memory expectedUserRewards,
                uint256[] memory expectedProtocolAmounts
            ) = calculateExpectedUserRewardsAndProtocolAmounts();

            (uint16[] memory exchangeIds, address[] memory tokenPath) = buildArbPath(routes);

            address[] memory sourceTokens = new address[](1);
            uint256[] memory sourceAmounts = new uint256[](1);
            sourceTokens[0] = tokens[i];
            sourceAmounts[0] = AMOUNT;

            vm.startPrank(user1);
            // approve token if user-funded arb
            if (userFunded) {
                Token(tokens[i]).safeApprove(address(bancorArbitrage), AMOUNT);
            }

            vm.expectEmit(true, true, true, true);
            emit ArbitrageExecuted(
                user1,
                exchangeIds,
                tokenPath,
                sourceTokens,
                sourceAmounts,
                expectedProtocolAmounts,
                expectedUserRewards
            );
            vm.stopPrank();
            executeArbitrageNoApproval(flashloans, routes, userFunded);
        }
    }

    /**
     * @dev test reward distribution and token transfer on arbitrage execution
     * @dev test that both the protocol wallet and the arb caller receive the expected tokens
     * @dev test with multiple flashloan tokens
     */
    function testShouldCorrectlyTransferRewardAndProtocolAmounts(uint16 platformId, uint256 arbAmount) public {
        // limit arbAmount to AMOUNT
        vm.assume(arbAmount > 0 && arbAmount < AMOUNT);
        // test exchange ids 1 - 5 (w/o Carbon)
        platformId = uint16(bound(platformId, FIRST_EXCHANGE_ID, 5));
        address[] memory tokensToTrade = new address[](3);
        tokensToTrade[0] = address(arbToken1);
        tokensToTrade[1] = address(arbToken2);
        tokensToTrade[2] = address(TokenLibrary.NATIVE_TOKEN);

        // test with all token combinations
        for (uint256 i = 0; i < 3; ++i) {
            for (uint256 j = 0; j < 3; ++j) {
                for (uint256 k = 0; k < 3; ++k) {
                    if (i == j || i == k || j == k) {
                        continue;
                    }
                    // initialize intermediary tokens for routes
                    address[] memory tokens = new address[](6);
                    tokens[0] = tokensToTrade[j];
                    tokens[1] = tokensToTrade[k];
                    tokens[2] = tokensToTrade[i];
                    tokens[3] = tokensToTrade[k];
                    tokens[4] = tokensToTrade[i];
                    tokens[5] = tokensToTrade[j];
                    // get flashloan data for 3 token flashloans
                    BancorArbitrage.Flashloan[] memory flashloans = getCombinedFlashloanDataForSeveralTokens(
                        tokensToTrade[i],
                        AMOUNT,
                        tokensToTrade[j],
                        AMOUNT,
                        tokensToTrade[k],
                        AMOUNT
                    );
                    // get custom routes for all tokens with 3 flashloans
                    BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokensMultipleFlashloans(
                        platformId,
                        tokensToTrade[i],
                        tokensToTrade[j],
                        tokensToTrade[k],
                        tokens,
                        arbAmount,
                        500
                    );
                    if (!isValidTestConfiguration(platformId, routes)) {
                        continue;
                    }

                    // get expected user rewards and protocol amounts
                    (
                        uint256[] memory expectedUserRewards,
                        uint256[] memory expectedProtocolAmounts
                    ) = calculateExpectedUserRewardsAndProtocolAmountsMultipleFlashloans(3);

                    // calculate balances before
                    uint256[] memory protocolWalletBalancesBefore = new uint256[](3);
                    uint256[] memory callerBalancesBefore = new uint256[](3);
                    for (uint256 t = 0; t < 3; ++t) {
                        protocolWalletBalancesBefore[t] = Token(tokens[t]).balanceOf(protocolWallet);
                        callerBalancesBefore[t] = Token(tokens[t]).balanceOf(user1);
                    }

                    // execute arb
                    executeArbitrage(flashloans, routes, false);

                    // calculate token gains for the wallets and check if they match the expected amounts
                    for (uint256 t = 0; t < 3; ++t) {
                        uint256 protocolWalletBalanceAfter = Token(tokens[t]).balanceOf(protocolWallet);
                        uint256 callerBalanceAfter = Token(tokens[t]).balanceOf(user1);
                        uint256 protocolWalletGain = protocolWalletBalanceAfter - protocolWalletBalancesBefore[t];
                        uint256 callerGain = callerBalanceAfter - callerBalancesBefore[t];
                        // assert gain is equal to the expected amounts
                        assertEq(protocolWalletGain, expectedProtocolAmounts[t]);
                        assertEq(callerGain, expectedUserRewards[t]);
                    }
                }
            }
        }
    }

    /// --- Flashloan tests --- ///

    /**
     * @dev test correct obtaining and repayment of flashloan
     */
    function testShouldCorrectlyObtainAndRepayFlashloanFromBancorV3() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectEmit(true, true, true, true);
        emit FlashLoanCompleted(Token(address(bnt)), address(bancorArbitrage), AMOUNT, 0);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test correct obtaining and repayment of flashloan
     */
    function testShouldCorrectlyObtainAndRepayMultipleFlashloansFromBancorV3() public {
        IERC20[] memory tokens = new IERC20[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = bnt;
        amounts[0] = AMOUNT;
        tokens[1] = arbToken1;
        amounts[1] = AMOUNT;
        BancorArbitrage.Flashloan[] memory flashloans = getFlashloanDataForV3(tokens, amounts);
        // get routes
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomLength(
            3,
            uint16(PlatformId.UNISWAP_V3_FORK),
            0,
            AMOUNT
        );
        // expect two flashloan events are emitted from the flashloan source (bancor v3)
        vm.expectEmit(true, true, true, true);
        emit FlashLoanCompleted(Token(address(arbToken1)), address(bancorArbitrage), AMOUNT, 0);
        vm.expectEmit(true, true, true, true);
        emit FlashLoanCompleted(Token(address(bnt)), address(bancorArbitrage), AMOUNT, 0);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test correct obtaining and repayment of flashloan from balancer
     */
    function testShouldCorrectlyObtainAndRepayFlashloanFromBalancer() public {
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = bnt;
        amounts[0] = AMOUNT;
        BancorArbitrage.Flashloan[] memory flashloans = getFlashloanDataForBalancer(tokens, amounts);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectEmit(true, true, true, true);
        emit FlashLoan(IFlashLoanRecipient(address(bancorArbitrage)), bnt, AMOUNT, 0);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test correct obtaining and repayment of flashloan from balancer
     */
    function testShouldCorrectlyObtainAndRepayMultipleTokenFlashloanFromBalancer() public {
        IERC20[] memory tokens = new IERC20[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = bnt;
        amounts[0] = AMOUNT;
        tokens[1] = arbToken1;
        amounts[1] = AMOUNT;
        BancorArbitrage.Flashloan[] memory flashloans = getFlashloanDataForBalancer(tokens, amounts);
        // get routes
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomLength(
            3,
            uint16(PlatformId.UNISWAP_V3_FORK),
            0,
            AMOUNT
        );
        // expect two flashloan events are emitted from the flashloan source (balancer vault)
        vm.expectEmit(true, true, true, true);
        emit FlashLoan(IFlashLoanRecipient(address(bancorArbitrage)), bnt, AMOUNT, 0);
        vm.expectEmit(true, true, true, true);
        emit FlashLoan(IFlashLoanRecipient(address(bancorArbitrage)), arbToken1, AMOUNT, 0);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test correct obtaining and repayment of flashloan from balancer and bancor v3
     */
    function testShouldCorrectlyObtainAndRepayFlashloansFromBalancerAndBancorV3() public {
        IERC20[] memory tokensBancorV3 = new IERC20[](1);
        uint256[] memory amountsBancorV3 = new uint256[](1);
        IERC20[] memory tokensBalancer = new IERC20[](2);
        uint256[] memory amountsBalancer = new uint256[](2);
        tokensBancorV3[0] = arbToken2;
        amountsBancorV3[0] = AMOUNT;
        tokensBalancer[0] = bnt;
        amountsBalancer[0] = AMOUNT;
        tokensBalancer[1] = arbToken1;
        amountsBalancer[1] = AMOUNT;

        BancorArbitrage.Flashloan[] memory flashloans = getCombinedFlashloanData(
            tokensBalancer,
            amountsBalancer,
            tokensBancorV3,
            amountsBancorV3
        );

        // get routes
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomLength(
            3,
            uint16(PlatformId.UNISWAP_V3_FORK),
            0,
            AMOUNT
        );
        // expect all three flashloan events are emitted from the flashloan sources
        vm.expectEmit(true, true, true, true);
        // bancor v3 flashloan event
        emit FlashLoanCompleted(Token(address(arbToken2)), address(bancorArbitrage), AMOUNT, 0);
        vm.expectEmit(true, true, true, true);
        // balancer flashloan event
        emit FlashLoan(IFlashLoanRecipient(address(bancorArbitrage)), bnt, AMOUNT, 0);
        vm.expectEmit(true, true, true, true);
        // balancer flashloan event
        emit FlashLoan(IFlashLoanRecipient(address(bancorArbitrage)), arbToken1, AMOUNT, 0);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test that onFlashloan cannot be called directly
     */
    function testShouldntBeAbleToCallOnFlashloanDirectly() public {
        vm.expectRevert(BancorArbitrage.InvalidFlashLoanCaller.selector);
        bancorArbitrage.onFlashLoan(address(bancorArbitrage), IERC20(address(bnt)), 1, 0, "0x");
    }

    /**
     * @dev test that receiveFlashloan cannot be called directly
     */
    function testShouldntBeAbleToCallReceiveFlashloanDirectly() public {
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory feeAmounts = new uint256[](1);
        tokens[0] = IERC20(address(bnt));
        amounts[0] = 1;
        feeAmounts[0] = 0;
        vm.expectRevert(BancorArbitrage.InvalidFlashLoanCaller.selector);
        bancorArbitrage.receiveFlashLoan(tokens, amounts, feeAmounts, "0x");
    }

    /**
     * @dev test that flashloan attempt reverts if platform id is not supported
     */
    function testShouldRevertIfPlatformIdIsNotSupportedForFlashloan() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        flashloans[0].platformId = uint16(PlatformId.BANCOR_V2);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectRevert(BancorArbitrage.InvalidFlashloanPlatformId.selector);
        executeArbitrage(flashloans, routes, false);
    }

    /**
     * @dev test that flashloan attempt reverts empty flashloan array is passed
     */
    function testShouldRevertIfEmptyFlashloanArrayIsPassed() public {
        BancorArbitrage.Flashloan[] memory flashloans = new BancorArbitrage.Flashloan[](0);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectRevert(BancorArbitrage.InvalidFlashloanFormat.selector);
        executeArbitrage(flashloans, routes, false);
    }

    /**
     * @dev test that flashloan attempt reverts empty flashloan source tokens array is passed
     */
    function testShouldRevertIfEmptyFlashloanTokensArrayIsPassed() public {
        BancorArbitrage.Flashloan[] memory flashloans = new BancorArbitrage.Flashloan[](1);
        IERC20[] memory sourceTokens = new IERC20[](0);
        uint256[] memory sourceAmounts = new uint256[](0);
        flashloans[0].platformId = uint16(PlatformId.BALANCER);
        flashloans[0].sourceTokens = sourceTokens;
        flashloans[0].sourceAmounts = sourceAmounts;
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectRevert(BancorArbitrage.InvalidFlashloanFormat.selector);
        executeArbitrage(flashloans, routes, false);
    }

    /**
     * @dev test that flashloan attempt reverts if lengths of source tokens and amounts is different
     */
    function testShouldRevertIfFlashloanTokensAndAmountsLengthsDiffer() public {
        BancorArbitrage.Flashloan[] memory flashloans = new BancorArbitrage.Flashloan[](1);
        IERC20[] memory sourceTokens = new IERC20[](1);
        uint256[] memory sourceAmounts = new uint256[](2);
        flashloans[0].platformId = uint16(PlatformId.BALANCER);
        flashloans[0].sourceTokens = sourceTokens;
        flashloans[0].sourceAmounts = sourceAmounts;
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectRevert(BancorArbitrage.InvalidFlashloanFormat.selector);
        executeArbitrage(flashloans, routes, false);
    }

    /**
     * @dev test that flashloan attempt reverts if bancor v3 has more than one source token
     */
    function testShouldRevertIfBancorV3FlashloanHasMoreThanOneSourceToken() public {
        BancorArbitrage.Flashloan[] memory flashloans = new BancorArbitrage.Flashloan[](1);
        IERC20[] memory sourceTokens = new IERC20[](2);
        uint256[] memory sourceAmounts = new uint256[](2);
        flashloans[0].platformId = uint16(PlatformId.BANCOR_V3);
        flashloans[0].sourceTokens = sourceTokens;
        flashloans[0].sourceAmounts = sourceAmounts;
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectRevert(BancorArbitrage.InvalidFlashloanFormat.selector);
        executeArbitrage(flashloans, routes, false);
    }

    /**
     * @dev test that flashloan attempt reverts if any of the flashloan source amounts are zero
     */
    function testShouldRevertIfAnyOfTheFlashloanSourceAmountsAreZero() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        flashloans[0].sourceAmounts[0] = 0;
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectRevert(ZeroValue.selector);
        executeArbitrage(flashloans, routes, false);
    }

    /**
     * @dev test should revert if flashloan cannot be obtained from bancor v3
     */
    function testShouldRevertIfFlashloanCannotBeObtainedFromBancorV3() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, type(uint256).max);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test should revert if flashloan cannot be obtained from balancer
     */
    function testShouldRevertIfFlashloanCannotBeObtainedFromBalancer() public {
        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = bnt;
        amounts[0] = type(uint256).max;
        BancorArbitrage.Flashloan[] memory flashloans = getFlashloanDataForBalancer(tokens, amounts);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectRevert(MockBalancerVault.NotEnoughBalanceForFlashloan.selector);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /// --- Trade tests --- ///

    /**
     * @dev test that trade attempt if deadline is > block.timestamp reverts
     */
    function testShouldRevertIfDeadlineIsReached() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        // move block.timestamp forward by 1000 sec
        skip(1000);
        // set deadline to 1
        routes[0].deadline = 1;
        routes[1].deadline = 1;
        routes[2].deadline = 1;
        vm.expectRevert();
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test that trade attempt reverts if platform id is not supported
     */
    function testShouldRevertIfPlatformIdIsNotSupportedForTrade(bool userFunded) public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        routes[0].platformId = 0;
        vm.startPrank(user1);
        Token(address(bnt)).safeApprove(address(bancorArbitrage), AMOUNT);
        vm.expectRevert(BancorArbitrage.InvalidTradePlatformId.selector);
        vm.stopPrank();
        executeArbitrageNoApproval(flashloans, routes, userFunded);
    }

    /**
     * @dev test that trade attempt with invalid route length
     */
    function testShouldRevertIfRouteLengthIsInvalid(bool userFunded) public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        // attempt to route through 11 exchanges
        BancorArbitrage.TradeRoute[] memory longRoute = new BancorArbitrage.TradeRoute[](11);

        vm.expectRevert(BancorArbitrage.InvalidRouteLength.selector);
        executeArbitrageNoApproval(flashloans, longRoute, userFunded);
        // attempt to route through 0 exchanges
        BancorArbitrage.TradeRoute[] memory emptyRoute = new BancorArbitrage.TradeRoute[](0);
        vm.expectRevert(BancorArbitrage.InvalidRouteLength.selector);
        executeArbitrageNoApproval(flashloans, emptyRoute, userFunded);
    }

    /**
     * @dev test attempting to trade with more than exchange's balance reverts
     */
    function testShouldRevertIfExchangeDoesntHaveEnoughBalanceForFlashloan() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, MAX_SOURCE_AMOUNT * 2);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test reverts if min target amount is greater than expected
     * @dev test both user-funded and flashloan arbs
     */
    function testShouldRevertIfMinTargetAmountIsGreaterThanExpected(bool userFunded) public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        routes[0].minTargetAmount = type(uint256).max;
        vm.startPrank(user1);
        Token(address(bnt)).safeApprove(address(bancorArbitrage), AMOUNT);
        vm.expectRevert("InsufficientTargetAmount");
        vm.stopPrank();
        executeArbitrageNoApproval(flashloans, routes, userFunded);
    }

    /**
     * @dev test reverts if the source token isn't whitelisted
     * @dev test flashloan arbs
     */
    function testShouldRevertIfFlashloanTokenIsntWhitelisted() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(nonWhitelistedToken, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectRevert(MockExchanges.NotWhitelisted.selector);
        // make arb with the non-whitelisted token
        executeArbitrageNoApproval(flashloans, routes, false);
    }

    /**
     * @dev test reverts if the source token isn't tradeable on bancor network v3
     * @dev test user-funded arb
     */
    function testShouldRevertIfUserFundedArbLastArbTokenIsntEqualToInitialArbToken() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(nonWhitelistedToken, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        // set last token to be different from bnt
        routes[2].targetToken = Token(address(arbToken2));
        routes[2].customAddress = address(arbToken2);
        vm.expectRevert(BancorArbitrage.InvalidInitialAndFinalTokens.selector);
        // make arb with the non-whitelisted token
        executeArbitrageNoApproval(flashloans, routes, true);
    }

    /**
     * @dev test reverts if the path is invalid
     * @dev the test uses same input and output token for the second swap
     */
    function testShouldRevertIfThePathIsInvalid() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        routes[1].platformId = uint16(PlatformId.BANCOR_V2);
        routes[1].targetToken = Token(address(arbToken1));
        routes[1].customAddress = address(arbToken1);
        vm.expectRevert("Invalid swap");
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test trade approvals for erc-20 tokens for exchanges (without WETH exchange)
     * @dev should approve max amount for trading on each first swap for token and exchange
     */
    function testShouldApproveERC20TokensForEachExchange(uint16 platformId, bool userFunded) public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        // bound to valid exchange ids
        platformId = uint16(bound(platformId, FIRST_EXCHANGE_ID, LAST_EXCHANGE_ID));
        address[] memory tokensToTrade = new address[](3);
        tokensToTrade[0] = address(arbToken1);
        tokensToTrade[1] = address(arbToken2);
        tokensToTrade[2] = address(TokenLibrary.NATIVE_TOKEN);
        uint256 approveAmount = type(uint256).max;
        address aprovee = platformId == uint16(PlatformId.BALANCER) ? address(balancerVault) : address(exchanges);

        // test with all token combinations
        for (uint256 i = 0; i < 3; ++i) {
            for (uint256 j = 0; j < 3; ++j) {
                if (i == j) {
                    continue;
                }
                BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
                    platformId,
                    tokensToTrade[i],
                    tokensToTrade[j],
                    address(bnt),
                    AMOUNT,
                    500
                );
                // verify that this is a valid test configuration
                if (!isValidTestConfiguration(platformId, routes)) {
                    continue;
                }
                setCurveTokens(routes);
                vm.startPrank(user1);
                // approve token if user-funded arb
                if (userFunded) {
                    Token(address(bnt)).safeApprove(address(bancorArbitrage), AMOUNT);
                }
                uint256 allowance = arbToken1.allowance(address(bancorArbitrage), aprovee);
                if (allowance == 0) {
                    // expect arbToken1 to emit the approval event
                    vm.expectEmit(true, true, true, true, address(arbToken1));
                    emit Approval(address(bancorArbitrage), aprovee, approveAmount);
                }
                vm.stopPrank();
                executeArbitrageNoApproval(flashloans, routes, userFunded);
            }
        }
    }

    /**
     * @dev test trade approvals for erc-20 tokens for the carbon pol (only BNT -> ETH)
     * @dev should approve max amount for trading
     */
    function testShouldApproveERC20TokensForCarbonPOL(bool userFunded) public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(arbToken1, AMOUNT);
        // bound to valid exchange ids
        uint16 platformId = uint16(PlatformId.CARBON_POL);
        uint256 approveAmount = type(uint256).max;

        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            platformId,
            address(bnt),
            address(TokenLibrary.NATIVE_TOKEN),
            address(arbToken1),
            AMOUNT,
            0
        );
        vm.startPrank(user1);
        // approve token if user-funded arb
        if (userFunded) {
            Token(address(arbToken1)).safeApprove(address(bancorArbitrage), type(uint256).max);
        }
        uint256 allowance = bnt.allowance(address(bancorArbitrage), address(exchanges));
        if (allowance == 0) {
            // expect bnt to emit the approval event
            vm.expectEmit(true, true, true, true, address(bnt));
            emit Approval(address(bancorArbitrage), address(exchanges), approveAmount);
        }
        vm.stopPrank();
        executeArbitrageNoApproval(flashloans, routes, userFunded);
    }

    /// --- Arbitrage tests --- ///

    /**
     * @dev test arbitrage executed event gets emitted
     */
    function testShouldEmitArbitrageExecutedOnSuccessfulFlashloanArb() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        uint16[] memory exchangeIds = new uint16[](0);
        address[] memory tradePath = new address[](0);
        address[] memory sourceTokens = new address[](1);
        uint256[] memory sourceAmounts = new uint256[](1);
        uint256[] memory protocolAmounts = new uint256[](0);
        uint256[] memory rewardAmounts = new uint256[](0);
        sourceTokens[0] = address(bnt);
        sourceAmounts[0] = AMOUNT;
        vm.expectEmit(false, false, false, false);
        emit ArbitrageExecuted(
            admin,
            exchangeIds,
            tradePath,
            sourceTokens,
            sourceAmounts,
            protocolAmounts,
            rewardAmounts
        );
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test proper arbitrage executed sourceTokens and sourceAmounts parameters
     * @dev sourceTokens and sourceAmounts must be in flashloans order
     */
    function testArbitrageExecutedParams() public {
        IERC20[] memory tokensBalancer = new IERC20[](2);
        uint256[] memory amountsBalancer = new uint256[](2);
        IERC20[] memory tokensBancorV3 = new IERC20[](1);
        uint256[] memory amountsBancorV3 = new uint256[](1);
        tokensBalancer[0] = bnt;
        amountsBalancer[0] = AMOUNT;
        tokensBalancer[1] = arbToken1;
        amountsBalancer[1] = AMOUNT;
        tokensBancorV3[0] = arbToken2;
        amountsBancorV3[0] = AMOUNT;

        BancorArbitrage.Flashloan[] memory flashloans = getCombinedFlashloanData(
            tokensBalancer,
            amountsBalancer,
            tokensBancorV3,
            amountsBancorV3
        );
        // get routes
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomLength(
            3,
            uint16(PlatformId.UNISWAP_V3_FORK),
            0,
            AMOUNT
        );
        (uint16[] memory exchangeIds, address[] memory tokenPath) = buildArbPath(routes);

        (
            uint256[] memory rewardAmounts,
            uint256[] memory protocolAmounts
        ) = calculateExpectedUserRewardsAndProtocolAmountsMultipleFlashloans(3);
        rewardAmounts[1] = 0;
        rewardAmounts[2] = 0;
        protocolAmounts[1] = 0;
        protocolAmounts[2] = 0;
        address[] memory sourceTokens = new address[](3);
        uint256[] memory sourceAmounts = new uint256[](3);
        sourceTokens[0] = address(bnt);
        sourceAmounts[0] = AMOUNT;
        sourceTokens[1] = address(arbToken1);
        sourceAmounts[1] = AMOUNT;
        sourceTokens[2] = address(arbToken2);
        sourceAmounts[2] = AMOUNT;
        vm.expectEmit(true, true, true, true);
        emit ArbitrageExecuted(
            user1,
            exchangeIds,
            tokenPath,
            sourceTokens,
            sourceAmounts,
            protocolAmounts,
            rewardAmounts
        );
        vm.prank(user1);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test proper arbitrage executed parameters - without passing in customAddress for uni v2/v3 and sushiswap
     */
    function testArbitrageExecutedUniV2V3SushiswapBackwardsCompatibility() public {
        IERC20[] memory tokensBalancer = new IERC20[](2);
        uint256[] memory amountsBalancer = new uint256[](2);
        IERC20[] memory tokensBancorV3 = new IERC20[](1);
        uint256[] memory amountsBancorV3 = new uint256[](1);
        tokensBalancer[0] = bnt;
        amountsBalancer[0] = AMOUNT;
        tokensBalancer[1] = arbToken1;
        amountsBalancer[1] = AMOUNT;
        tokensBancorV3[0] = arbToken2;
        amountsBancorV3[0] = AMOUNT;

        BancorArbitrage.Flashloan[] memory flashloans = getCombinedFlashloanData(
            tokensBalancer,
            amountsBalancer,
            tokensBancorV3,
            amountsBancorV3
        );
        // get routes
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomLength(
            3,
            uint16(PlatformId.UNISWAP_V3_FORK),
            0,
            AMOUNT
        );
        // set custom address to 0 for uniswap v3
        routes[1].customAddress = address(0);
        (uint16[] memory exchangeIds, address[] memory tokenPath) = buildArbPath(routes);

        (
            uint256[] memory rewardAmounts,
            uint256[] memory protocolAmounts
        ) = calculateExpectedUserRewardsAndProtocolAmountsMultipleFlashloans(3);
        rewardAmounts[1] = 0;
        rewardAmounts[2] = 0;
        protocolAmounts[1] = 0;
        protocolAmounts[2] = 0;
        address[] memory sourceTokens = new address[](3);
        uint256[] memory sourceAmounts = new uint256[](3);
        sourceTokens[0] = address(bnt);
        sourceAmounts[0] = AMOUNT;
        sourceTokens[1] = address(arbToken1);
        sourceAmounts[1] = AMOUNT;
        sourceTokens[2] = address(arbToken2);
        sourceAmounts[2] = AMOUNT;
        vm.expectEmit(true, true, true, true);
        emit ArbitrageExecuted(
            user1,
            exchangeIds,
            tokenPath,
            sourceTokens,
            sourceAmounts,
            protocolAmounts,
            rewardAmounts
        );
        // test uni v3
        vm.startPrank(user1);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);

        // test uni v2
        routes = getRoutesCustomLength(3, uint16(PlatformId.UNISWAP_V2_FORK), 0, AMOUNT);
        // set custom address to 0 for uniswap v2
        routes[1].customAddress = address(0);
        (exchangeIds, tokenPath) = buildArbPath(routes);
        vm.expectEmit(true, true, true, true);
        emit ArbitrageExecuted(
            user1,
            exchangeIds,
            tokenPath,
            sourceTokens,
            sourceAmounts,
            protocolAmounts,
            rewardAmounts
        );
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);

        // test sushiswap
        routes = getRoutesCustomLength(3, uint16(PlatformId.SUSHISWAP), 0, AMOUNT);
        // set custom address to 0 for sushiswap
        routes[1].customAddress = address(0);
        (exchangeIds, tokenPath) = buildArbPath(routes);
        vm.expectEmit(true, true, true, true);
        emit ArbitrageExecuted(
            user1,
            exchangeIds,
            tokenPath,
            sourceTokens,
            sourceAmounts,
            protocolAmounts,
            rewardAmounts
        );
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test proper arbitrage executed parameters - without passing in customAddress for carbon
     */
    function testCarbonArbitrageExecutedBackwardCompatibility() public {
        vm.startPrank(user1);
        // get flashloan data
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);

        // test carbon
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCarbon(
            address(arbToken1),
            address(arbToken2),
            AMOUNT,
            3,
            false
        );
        // set custom address to 0 for carbon
        routes[1].customAddress = address(0);

        (uint16[] memory exchangeIds, address[] memory tokenPath) = buildArbPath(routes);

        address[] memory sourceTokens = new address[](1);
        uint256[] memory sourceAmounts = new uint256[](1);
        sourceTokens[0] = address(bnt);
        sourceAmounts[0] = AMOUNT;
        (
            uint256[] memory rewardAmounts,
            uint256[] memory protocolAmounts
        ) = calculateExpectedUserRewardsAndProtocolAmounts();

        vm.expectEmit(true, true, true, true);
        emit ArbitrageExecuted(
            user1,
            exchangeIds,
            tokenPath,
            sourceTokens,
            sourceAmounts,
            protocolAmounts,
            rewardAmounts
        );
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
        vm.stopPrank();
    }

    /**
     * @dev test arbitrage executed event gets emitted
     */
    function testShouldEmitArbitrageExecutedOnSuccessfulUserFundedArb() public {
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        uint16[] memory exchangeIds = new uint16[](0);
        address[] memory tradePath = new address[](0);
        uint256[] memory protocolAmounts = new uint256[](0);
        uint256[] memory rewardAmounts = new uint256[](0);
        address[] memory sourceTokens = new address[](1);
        uint256[] memory sourceAmounts = new uint256[](1);
        sourceTokens[0] = address(bnt);
        sourceAmounts[0] = AMOUNT;
        vm.startPrank(admin);
        bnt.approve(address(bancorArbitrage), AMOUNT);
        vm.expectEmit(false, false, false, false);
        emit ArbitrageExecuted(
            admin,
            exchangeIds,
            tradePath,
            sourceTokens,
            sourceAmounts,
            protocolAmounts,
            rewardAmounts
        );
        bancorArbitrage.fundAndArb(routes, Token(address(bnt)), AMOUNT);
        vm.stopPrank();
    }

    /**
     * @dev test that any address can execute arbs
     */
    function testAnyoneCanExecuteArbs(address user) public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        // assume user is not proxy admin or 0x0 address
        vm.assume(user != address(proxyAdmin) && user != address(0));
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        // impersonate user
        vm.prank(user);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev fuzz test arbitrage execution
     * @dev go through all exchanges and use different amounts
     * @dev test both user-funded and flashloan arbs
     */
    function testArbitrage(uint16 platformId, uint256 arbAmount, uint256 fee, bool userFunded) public {
        // limit arbAmount to AMOUNT
        vm.assume(arbAmount > 0 && arbAmount < AMOUNT);
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, arbAmount);
        // test exchange ids 1 - 5 (w/o Carbon)
        platformId = uint16(bound(platformId, FIRST_EXCHANGE_ID, 5));
        address[] memory tokensToTrade = new address[](3);
        tokensToTrade[0] = address(arbToken1);
        tokensToTrade[1] = address(arbToken2);
        tokensToTrade[2] = address(TokenLibrary.NATIVE_TOKEN);

        // test with all token combinations
        for (uint256 i = 0; i < 3; ++i) {
            for (uint256 j = 0; j < 3; ++j) {
                if (i == j) {
                    continue;
                }
                BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
                    platformId,
                    tokensToTrade[i],
                    tokensToTrade[j],
                    address(bnt),
                    arbAmount,
                    fee
                );
                // verify that this is a valid test configuration
                if (!isValidTestConfiguration(platformId, routes)) {
                    continue;
                }
                executeArbitrage(flashloans, routes, userFunded);
            }
        }
    }

    /**
     * @dev test arbitrages with different route length
     * @dev fuzz test 2 - 10 routes on any exchange with any amount
     * @dev test both user-funded and flashloan arbs
     */
    function testArbitrageWithDifferentRoutes(
        uint256 routeLength,
        uint16 platformId,
        uint256 arbAmount,
        uint256 fee,
        bool userFunded
    ) public {
        // bound route len from 2 to 10
        routeLength = bound(routeLength, 2, 10);
        // bound exchange id to valid exchange ids
        platformId = uint16(bound(platformId, FIRST_EXCHANGE_ID, LAST_EXCHANGE_ID));
        // bound arb amount from 1 to AMOUNT
        arbAmount = bound(arbAmount, 1, AMOUNT);
        // get flashloans
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, arbAmount);
        // get routes
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomLength(routeLength, platformId, fee, arbAmount);
        // verify that this is a valid test configuration
        if (!isValidTestConfiguration(platformId, routes)) {
            return;
        }
        setCurveTokens(routes);
        // trade
        executeArbitrage(flashloans, routes, userFunded);
    }

    /**
     * @dev fuzz test arbs on carbon pol - from BNT to ETH
     * @dev use different arb amounts
     * @dev test both user-funded and flashloan arbs
     */
    function testArbitrageOnCarbonPOL(uint256 arbAmount, bool userFunded) public {
        // bound arb amount from 1 to AMOUNT
        arbAmount = bound(arbAmount, 1, AMOUNT);
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(arbToken1, arbAmount);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.CARBON_POL),
            address(bnt),
            address(TokenLibrary.NATIVE_TOKEN),
            address(arbToken1),
            arbAmount,
            0
        );
        executeArbitrage(flashloans, routes, userFunded);
    }

    /**
     * @dev fuzz test arbs on carbon
     * @dev use different arb amounts and 1 to 11 trade actions for the carbon arb
     * @dev test both user-funded and flashloan arbs
     */
    function testArbitrageOnCarbon(uint256 arbAmount, uint256 tradeActionCount, bool userFunded) public {
        // bound arb amount from 1 to AMOUNT
        arbAmount = bound(arbAmount, 1, AMOUNT);
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, arbAmount);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCarbon(
            address(arbToken1),
            address(arbToken2),
            arbAmount,
            tradeActionCount,
            false
        );
        executeArbitrage(flashloans, routes, userFunded);
    }

    /**
     * @dev fuzz test arbs on carbon
     * @dev use different arb amounts and 1 to 11 trade actions for the carbon arb
     * @dev test both user-funded and flashloan arbs
     */
    function testTradeByTargetArbitrageOnCarbon(uint256 arbAmount, uint256 tradeActionCount, bool userFunded) public {
        // bound arb amount from 1 to AMOUNT
        arbAmount = bound(arbAmount, 1, AMOUNT);
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, arbAmount);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCarbon(
            address(arbToken1),
            address(arbToken2),
            arbAmount,
            tradeActionCount,
            true
        );
        executeArbitrage(flashloans, routes, userFunded);
    }

    /**
     * @dev test transferring leftover source tokens from the carbon trade to the protocol wallet
     * @dev test both user-funded and flashloan arbs
     * @param arbAmount arb amount to test with
     * @param leftoverAmount amount of tokens left over after the carbon trade
     * @param userFunded whether arb is user funded or flashloan
     */
    function testShouldTransferLeftoverSourceTokensFromCarbonTrade(
        uint256 arbAmount,
        uint256 leftoverAmount,
        bool userFunded
    ) public {
        // bound arb amount from 1 to AMOUNT
        arbAmount = bound(arbAmount, 1, AMOUNT);
        // bound leftover amount from 1 to 300 units
        leftoverAmount = bound(leftoverAmount, 1, 300 ether);
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, arbAmount);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        routes[1].platformId = uint16(PlatformId.CARBON_FORK);
        uint256 sourceTokenAmountForCarbonTrade = arbAmount + 300 ether;
        // encode less tokens for the trade than the source token balance at this point in the arb
        routes[1].customData = getCarbonData(sourceTokenAmountForCarbonTrade - leftoverAmount);

        // get source token balance in the protocol wallet before the trade
        uint256 sourceBalanceBefore = arbToken1.balanceOf(protocolWallet);

        // execute arb
        executeArbitrage(flashloans, routes, userFunded);

        // get source token balance in the protocol wallet after the trade
        uint256 sourceBalanceAfter = arbToken1.balanceOf(protocolWallet);
        uint256 sourceBalanceTransferred = sourceBalanceAfter - sourceBalanceBefore;

        // assert that the entire leftover amount is transferred to the protocol wallet
        assertEq(leftoverAmount, sourceBalanceTransferred);
        // assert that no source tokens are left in the arb contract
        assertEq(arbToken1.balanceOf(address(bancorArbitrage)), 0);
    }

    /**
     * @dev fuzz test arbitrage execution with different initial tokens
     * @dev go through all exchanges and use different amounts
     * @dev test both user-funded and flashloan arbs
     */
    function testArbitrageWithDifferentTokens(
        uint16 platformId,
        uint256 arbAmount,
        uint256 fee,
        bool userFunded
    ) public {
        // limit arbAmount to AMOUNT
        vm.assume(arbAmount > 0 && arbAmount < AMOUNT);
        // test exchange ids 1 - 5 (w/o Carbon)
        platformId = uint16(bound(platformId, FIRST_EXCHANGE_ID, 5));
        address[] memory tokensToTrade = new address[](3);
        tokensToTrade[0] = address(arbToken1);
        tokensToTrade[1] = address(arbToken2);
        tokensToTrade[2] = address(TokenLibrary.NATIVE_TOKEN);

        // test with all token combinations
        for (uint256 i = 0; i < 3; ++i) {
            for (uint256 j = 0; j < 3; ++j) {
                for (uint256 k = 0; k < 3; ++k) {
                    if (i == j || i == k || j == k) {
                        continue;
                    }
                    BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(
                        IERC20(tokensToTrade[k]),
                        arbAmount
                    );
                    BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
                        platformId,
                        tokensToTrade[i],
                        tokensToTrade[j],
                        tokensToTrade[k],
                        arbAmount,
                        fee
                    );
                    if (!isValidTestConfiguration(platformId, routes)) {
                        continue;
                    }
                    executeArbitrage(flashloans, routes, userFunded);
                }
            }
        }
    }

    /**
     * @dev fuzz test arbitrage execution with multiple flashloans
     * @dev go through all exchanges and use different amounts
     * @dev test flashloan arbs
     */
    function testArbitrageWithMultipleFlashloans(uint16 platformId, uint256 arbAmount) public {
        // limit arbAmount to AMOUNT
        vm.assume(arbAmount > 0 && arbAmount < AMOUNT);
        // test exchange ids 1 - 5 (w/o Carbon)
        platformId = uint16(bound(platformId, FIRST_EXCHANGE_ID, 5));
        address[] memory tokensToTrade = new address[](3);
        tokensToTrade[0] = address(arbToken1);
        tokensToTrade[1] = address(arbToken2);
        tokensToTrade[2] = address(TokenLibrary.NATIVE_TOKEN);

        // test with all token combinations
        for (uint256 i = 0; i < 3; ++i) {
            for (uint256 j = 0; j < 3; ++j) {
                for (uint256 k = 0; k < 3; ++k) {
                    if (i == j || i == k || j == k) {
                        continue;
                    }
                    // initialize intermediary tokens for routes
                    address[] memory tokens = new address[](6);
                    tokens[0] = tokensToTrade[j];
                    tokens[1] = tokensToTrade[k];
                    tokens[2] = tokensToTrade[i];
                    tokens[3] = tokensToTrade[k];
                    tokens[4] = tokensToTrade[i];
                    tokens[5] = tokensToTrade[j];
                    // get flashloan data for 3 token flashloans
                    BancorArbitrage.Flashloan[] memory flashloans = getCombinedFlashloanDataForSeveralTokens(
                        tokensToTrade[i],
                        AMOUNT,
                        tokensToTrade[j],
                        AMOUNT,
                        tokensToTrade[k],
                        AMOUNT
                    );
                    // get custom routes for all tokens with 3 flashloans
                    BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokensMultipleFlashloans(
                        platformId,
                        tokensToTrade[i],
                        tokensToTrade[j],
                        tokensToTrade[k],
                        tokens,
                        arbAmount,
                        500
                    );
                    if (!isValidTestConfiguration(platformId, routes)) {
                        continue;
                    }
                    executeArbitrage(flashloans, routes, false);
                }
            }
        }
    }

    /**
     * @dev test native token arbitrage on uni v3 by wrapping using WETH platform
     */
    function testUniV3NativeTokenArbitrageWrap(uint256 arbAmount, uint256 fee) public {
        // limit arbAmount to AMOUNT
        vm.assume(arbAmount > 0 && arbAmount < AMOUNT);

        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, arbAmount);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.UNISWAP_V3_FORK),
            address(TokenLibrary.NATIVE_TOKEN),
            address(arbToken2),
            address(bnt),
            arbAmount,
            fee
        );

        // wrap ETH on WETH platform before trading on uni v3
        routes = convertUniV3NativeTokenRouteWrap(routes);
        executeArbitrage(flashloans, routes, false);
    }

    /**
     * @dev test native token arbitrage on uni v3 by unwrapping using WETH platform
     */
    function testUniV3NativeTokenArbitrageUnwrap(uint256 arbAmount, uint256 fee) public {
        // limit arbAmount to AMOUNT
        vm.assume(arbAmount > 0 && arbAmount < AMOUNT);

        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, arbAmount);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.UNISWAP_V3_FORK),
            address(arbToken1),
            address(weth),
            address(bnt),
            arbAmount,
            fee
        );

        // unwrap wETH on WETH platform after trading on uni v3
        routes = convertUniV3NativeTokenRouteUnwrap(routes);
        executeArbitrage(flashloans, routes, false);
    }

    /**
     * @dev test user funded arbs return users tokens
     * @dev go through all exchanges and use different amounts
     */
    function testUserFundedArbsReturnUsersTokens(uint16 platformId, uint256 arbAmount, uint256 fee) public {
        // limit arbAmount to AMOUNT
        vm.assume(arbAmount > 0 && arbAmount < AMOUNT);
        // test exchange ids 1 - 5 (w/o Carbon)
        platformId = uint16(bound(platformId, FIRST_EXCHANGE_ID, 5));
        address[] memory tokensToTrade = new address[](3);
        tokensToTrade[0] = address(arbToken1);
        tokensToTrade[1] = address(arbToken2);
        tokensToTrade[2] = address(TokenLibrary.NATIVE_TOKEN);

        // test with all token combinations
        for (uint256 i = 0; i < 3; ++i) {
            for (uint256 j = 0; j < 3; ++j) {
                for (uint256 k = 0; k < 3; ++k) {
                    if (i == j || i == k || j == k) {
                        continue;
                    }
                    BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(
                        IERC20(tokensToTrade[k]),
                        arbAmount
                    );
                    BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
                        platformId,
                        tokensToTrade[i],
                        tokensToTrade[j],
                        tokensToTrade[k],
                        arbAmount,
                        fee
                    );
                    if (!isValidTestConfiguration(platformId, routes)) {
                        continue;
                    }
                    uint256 balanceBefore = Token(tokensToTrade[k]).balanceOf(user1);
                    executeArbitrage(flashloans, routes, true);
                    uint256 balanceAfter = Token(tokensToTrade[k]).balanceOf(user1);
                    assertGe(balanceAfter, balanceBefore);
                }
            }
        }
    }

    /**
     * @dev test that arb hop with 0 source amount for routes will take the available source amount
     */
    function testShouldTakeAvailableBalanceIfSourceAmountIsZero(bool userFunded) public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        // getRoutes returns routes with 0 sourceAmount for each Route
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        uint256 balanceBefore = bnt.balanceOf(user1);
        vm.startPrank(user1);
        if (userFunded) {
            Token(address(bnt)).safeApprove(address(bancorArbitrage), AMOUNT);
        }
        vm.stopPrank();
        // make arb with AMOUNT
        executeArbitrageNoApproval(flashloans, routes, userFunded);
        // get user gain and calculate expected gain
        uint256 balanceAfter = bnt.balanceOf(user1);
        uint256 gain = balanceAfter - balanceBefore;
        uint256 hopGain = exchanges.outputAmount();
        uint256 totalRewards = routes.length * hopGain;
        BancorArbitrage.Rewards memory rewards = bancorArbitrage.rewards();
        uint256 expectedGain = (totalRewards * rewards.percentagePPM) / PPM_RESOLUTION;
        // check that the user has received exactly the expected tokens
        assertEq(gain, expectedGain);
    }

    /**
     * @dev test that arb hop with > available source amount will be capped to the currently available source amount
     */
    function testShouldTakeAvailableBalanceIfSourceAmountIsLarger(
        bool userFunded,
        uint256 firstHopSourceAmount
    ) public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        // bound the firstHopSourceAmount to a value larger than the arb amount
        bound(firstHopSourceAmount, AMOUNT + 1, type(uint256).max);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        routes[0].sourceAmount = firstHopSourceAmount; // set first hop source amount to firstHopSourceAmount
        uint256 balanceBefore = bnt.balanceOf(user1);
        vm.startPrank(user1);
        if (userFunded) {
            Token(address(bnt)).safeApprove(address(bancorArbitrage), AMOUNT);
        }
        vm.stopPrank();
        // make arb with AMOUNT
        executeArbitrageNoApproval(flashloans, routes, userFunded);
        // get user gain and calculate expected gain
        uint256 balanceAfter = bnt.balanceOf(user1);
        uint256 gain = balanceAfter - balanceBefore;
        uint256 hopGain = exchanges.outputAmount();
        uint256 totalRewards = routes.length * hopGain;
        BancorArbitrage.Rewards memory rewards = bancorArbitrage.rewards();
        uint256 expectedGain = (totalRewards * rewards.percentagePPM) / PPM_RESOLUTION;
        // check that the user has received exactly the expected tokens
        assertEq(gain, expectedGain);
    }

    /**
     * @dev test that arb hop will take only the specified source amount as input
     *      leftover tokens get swept to the protocol wallet at the end of the arb
     */
    function testArbHopShouldTakeOnlyTheSpecifiedSourceAmountAsInput(bool userFunded) public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        // set second hop to AMOUNT + 200 arb token 1 as input
        // after the first hop, we have AMOUNT + 300 arbToken1 tokens available
        routes[1].sourceAmount = AMOUNT + 200e18;
        // set third hop to AMOUNT + 400 arb token 2 as input
        // after the second hop, we have AMOUNT + 500 arbToken2 tokens available
        routes[2].sourceAmount = AMOUNT + 400e18;
        vm.startPrank(user1);
        if (userFunded) {
            Token(address(bnt)).safeApprove(address(bancorArbitrage), AMOUNT);
        }
        vm.stopPrank();
        uint256 userBalanceBefore = bnt.balanceOf(user1);
        uint256 balanceBefore1 = arbToken1.balanceOf(address(protocolWallet));
        uint256 balanceBefore2 = arbToken2.balanceOf(address(protocolWallet));
        // make arb with AMOUNT
        executeArbitrageNoApproval(flashloans, routes, userFunded);
        // get user and arb contract balances
        uint256 userBalanceAfter = bnt.balanceOf(user1);
        uint256 balanceAfter1 = arbToken1.balanceOf(address(protocolWallet));
        uint256 balanceAfter2 = arbToken2.balanceOf(address(protocolWallet));
        uint256 userGain = userBalanceAfter - userBalanceBefore;
        // calculate expected user gain
        uint256 hopGain = exchanges.outputAmount();
        uint256 totalRewards = routes.length * hopGain - 200e18;
        BancorArbitrage.Rewards memory rewards = bancorArbitrage.rewards();
        uint256 expectedUserGain = (totalRewards * rewards.percentagePPM) / PPM_RESOLUTION;

        // we sweep tokens at the end, so the 100 arbToken1 and arbToken2 go to the protocol wallet's balance
        // assert that 100 arbToken1 and arbToken2 go to the protocol wallet's balance
        assertEq(balanceAfter1, balanceBefore1 + 100e18);
        assertEq(balanceAfter2, balanceBefore2 + 100e18);
        // assert that user will gain exactly the expected amount
        assertEq(userGain, expectedUserGain);
    }

    /**
     * @dev test that leftover tokens get swept to the protocol wallet
     */
    function testLeftoverTokensGetSweptToProtocolWallet(uint16 platformId, uint256 arbAmount, uint256 fee) public {
        // limit arbAmount to AMOUNT
        vm.assume(arbAmount > 0 && arbAmount < AMOUNT);
        // test exchange ids 1 - 5 (w/o Carbon)
        platformId = uint16(bound(platformId, FIRST_EXCHANGE_ID, 5));
        address[] memory tokensToTrade = new address[](3);
        tokensToTrade[0] = address(arbToken1);
        tokensToTrade[1] = address(arbToken2);
        tokensToTrade[2] = address(TokenLibrary.NATIVE_TOKEN);

        // test with all token combinations
        for (uint256 i = 0; i < 3; ++i) {
            for (uint256 j = 0; j < 3; ++j) {
                for (uint256 k = 0; k < 3; ++k) {
                    if (i == j || i == k || j == k) {
                        continue;
                    }
                    BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(
                        IERC20(tokensToTrade[k]),
                        arbAmount
                    );
                    BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
                        platformId,
                        tokensToTrade[i],
                        tokensToTrade[j],
                        tokensToTrade[k],
                        arbAmount,
                        fee
                    );
                    // set second hop to arbAmount + 200 arb token 1 as input
                    // after the first hop, we have arbAmount + 300 tokens available
                    routes[1].sourceAmount = arbAmount + 200e18;
                    // set third hop to arbAmount + 400 arb token 2 as input
                    // after the second hop, we have arbAmount + 500 tokens available
                    routes[2].sourceAmount = arbAmount + 400e18;

                    if (!isValidTestConfiguration(platformId, routes)) {
                        continue;
                    }

                    // get protocol wallet balances before and after the arbitrage
                    uint256 balanceBefore1 = Token(tokensToTrade[i]).balanceOf(address(protocolWallet));
                    uint256 balanceBefore2 = Token(tokensToTrade[j]).balanceOf(address(protocolWallet));
                    executeArbitrage(flashloans, routes, true);
                    uint256 balanceAfter1 = Token(tokensToTrade[i]).balanceOf(address(protocolWallet));
                    uint256 balanceAfter2 = Token(tokensToTrade[j]).balanceOf(address(protocolWallet));

                    // we sweep tokens at the end, so the 100 arbToken1 and arbToken2 go to the protocol wallet's balance
                    // assert that 100 arbToken1 and arbToken2 go to the protocol wallet's balance
                    assertEq(balanceAfter1, balanceBefore1 + 100e18);
                    assertEq(balanceAfter2, balanceBefore2 + 100e18);
                }
            }
        }
    }

    /**
     * @dev test that arbing on the weth platform should wrap or unwrap the source amount of the native token
     */
    function testTradingOnWethPlatformShouldWrapOrUnwrapTheNativeToken(bool userFunded, bool isNativeToken) public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        Token sourceToken = isNativeToken ? TokenLibrary.NATIVE_TOKEN : Token(address(weth));
        Token targetToken = isNativeToken ? Token(address(weth)) : TokenLibrary.NATIVE_TOKEN;
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.WETH),
            address(sourceToken),
            address(targetToken),
            address(bnt),
            AMOUNT,
            500
        );
        // set third hop to AMOUNT + 200 target tokens as input
        // after the first hop, we have AMOUNT + 300 sourceToken (native token or weth) tokens available
        // this is because when wrapping / unwrapping ETH the token amount is the same
        routes[2].sourceAmount = AMOUNT + 200e18;
        vm.startPrank(user1);
        if (userFunded) {
            Token(address(bnt)).safeApprove(address(bancorArbitrage), AMOUNT);
        }
        vm.stopPrank();
        uint256 userBalanceBefore = bnt.balanceOf(user1);
        uint256 balanceBefore = targetToken.balanceOf(address(protocolWallet));
        // make arb with AMOUNT
        executeArbitrageNoApproval(flashloans, routes, userFunded);
        // get user and arb contract balances
        uint256 userBalanceAfter = bnt.balanceOf(user1);
        uint256 balanceAfter = targetToken.balanceOf(address(protocolWallet));
        uint256 userGain = userBalanceAfter - userBalanceBefore;
        // calculate expected user gain
        uint256 hopGain = exchanges.outputAmount();
        uint256 totalRewards = (routes.length - 1) * hopGain - 100e18; // no hop gain from wrapping / unwrapping
        BancorArbitrage.Rewards memory rewards = bancorArbitrage.rewards();
        uint256 expectedUserGain = (totalRewards * rewards.percentagePPM) / PPM_RESOLUTION;
        // assert that 100 targetTokens (Native token or weth) get swept to the protocol wallet
        assertEq(balanceAfter, balanceBefore + 100e18);
        // assert that user will gain exactly the expected amount
        assertEq(userGain, expectedUserGain);
    }

    /**
     * @dev test arbing on weth platform emits the deposit event when trading ETH -> wETH
     */
    function testTradingOnWethPlatformEmitsDepositEvent() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);

        // if source token is native and target is weth, trading on the WETH platform is equal to a weth deposit
        Token sourceToken = TokenLibrary.NATIVE_TOKEN;
        Token targetToken = Token(address(weth));

        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.WETH),
            address(sourceToken),
            address(targetToken),
            address(bnt),
            AMOUNT,
            500
        );

        uint256 hopGain = exchanges.outputAmount();
        uint256 expectedDepositAmount = AMOUNT + hopGain;

        vm.expectEmit();
        emit Deposit(address(bancorArbitrage), expectedDepositAmount);
        executeArbitrage(flashloans, routes, false);
    }

    /**
     * @dev test arbing on weth platform emits the withdrawal event when trading wETH -> ETH
     */
    function testTradingOnWethPlatformEmitsWithdrawalEvent() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);

        // if source token is weth and target is NATIVE TOKEN, trading on the WETH platform is equal to a weth withdrawal
        Token sourceToken = Token(address(weth));
        Token targetToken = TokenLibrary.NATIVE_TOKEN;

        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.WETH),
            address(sourceToken),
            address(targetToken),
            address(bnt),
            AMOUNT,
            500
        );

        uint256 hopGain = exchanges.outputAmount();
        uint256 expectedDepositAmount = AMOUNT + hopGain;

        vm.expectEmit();
        emit Withdrawal(address(bancorArbitrage), expectedDepositAmount);
        executeArbitrage(flashloans, routes, false);
    }

    /**
     * @dev test setting custom source token which doesn't match the previous target token
     */
    function testShouldRevertArbIfNoTokenBalanceInGivenHop() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        // setting 2nd hop source token to bnt (rather than arbToken1) - bnt balance is 0 at this point
        routes[1].sourceToken = Token(address(bnt));
        // we should send a swap tx with 0 sourceAmount
        vm.expectRevert("Source amount should be > 0");
        executeArbitrage(flashloans, routes, false);
    }

    /**
     * @dev test that arb attempt with 0 amount should revert
     */
    function testShouldRevertArbWithZeroAmount(bool userFunded) public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, 0);
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectRevert(ZeroValue.selector);
        executeArbitrageNoApproval(flashloans, routes, userFunded);
    }

    function testShouldRevertETHUserArbIfNotEnoughETHSent() public {
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.BANCOR_V2),
            address(arbToken1),
            address(arbToken2),
            address(TokenLibrary.NATIVE_TOKEN),
            AMOUNT,
            500
        );
        vm.expectRevert(BancorArbitrage.InvalidETHAmountSent.selector);
        bancorArbitrage.fundAndArb{ value: AMOUNT - 1 }(routes, TokenLibrary.NATIVE_TOKEN, AMOUNT);
    }

    function testShouldRevertNonETHUserArbIfETHIsSent() public {
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.BANCOR_V2),
            address(TokenLibrary.NATIVE_TOKEN),
            address(arbToken2),
            address(arbToken1),
            AMOUNT,
            500
        );
        vm.expectRevert(BancorArbitrage.InvalidETHAmountSent.selector);
        bancorArbitrage.fundAndArb{ value: 1 }(routes, Token(address(arbToken1)), AMOUNT);
    }

    function testShouldRevertArbWithUserFundsIfTokensHaventBeenApproved(uint256) public {
        BancorArbitrage.TradeRoute[] memory routes = getRoutes();
        vm.expectRevert("ERC20: insufficient allowance");
        bancorArbitrage.fundAndArb(routes, Token(address(bnt)), AMOUNT);
    }

    /**
     * @dev test that arb attempt on carbon with invalid trade data should revert
     */
    function testShouldRevertArbOnCarbonWithInvalidData(bytes memory data) public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.CARBON_FORK),
            address(arbToken1),
            address(arbToken2),
            address(bnt),
            AMOUNT,
            500
        );
        routes[1].customData = data;
        vm.expectRevert();
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test that trade by target arb attempt on carbon reverts if source amount is greater than max input
     */
    function testShouldRevertArbOnCarbonIfGreaterThanMaxInput() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCarbon(
            address(arbToken1),
            address(arbToken2),
            AMOUNT,
            3,
            true
        );
        // minTargetAmount is used for maxInput if tradeByTarget is true
        routes[1].minTargetAmount = AMOUNT / 2;
        vm.expectRevert(MockExchanges.GreaterThanMaxInput.selector);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test that arb attempt on carbon with invalid trade data should revert
     */
    function testShouldRevertArbOnCarbonWithLargerThanUint128TargetAmount() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.CARBON_FORK),
            address(arbToken1),
            address(arbToken2),
            address(bnt),
            AMOUNT,
            500
        );
        routes[1].minTargetAmount = 2 ** 128;
        vm.expectRevert(BancorArbitrage.MinTargetAmountTooHigh.selector);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test that arb attempt on carbon pol with invalid trade data should revert
     */
    function testShouldRevertArbOnCarbonPOLWithLargerThanUint128SourceAmount() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.CARBON_POL),
            address(TokenLibrary.NATIVE_TOKEN),
            address(arbToken2),
            address(bnt),
            AMOUNT,
            500
        );
        // transfer enough eth in order to hit the source amount check
        vm.deal(address(bancorArbitrage), 2 ** 128);
        routes[1].sourceAmount = 2 ** 128;
        vm.expectRevert(BancorArbitrage.SourceAmountTooHigh.selector);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test that arb attempt on carbon pol if min target amount is not reached
     */
    function testShouldRevertArbOnCarbonPOLIfMinTargetAmountIsNotReached() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.CARBON_POL),
            address(TokenLibrary.NATIVE_TOKEN),
            address(arbToken2),
            address(bnt),
            AMOUNT,
            500
        );
        routes[1].minTargetAmount = 2 ** 128;
        vm.expectRevert(BancorArbitrage.MinTargetAmountNotReached.selector);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test that arb attempt on carbon pol reverts if the source token isn't ETH or BNT
     */
    function testShouldRevertArbOnCarbonPOLIfSourceTokenIsntETHOrBNT() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.CARBON_POL),
            address(arbToken1), // carbon pol source token
            address(arbToken2), // carbon pol target token
            address(bnt),
            AMOUNT,
            500
        );
        vm.expectRevert(BancorArbitrage.InvalidCarbonPOLTrade.selector);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test that arb attempt on carbon pol reverts if the source token is BNT and target isn't ETH
     */
    function testShouldRevertArbOnCarbonPOLIfSourceTokenIsBNTAndTargetIsntETH() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(arbToken1, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.CARBON_POL),
            address(bnt), // carbon pol source token
            address(arbToken2), // carbon pol target token
            address(arbToken1),
            AMOUNT,
            500
        );
        vm.expectRevert(BancorArbitrage.InvalidCarbonPOLTrade.selector);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test that arb attempt on curve with invalid pool address should revert
     */
    function testShouldRevertArbOnCurveIfNoPoolAddressIsPassedIn() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.CURVE),
            address(arbToken1),
            address(arbToken2),
            address(bnt),
            AMOUNT,
            500
        );
        // set curve tokens, pool address and token indices
        setCurveTokens(routes);
        // set custom address to 0
        routes[1].customAddress = address(0);
        vm.expectRevert(BancorArbitrage.InvalidCurvePool.selector);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test that arb attempt on WETH with invalid trade data should revert
     */
    function testShouldRevertArbOnPlaftormWETHWithNonETHorWETHAsSourceToken() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.WETH),
            address(arbToken1),
            address(TokenLibrary.NATIVE_TOKEN),
            address(bnt),
            AMOUNT,
            500
        );
        vm.expectRevert(BancorArbitrage.InvalidWethTrade.selector);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test that arb attempt on WETH with invalid trade data should revert
     */
    function testShouldRevertArbOnPlaftormWETHWithNonETHorWETHAsTargetToken() public {
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.WETH),
            address(TokenLibrary.NATIVE_TOKEN),
            address(arbToken2),
            address(bnt),
            AMOUNT,
            500
        );
        vm.expectRevert(BancorArbitrage.InvalidWethTrade.selector);
        bancorArbitrage.flashloanAndArbV2(flashloans, routes);
    }

    /**
     * @dev test that arb attempt with user funds should revert if reentrancy is attempted
     */
    function testShouldRevertArbWithUserFundsIfReentrancyIsAttempted() public {
        vm.startPrank(user1);
        TestReentrancy testReentrancy = new TestReentrancy(bancorArbitrage);
        // transfer tokens to test reentrancy
        arbToken1.transfer(address(testReentrancy), AMOUNT);
        // approve tokens
        testReentrancy.approveTokens(Token(address(arbToken1)), AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.BANCOR_V2),
            address(arbToken1),
            address(arbToken2),
            address(TokenLibrary.NATIVE_TOKEN),
            AMOUNT,
            500
        );
        // reverts in "unsafeTransfer" in fundAndArb - which uses OZ's Address "sendValue" function
        vm.expectRevert("Address: unable to send value, recipient may have reverted");
        testReentrancy.tryReenterFundAndArb{ value: AMOUNT }(routes, Token(address(TokenLibrary.NATIVE_TOKEN)), AMOUNT);
        vm.stopPrank();
    }

    /**
     * @dev test that arb attempt with user funds should revert if reentrancy is attempted via a malicious token
     */
    function testShouldRevertArbWithUserFundsIfReentrancyIsAttemptedViaMaliciousToken() public {
        vm.startPrank(user1);
        TestReentrancy testReentrancy = new TestReentrancy(bancorArbitrage);
        // deploy malicious token
        TestReentrantToken reentrantToken = new TestReentrantToken(
            "TKN1",
            "TKN1",
            1_000_000_000 ether,
            bancorArbitrage
        );
        // set pool collection
        exchanges.setCollectionByPool(Token(address(reentrantToken)));
        // transfer tokens to test reentrancy
        reentrantToken.standardTransfer(address(testReentrancy), AMOUNT);
        // approve tokens
        testReentrancy.approveTokens(Token(address(reentrantToken)), AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.BANCOR_V2),
            address(arbToken1),
            address(arbToken2),
            address(reentrantToken),
            AMOUNT,
            500
        );
        // reverts in the "safeTransferFrom" call in fundAndArb
        vm.expectRevert("ReentrancyGuard: reentrant call");
        testReentrancy.tryReenterFundAndArb(routes, Token(address(reentrantToken)), AMOUNT);
        vm.stopPrank();
    }

    /**
     * @dev test that flashloan arb attempt should revert if reentrancy is attempted via a malicious token
     */
    function testShouldRevertFlashloanArbIfReentrancyIsAttemptedViaMaliciousToken() public {
        vm.startPrank(user1);
        TestReentrancy testReentrancy = new TestReentrancy(bancorArbitrage);
        // deploy malicious token
        TestReentrantToken reentrantToken = new TestReentrantToken(
            "TKN1",
            "TKN1",
            1_000_000_000 ether,
            bancorArbitrage
        );
        // set pool collection
        exchanges.setCollectionByPool(Token(address(reentrantToken)));
        // transfer tokens to exchange to test reentrancy
        reentrantToken.standardTransfer(address(exchanges), AMOUNT * 2);
        // flashloan bnt
        BancorArbitrage.Flashloan[] memory flashloans = getSingleTokenFlashloanDataForV3(bnt, AMOUNT);
        BancorArbitrage.TradeRoute[] memory routes = getRoutesCustomTokens(
            uint16(PlatformId.BANCOR_V2),
            address(reentrantToken),
            address(arbToken2),
            address(bnt),
            AMOUNT,
            500
        );
        // reverts in the "safeTransfer" call when the reentrantTokens get sent from the exchange to bancorArbitrage
        // token transfer function is overriden to attempt re-entry in flashloanAndArbV2
        vm.expectRevert("ReentrancyGuard: reentrant call");
        testReentrancy.tryReenterFlashloanAndArbV2(flashloans, routes);
        vm.stopPrank();
    }

    /**
     * @dev get 3 routes for arb testing
     */
    function getRoutes() public view returns (BancorArbitrage.TradeRoute[] memory routes) {
        routes = new BancorArbitrage.TradeRoute[](3);

        routes[0] = BancorArbitrage.TradeRoute({
            platformId: uint16(PlatformId.BANCOR_V2),
            sourceToken: Token(address(bnt)),
            targetToken: Token(address(arbToken1)),
            sourceAmount: 0,
            minTargetAmount: 1,
            deadline: DEADLINE,
            customAddress: address(arbToken1),
            customInt: 0,
            customData: ""
        });

        routes[1] = BancorArbitrage.TradeRoute({
            platformId: uint16(PlatformId.SUSHISWAP),
            sourceToken: Token(address(arbToken1)),
            targetToken: Token(address(arbToken2)),
            sourceAmount: 0,
            minTargetAmount: 1,
            deadline: DEADLINE,
            customAddress: address(exchanges),
            customInt: 0,
            customData: ""
        });

        routes[2] = BancorArbitrage.TradeRoute({
            platformId: uint16(PlatformId.BANCOR_V2),
            sourceToken: Token(address(arbToken2)),
            targetToken: Token(address(bnt)),
            sourceAmount: 0,
            minTargetAmount: 1,
            deadline: DEADLINE,
            customAddress: address(bnt),
            customInt: 0,
            customData: ""
        });
        return routes;
    }

    /**
     * @dev get 3 routes for arb testing with custom tokens and 2nd exchange id
     * @param platformId - which exchange to use for middle swap
     * @param token1 - first swapped token
     * @param token2 - second swapped token
     * @param flashloanToken - flashloan token
     * @param arbAmount - initial arb amount
     * @param fee - Uni V3 fee, can be 100, 500 or 3000
     */
    function getRoutesCustomTokens(
        uint16 platformId,
        address token1,
        address token2,
        address flashloanToken,
        uint256 arbAmount,
        uint256 fee
    ) public view returns (BancorArbitrage.TradeRoute[] memory routes) {
        routes = new BancorArbitrage.TradeRoute[](3);

        uint256 customFee = 0;
        // custom address should be the exchange address for all uni v2/v3 and carbon forks
        address customAddress = address(exchanges);
        uint256 hopGain = exchanges.outputAmount();
        // add custom fee bps for pancake / uni v3 - 100, 500 or 3000
        if (platformId == uint16(PlatformId.UNISWAP_V3_FORK)) {
            uint16[3] memory fees = [100, 500, 3000];
            // get a random fee on each run
            uint256 feeIndex = bound(fee, 0, 2);
            // use 100, 500 or 3000
            customFee = fees[feeIndex];
            // set customAddress to proper Uni V3 router
            customAddress = address(exchanges);
        }
        if (platformId == uint16(PlatformId.UNISWAP_V2_FORK) || platformId == uint16(PlatformId.SUSHISWAP)) {
            customAddress = address(exchanges);
        }
        bytes memory data = "";
        // add custom data for carbon
        if (platformId == uint16(PlatformId.CARBON_FORK)) {
            TradeAction[] memory tradeActions = new TradeAction[](1);
            tradeActions[0] = TradeAction({ strategyId: 0, amount: uint128(AMOUNT + 300 ether) });
            data = abi.encode(tradeActions);
        }

        routes[0] = BancorArbitrage.TradeRoute({
            platformId: uint16(PlatformId.BANCOR_V2),
            sourceToken: Token(flashloanToken),
            targetToken: Token(token1),
            sourceAmount: arbAmount,
            minTargetAmount: 1,
            deadline: DEADLINE,
            customAddress: token1,
            customInt: 0,
            customData: ""
        });

        routes[1] = BancorArbitrage.TradeRoute({
            platformId: platformId,
            sourceToken: Token(token1),
            targetToken: Token(token2),
            sourceAmount: arbAmount + hopGain,
            minTargetAmount: 1,
            deadline: DEADLINE,
            customAddress: customAddress,
            customInt: customFee,
            customData: data
        });

        routes[2] = BancorArbitrage.TradeRoute({
            platformId: uint16(PlatformId.BANCOR_V2),
            sourceToken: Token(token2),
            targetToken: Token(flashloanToken),
            sourceAmount: arbAmount + hopGain * 2,
            minTargetAmount: 1,
            deadline: DEADLINE,
            customAddress: flashloanToken,
            customInt: 0,
            customData: ""
        });
        return routes;
    }

    /**
     * @dev get several routes for arb testing with custom route length
     * @param routeLength - how many routes to generate
     * @param platformId - which exchange to perform swaps on
     * @param fee - Uni V3 fee, can be 100, 500 or 3000
     * @param arbAmount - initial arb amount
     */
    function getRoutesCustomLength(
        uint256 routeLength,
        uint16 platformId,
        uint256 fee,
        uint256 arbAmount
    ) public view returns (BancorArbitrage.TradeRoute[] memory routes) {
        routes = new BancorArbitrage.TradeRoute[](routeLength);

        uint256 customFee = 0;
        // custom address should be the exchange for all uni v2/v3 and carbon forks
        address customAddress = address(exchanges);
        // add custom fee bps for pancake / uni v3 - 100, 500 or 3000
        if (platformId == uint16(PlatformId.UNISWAP_V3_FORK)) {
            uint16[3] memory fees = [100, 500, 3000];
            // get a random fee on each run
            uint256 feeIndex = bound(fee, 0, 2);
            // use 100, 500 or 3000
            customFee = fees[feeIndex];
        }
        bytes memory data = "";
        uint256 currentAmount = arbAmount;
        uint256 hopGain = exchanges.outputAmount();

        address sourceToken = address(bnt);
        address targetToken = address(arbToken1);

        // generate route for trading
        for (uint256 i = 0; i < routeLength; ++i) {
            if (i % 3 == 0) {
                targetToken = address(arbToken1);
            } else if (i % 3 == 1) {
                targetToken = address(arbToken2);
            } else {
                targetToken = address(TokenLibrary.NATIVE_TOKEN);
            }
            data = getCarbonData(currentAmount);
            routes[i] = BancorArbitrage.TradeRoute({
                platformId: platformId,
                sourceToken: Token(sourceToken),
                targetToken: Token(targetToken),
                sourceAmount: currentAmount,
                minTargetAmount: 1,
                deadline: DEADLINE,
                customAddress: customAddress,
                customInt: customFee,
                customData: data
            });
            currentAmount += hopGain;
            sourceToken = targetToken;
        }
        // last token should be BNT
        routes[routeLength - 1].targetToken = Token(address(bnt));
        return routes;
    }

    /**
     * @dev get 3 routes for arb testing with custom tokens and 2nd exchange = carbon
     * @param token1 - first swapped token
     * @param token2 - second swapped token
     * @param tradeActionCount - count of individual trade actions passed to carbon trade
     * @param byTargetAmount - true if trade is by target amount
     */
    function getRoutesCarbon(
        address token1,
        address token2,
        uint256 arbAmount,
        uint256 tradeActionCount,
        bool byTargetAmount
    ) public view returns (BancorArbitrage.TradeRoute[] memory routes) {
        routes = new BancorArbitrage.TradeRoute[](3);

        // custom address should be the exchange for all carbon forks
        address customAddress = address(exchanges);

        uint256 hopGain = exchanges.outputAmount();
        // generate from 1 to 11 actions
        // each action will trade `amount / tradeActionCount`
        tradeActionCount = bound(tradeActionCount, 1, 11);
        TradeAction[] memory tradeActions = new TradeAction[](tradeActionCount + 1);
        // source amount at the point of carbon trade is arbAmount + hopGain = arbAmount + 300
        // target amount is arbAmount + 2 * hopGain = arbAmount + 600
        uint256 totalAmount = byTargetAmount ? arbAmount + hopGain * 2 : arbAmount + hopGain;
        // set the individual action values
        for (uint256 i = 1; i <= tradeActionCount; ++i) {
            tradeActions[i] = TradeAction({ strategyId: i, amount: uint128(totalAmount / tradeActionCount) });
        }
        // add remainder of the division to the last trade action
        // goal is for strategies sum to be exactly equal to the total amount
        tradeActions[tradeActionCount].amount += uint128(totalAmount % tradeActionCount);
        bytes memory customData = abi.encode(tradeActions);

        // encode trade by target flag (if the LSB of customInt is set to 1, we trade by target on Carbon)
        uint256 customInt = 0;
        if (byTargetAmount) {
            customInt = customInt | 1;
        }

        // set min target amount / max input depending on the `byTargetAmount` flag
        uint256 minTargetAmount = byTargetAmount ? totalAmount - hopGain : 1;

        routes[0] = BancorArbitrage.TradeRoute({
            platformId: uint16(PlatformId.BANCOR_V2),
            sourceToken: Token(address(bnt)),
            targetToken: Token(token1),
            sourceAmount: arbAmount,
            minTargetAmount: 1,
            deadline: DEADLINE,
            customAddress: token1,
            customInt: 0,
            customData: ""
        });

        routes[1] = BancorArbitrage.TradeRoute({
            platformId: uint16(PlatformId.CARBON_FORK),
            sourceToken: Token(token1),
            targetToken: Token(token2),
            sourceAmount: totalAmount,
            minTargetAmount: minTargetAmount,
            deadline: DEADLINE,
            customAddress: customAddress,
            customInt: customInt,
            customData: customData
        });

        routes[2] = BancorArbitrage.TradeRoute({
            platformId: uint16(PlatformId.BANCOR_V2),
            sourceToken: Token(token2),
            targetToken: Token(address(bnt)),
            sourceAmount: arbAmount + hopGain * 2,
            minTargetAmount: 1,
            deadline: DEADLINE,
            customAddress: address(bnt),
            customInt: 0,
            customData: ""
        });
        return routes;
    }

    /**
     * @dev get several routes for multiple flashloan arb testing
     * @dev 3 routes for each arb with path flashloanToken -> token1 -> token2 -> flashloanToken
     * @param platformId - which exchange to use for middle swap
     * @param flashloanToken1 - first flashloan token to be withdrawn
     * @param flashloanToken2 - second flashloan token to be withdrawn
     * @param flashloanToken3 - third flashloan token to be withdrawn
     * @param tokens - intermediary tokens
     * @param arbAmount - initial arb amount
     * @param fee - Uni V3 fee, can be 100, 500 or 3000
     */
    function getRoutesCustomTokensMultipleFlashloans(
        uint16 platformId,
        address flashloanToken1,
        address flashloanToken2,
        address flashloanToken3,
        address[] memory tokens,
        uint256 arbAmount,
        uint256 fee
    ) public view returns (BancorArbitrage.TradeRoute[] memory routes) {
        routes = new BancorArbitrage.TradeRoute[](9);

        BancorArbitrage.TradeRoute[] memory firstArbRoutes = getRoutesCustomTokens(
            uint16(platformId),
            tokens[0],
            tokens[1],
            flashloanToken1,
            arbAmount,
            fee
        );
        BancorArbitrage.TradeRoute[] memory secondArbRoutes = getRoutesCustomTokens(
            uint16(platformId),
            tokens[2],
            tokens[3],
            flashloanToken2,
            arbAmount,
            fee
        );
        BancorArbitrage.TradeRoute[] memory thirdArbRoutes = getRoutesCustomTokens(
            uint16(platformId),
            tokens[4],
            tokens[5],
            flashloanToken3,
            arbAmount,
            fee
        );
        uint256 currIndex = 0;
        // fill in the routes
        for (uint256 i = 0; i < 3; ++i) {
            routes[currIndex] = firstArbRoutes[i];
            routes[currIndex + 3] = secondArbRoutes[i];
            routes[currIndex + 6] = thirdArbRoutes[i];
            currIndex++;
        }
        return routes;
    }

    /**
     * @dev convert route for uni v3 native token arb testing by wrapping eth on WETH platform
     */
    function convertUniV3NativeTokenRouteWrap(
        BancorArbitrage.TradeRoute[] memory routes
    ) public view returns (BancorArbitrage.TradeRoute[] memory updatedRoutes) {
        uint256 hopGain = exchanges.outputAmount();
        // new arb route is bnt -> eth -> weth -> arbToken2 -> bnt
        updatedRoutes = new BancorArbitrage.TradeRoute[](4);
        updatedRoutes[0] = routes[0];
        updatedRoutes[1] = BancorArbitrage.TradeRoute({
            platformId: uint16(PlatformId.WETH),
            sourceToken: TokenLibrary.NATIVE_TOKEN,
            targetToken: Token(address(weth)),
            sourceAmount: routes[0].sourceAmount + hopGain,
            minTargetAmount: 0,
            deadline: DEADLINE,
            customAddress: address(0),
            customInt: 0,
            customData: ""
        });
        updatedRoutes[2] = routes[1];
        updatedRoutes[2].sourceToken = Token(address(weth));
        updatedRoutes[3] = routes[2];

        return updatedRoutes;
    }

    /**
     * @dev convert route for uni v3 native token arb testing by unwrapping weth on WETH platform
     */
    function convertUniV3NativeTokenRouteUnwrap(
        BancorArbitrage.TradeRoute[] memory routes
    ) public view returns (BancorArbitrage.TradeRoute[] memory updatedRoutes) {
        uint256 hopGain = exchanges.outputAmount();
        // new arb route is bnt -> eth -> weth -> arbToken2 -> bnt
        updatedRoutes = new BancorArbitrage.TradeRoute[](4);
        updatedRoutes[0] = routes[0];
        updatedRoutes[1] = routes[1];
        updatedRoutes[1].targetToken = Token(address(weth));
        updatedRoutes[2] = BancorArbitrage.TradeRoute({
            platformId: uint16(PlatformId.WETH),
            sourceToken: Token(address(weth)),
            targetToken: TokenLibrary.NATIVE_TOKEN,
            sourceAmount: routes[1].sourceAmount + hopGain * 2,
            minTargetAmount: 0,
            deadline: DEADLINE,
            customAddress: address(0),
            customInt: 0,
            customData: ""
        });
        updatedRoutes[3] = routes[2];
        updatedRoutes[3].sourceToken = TokenLibrary.NATIVE_TOKEN;

        return updatedRoutes;
    }

    /**
     * @dev get custom data for trading on Carbon
     * @param amount the amount to be traded
     * @return data the encoded trading data
     */
    function getCarbonData(uint256 amount) public pure returns (bytes memory data) {
        TradeAction[] memory tradeActions = new TradeAction[](1);
        tradeActions[0] = TradeAction({ strategyId: 0, amount: uint128(amount) });
        data = abi.encode(tradeActions);
    }

    /**
     * @dev get flashloan data for Balancer flashloans
     * @dev one flashloan is taken for all tokens provided
     * @param sourceTokens the source tokens to be withdrawn
     * @param sourceAmounts the source amounts
     */
    function getFlashloanDataForBalancer(
        IERC20[] memory sourceTokens,
        uint256[] memory sourceAmounts
    ) public pure returns (BancorArbitrage.Flashloan[] memory flashloans) {
        // solhint-disable-next-line custom-errors
        require(sourceTokens.length == sourceAmounts.length, "Invalid flashloan data provided");
        flashloans = new BancorArbitrage.Flashloan[](1);
        flashloans[0] = BancorArbitrage.Flashloan({
            platformId: uint16(PlatformId.BALANCER),
            sourceTokens: sourceTokens,
            sourceAmounts: sourceAmounts
        });
        return flashloans;
    }

    /**
     * @dev get flashloan data for Bancor V3 flashloans
     * @dev each flashloan is taken separarately
     * @param sourceTokens the source tokens to be withdrawn
     * @param sourceAmounts the source amounts
     */
    function getFlashloanDataForV3(
        IERC20[] memory sourceTokens,
        uint256[] memory sourceAmounts
    ) public pure returns (BancorArbitrage.Flashloan[] memory flashloans) {
        // solhint-disable-next-line custom-errors
        require(sourceTokens.length == sourceAmounts.length, "Invalid flashloan data provided");
        uint256 len = sourceTokens.length;
        flashloans = new BancorArbitrage.Flashloan[](len);
        for (uint256 i = 0; i < len; ++i) {
            IERC20[] memory _sourceTokens = new IERC20[](1);
            uint256[] memory _sourceAmounts = new uint256[](1);
            _sourceTokens[0] = sourceTokens[i];
            _sourceAmounts[0] = sourceAmounts[i];
            flashloans[i] = BancorArbitrage.Flashloan({
                platformId: uint16(PlatformId.BANCOR_V3),
                sourceTokens: _sourceTokens,
                sourceAmounts: _sourceAmounts
            });
        }
        return flashloans;
    }

    /**
     * @dev get flashloan data for Bancor V3 flashloans
     * @dev only one token flashloan
     * @param sourceToken the source token to be withdrawn
     * @param sourceAmount the source amount
     */
    function getSingleTokenFlashloanDataForV3(
        IERC20 sourceToken,
        uint256 sourceAmount
    ) public pure returns (BancorArbitrage.Flashloan[] memory flashloans) {
        flashloans = new BancorArbitrage.Flashloan[](1);
        IERC20[] memory sourceTokens = new IERC20[](1);
        uint256[] memory sourceAmounts = new uint256[](1);
        sourceTokens[0] = sourceToken;
        sourceAmounts[0] = sourceAmount;
        flashloans[0] = BancorArbitrage.Flashloan({
            platformId: uint16(PlatformId.BANCOR_V3),
            sourceTokens: sourceTokens,
            sourceAmounts: sourceAmounts
        });
        return flashloans;
    }

    /**
     * @dev get combined flashloan data for balancer and bancor v3
     * @dev order is: Balancer flashloan first, then Bancor V3 flashloans
     */
    function getCombinedFlashloanData(
        IERC20[] memory sourceTokensBalancer,
        uint256[] memory sourceAmountsBalancer,
        IERC20[] memory sourceTokensBancorV3,
        uint256[] memory sourceAmountsBancorV3
    ) private pure returns (BancorArbitrage.Flashloan[] memory flashloans) {
        // total length is equal to bancor v3 source tokens (each token is a separate flashloan) + 1 for balancer
        uint256 totalFlashloansLength = sourceTokensBancorV3.length + 1;
        flashloans = new BancorArbitrage.Flashloan[](totalFlashloansLength);
        BancorArbitrage.Flashloan[] memory flashloansBalancer = getFlashloanDataForBalancer(
            sourceTokensBalancer,
            sourceAmountsBalancer
        );
        BancorArbitrage.Flashloan[] memory flashloansBancor = getFlashloanDataForV3(
            sourceTokensBancorV3,
            sourceAmountsBancorV3
        );
        flashloans[0] = flashloansBalancer[0];
        for (uint256 i = 1; i < totalFlashloansLength; ++i) {
            flashloans[i] = flashloansBancor[i - 1];
        }
        return flashloans;
    }

    /**
     * @dev get 2 flashloans - one from bancor v3 with one token, one from balancer with two tokens
     * @dev used to workaround stack too deep resulting from getCombinedFlashloanData
     */
    function getCombinedFlashloanDataForSeveralTokens(
        address sourceTokenBancorV3,
        uint256 sourceAmountBancorV3,
        address sourceToken1Balancer,
        uint256 sourceAmount1Balancer,
        address sourceToken2Balancer,
        uint256 sourceAmount2Balancer
    ) private pure returns (BancorArbitrage.Flashloan[] memory flashloans) {
        IERC20[] memory tokensBancorV3 = new IERC20[](1);
        uint256[] memory amountsBancorV3 = new uint256[](1);
        IERC20[] memory tokensBalancer = new IERC20[](2);
        uint256[] memory amountsBalancer = new uint256[](2);
        tokensBancorV3[0] = IERC20(sourceTokenBancorV3);
        amountsBancorV3[0] = sourceAmountBancorV3;
        tokensBalancer[0] = IERC20(sourceToken1Balancer);
        amountsBalancer[0] = sourceAmount1Balancer;
        tokensBalancer[1] = IERC20(sourceToken2Balancer);
        amountsBalancer[1] = sourceAmount2Balancer;

        flashloans = getCombinedFlashloanData(tokensBalancer, amountsBalancer, tokensBancorV3, amountsBancorV3);
    }

    /**
     * @dev build arb path from TradeRoute array
     */
    function buildArbPath(
        BancorArbitrage.TradeRoute[] memory routes
    ) private pure returns (uint16[] memory exchangeIds, address[] memory path) {
        exchangeIds = new uint16[](routes.length);
        path = new address[](routes.length * 2);
        for (uint256 i = 0; i < routes.length; ++i) {
            exchangeIds[i] = routes[i].platformId;
            path[i * 2] = address(routes[i].sourceToken);
            path[(i * 2) + 1] = address(routes[i].targetToken);
        }
    }

    /**
     * @dev execute user-funded or flashloan arb
     * @dev user-funded arb gets approved before execution
     */
    function executeArbitrage(
        BancorArbitrage.Flashloan[] memory flashloans,
        BancorArbitrage.TradeRoute[] memory routes,
        bool userFunded
    ) public {
        vm.startPrank(user1);
        if (userFunded) {
            uint256 sourceAmount = flashloans[0].sourceAmounts[0];
            Token token = Token(address(flashloans[0].sourceTokens[0]));
            token.safeIncreaseAllowance(address(bancorArbitrage), sourceAmount);
            uint256 val = token.isNative() ? sourceAmount : 0;
            bancorArbitrage.fundAndArb{ value: val }(routes, token, sourceAmount);
        } else {
            bancorArbitrage.flashloanAndArbV2(flashloans, routes);
        }
        vm.stopPrank();
    }

    /**
     * @dev execute user-funded or flashloan arb
     * @dev no approvals for token if user-funded
     */
    function executeArbitrageNoApproval(
        BancorArbitrage.Flashloan[] memory flashloans,
        BancorArbitrage.TradeRoute[] memory routes,
        bool userFunded
    ) public {
        vm.startPrank(user1);
        if (userFunded) {
            uint256 sourceAmount = flashloans[0].sourceAmounts[0];
            Token token = Token(address(flashloans[0].sourceTokens[0]));
            uint256 val = token.isNative() ? sourceAmount : 0;
            bancorArbitrage.fundAndArb{ value: val }(routes, token, sourceAmount);
        } else {
            bancorArbitrage.flashloanAndArbV2(flashloans, routes);
        }
        vm.stopPrank();
    }

    function calculateExpectedUserRewardsAndProtocolAmounts()
        private
        view
        returns (uint256[] memory, uint256[] memory)
    {
        // each hop through the route from MockExchanges adds 300e18 tokens to the output
        // so 3 hops = 3 * 300e18 = 900 tokens more than start
        // so with 0 flashloan fees, when we repay the flashloan, we have 900 tokens as totalRewards
        uint256 hopCount = 3;
        uint256 totalRewards = 300e18 * hopCount;

        BancorArbitrage.Rewards memory rewards = bancorArbitrage.rewards();

        uint256[] memory expectedUserRewards = new uint256[](1);
        uint256[] memory expectedProtocolAmounts = new uint256[](1);
        expectedUserRewards[0] = (totalRewards * rewards.percentagePPM) / PPM_RESOLUTION;
        expectedProtocolAmounts[0] = totalRewards - expectedUserRewards[0];
        return (expectedUserRewards, expectedProtocolAmounts);
    }

    function calculateExpectedUserRewardsAndProtocolAmountsMultipleFlashloans(
        uint256 tokenCount
    ) private view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory expectedUserRewards = new uint256[](tokenCount);
        uint256[] memory expectedProtocolAmounts = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; ++i) {
            (
                uint256[] memory rewards,
                uint256[] memory protocolAmounts
            ) = calculateExpectedUserRewardsAndProtocolAmounts();
            expectedUserRewards[i] = rewards[0];
            expectedProtocolAmounts[i] = protocolAmounts[0];
        }
        return (expectedUserRewards, expectedProtocolAmounts);
    }

    /**
     * @dev get platforms struct for initialization of bancor arbitrage
     */
    function getPlatformStruct(
        address _exchanges,
        address _balancerVault
    ) public pure returns (BancorArbitrage.Platforms memory platformList) {
        platformList = BancorArbitrage.Platforms({
            bancorNetworkV2: IBancorNetworkV2(_exchanges),
            bancorNetworkV3: IBancorNetwork(_exchanges),
            uniV2Router: IUniswapV2Router02(_exchanges),
            uniV3Router: ISwapRouter(_exchanges),
            sushiswapRouter: IUniswapV2Router02(_exchanges),
            carbonController: ICarbonController(_exchanges),
            balancerVault: IBalancerVault(_balancerVault),
            carbonPOL: ICarbonPOL(_exchanges)
        });
    }

    /**
     * @dev mofidy target token in an arb route
     */
    function modifyRouteTargetToken(BancorArbitrage.TradeRoute memory route, address token) public pure {
        route.targetToken = Token(token);
        route.customAddress = token;
    }

    /**
     * @dev validate the routes sent are a valid test configuration
     * @dev necessary for some exchanges which don't accept some input or output tokens
     */
    function isValidTestConfiguration(
        uint16 platformId,
        BancorArbitrage.TradeRoute[] memory routes
    ) private pure returns (bool) {
        if (PlatformId(platformId) == PlatformId.CARBON_POL) {
            if (!routes[1].sourceToken.isNative() || routes[1].targetToken.isNative()) {
                return false;
            }
        }
        // Uniswap V3 doesn't accept the native token as source or target
        for (uint256 i = 0; i < routes.length; ++i) {
            if (PlatformId(platformId) == PlatformId.UNISWAP_V3_FORK) {
                if (routes[i].sourceToken.isNative() || routes[i].targetToken.isNative()) {
                    return false;
                }
            }
        }
        return true;
    }

    function setCurveTokens(BancorArbitrage.TradeRoute[] memory routes) private {
        for (uint256 i = 0; i < routes.length; i++) {
            if (PlatformId(routes[i].platformId) == PlatformId.CURVE) {
                uint256 sourceTokenIndex = i * 2 + 0;
                uint256 targetTokenIndex = i * 2 + 1;
                exchanges.setCurveToken(int128(int256(sourceTokenIndex)), routes[i].sourceToken);
                exchanges.setCurveToken(int128(int256(targetTokenIndex)), routes[i].targetToken);
                routes[i].customInt = sourceTokenIndex | (targetTokenIndex << 128);
                routes[i].customAddress = address(exchanges);
            }
        }
    }
}
