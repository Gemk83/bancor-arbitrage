// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";

contract Utilities is Test {
    /// @dev create 4 users with 1000000 ETH balance each
    function createUsers() public returns (address payable[] memory) {
        address payable[] memory users = new address payable[](4);
        users[0] = payable(makeAddr("Admin"));
        users[1] = payable(makeAddr("User 1"));
        users[2] = payable(makeAddr("User 2"));
        users[3] = payable(makeAddr("User 3"));
        for (uint256 i = 0; i < 4; i++) {
            vm.deal(users[i], 1000000 ether);
        }

        return users;
    }
}
