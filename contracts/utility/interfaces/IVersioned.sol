// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/**
 * @dev an interface for a versioned contract
 */
interface IVersioned {
    function version() external view returns (uint16);
}
