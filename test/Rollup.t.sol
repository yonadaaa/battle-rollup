// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "../src/Rollup.sol";

contract RollupTest is Test {
    Rollup public rollup;
    uint256 public constant RUNS = 16;

    function setUp() public {
        rollup = new Rollup();
    }

    // Test that the rollup root is changing upon each deposit
    function testDeposit(uint32[RUNS] calldata values) public {
        bytes32 root = rollup.roots(0);
        bytes32 prevRoot = root;
        assertEq(root, "");

        for (uint256 i; i < RUNS; i++) {
            rollup.deposit{value: values[i]}();

            root = rollup.roots(i);
            assertTrue(root != prevRoot);
            prevRoot = root;
        }
    }
}
