// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/PlonkVerifier.sol";

contract PlonkVerifierTest is Test {
    PlonkVerifier public verifier;

    function setUp() public {
        verifier = new PlonkVerifier();
    }

    function testWrongVerify() public {
        uint256[] memory pubSignals;
        assertTrue(!verifier.verifyProof("", pubSignals));
    }

    // Generate proof for fuzzed inputs with SnarkJS and verify with smart contract
    function testVerify(uint32 a, uint32 b) public {
        vm.assume(a > 2);

        string[] memory inputs = new string[](3);
        inputs[1] = vm.toString(a);
        inputs[2] = vm.toString(b);

        // TODO combine proof and output into one script
        inputs[0] = "./prove.sh";
        bytes memory proof = vm.ffi(inputs);

        inputs[0] = "./output.sh";
        bytes memory output = vm.ffi(inputs);

        assertEq(output << 32, "");

        uint256[] memory pubSignals = new uint256[](3);
        pubSignals[0] = bytesToUint(output);
        pubSignals[1] = a;
        pubSignals[2] = b;

        assertTrue(verifier.verifyProof(proof, pubSignals));
    }
}
