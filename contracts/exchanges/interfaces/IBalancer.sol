// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IAsset as IBalancerAsset } from "@balancer-labs/v2-interfaces/contracts/vault/IAsset.sol";
import { IVault as IBalancerVault } from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import { IFlashLoanRecipient as IBalancerFlashloanRecipient } from "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";

import { IERC20 as IStandardERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20 as IBalancerERC20 } from "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";

function castTokens(IStandardERC20[] memory inputTokens) pure returns (IBalancerERC20[] memory outputTokens) {
    assembly {
        outputTokens := inputTokens
    }
}
