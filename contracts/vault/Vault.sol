// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { Upgradeable } from "../utility/Upgradeable.sol";
import { Token } from "../token/Token.sol";
import { TokenLibrary } from "../token/TokenLibrary.sol";

import { Utils, AccessDenied } from "../utility/Utils.sol";

contract Vault is ReentrancyGuardUpgradeable, Utils, Upgradeable {
    using Address for address payable;
    using SafeERC20 for IERC20;
    using TokenLibrary for Token;

    // the asset manager role is required to access all the funds
    bytes32 private constant ROLE_ASSET_MANAGER = keccak256("ROLE_ASSET_MANAGER");

    // upgrade forward-compatibility storage gap
    uint256[MAX_GAP] private __gap;

    /**
     * @dev triggered when tokens have been withdrawn from the vault
     */
    event FundsWithdrawn(Token indexed token, address indexed caller, address indexed target, uint256 amount);

    /**
     * @dev used to initialize the implementation
     */
    constructor() {
        initialize();
    }

    /**
     * @dev fully initializes the contract and its parents
     */
    function initialize() public initializer {
        __Vault_init();
    }

    // solhint-disable func-name-mixedcase

    /**
     * @dev initializes the contract and its parents
     */
    function __Vault_init() internal onlyInitializing {
        __Upgradeable_init();
        __ReentrancyGuard_init();

        __Vault_init_unchained();
    }

    /**
     * @dev performs contract-specific initialization
     */
    function __Vault_init_unchained() internal onlyInitializing {
        _setRoleAdmin(ROLE_ASSET_MANAGER, ROLE_ADMIN);
    }

    // solhint-enable func-name-mixedcase

    /**
     * @dev authorize the contract to receive the native token
     */
    receive() external payable {}

    /**
     * @inheritdoc Upgradeable
     */
    function version() public pure override(Upgradeable) returns (uint16) {
        return 1;
    }

    /**
     * @dev returns the asset manager role
     */
    function roleAssetManager() external pure returns (bytes32) {
        return ROLE_ASSET_MANAGER;
    }

    /**
     * @dev withdraws funds held by the contract and sends them to an account
     */
    function withdrawFunds(
        Token token,
        address payable target,
        uint256 amount
    ) external validAddress(target) nonReentrant whenAuthorized(msg.sender) {
        if (amount == 0) {
            return;
        }

        // safe due to nonReentrant modifier (forwards all available gas in case of ETH)
        token.unsafeTransfer(target, amount);

        emit FundsWithdrawn({ token: token, caller: msg.sender, target: target, amount: amount });
    }

    /**
     * @dev allows execution only by an authorized operation
     */
    modifier whenAuthorized(address caller) {
        if (!hasRole(ROLE_ASSET_MANAGER, caller)) {
            revert AccessDenied();
        }

        _;
    }
}
