// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Rollup.sol";

contract RollupTest is Test {
    Rollup public rollup;

    function setUp() public {
        rollup = new Rollup();
    }

    // Test that the rollup root is changing upon each deposit
    // Now check that the transactions are actually in the root
    function testDeposit() public {
        bytes32 root = rollup.root();
        assertEq(root, "");

        rollup.deposit();
        bytes32 newRoot = rollup.root();
        assertTrue(newRoot != "");

        rollup.deposit();
        bytes32 newNewRoot = rollup.root();
        assertTrue(newNewRoot != newRoot);
    }
}
