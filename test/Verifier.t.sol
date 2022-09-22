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

    // TODO: Generate proofs for fuzzed inputs
    // Take x and y as input
    // run the generate calldata
    // splice calldata and fill in pubsignals and proof
    function testVerify() public {
        string[] memory inputs = new string[](3);
        inputs[0] = "./prove.sh";
        inputs[1] = "3";
        inputs[2] = "11";

        bytes memory res = vm.ffi(inputs);

        uint256[] memory pubSignals = new uint256[](3);
        pubSignals[0] = 33;
        pubSignals[1] = 3;
        pubSignals[2] = 11;

        bytes memory proof = res;

        assertTrue(verifier.verifyProof(proof, pubSignals));
    }
}
