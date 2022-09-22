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

        // Create input JSON file
        string memory path = "input.json";
        string memory line = string.concat(
            '{"a":',
            vm.toString(a),
            ',"b":',
            vm.toString(b),
            "}"
        );
        vm.writeLine(path, line);

        // Generate proof
        string[] memory genInputs = new string[](8);
        genInputs[0] = "snarkjs";
        genInputs[1] = "plonk";
        genInputs[2] = "fullprove";
        genInputs[3] = "input.json";
        genInputs[4] = "circuits/Example_js/Example.wasm";
        genInputs[5] = "circuits/Example.zkey";
        genInputs[6] = "proof.json";
        genInputs[7] = "public.json";
        vm.ffi(genInputs);

        // Get calldata for proof and output
        string[] memory inputs = new string[](3);
        inputs[1] = vm.toString(a);
        inputs[2] = vm.toString(b);

        inputs[0] = "./prove.sh";
        bytes memory proof = vm.ffi(inputs);

        inputs[0] = "./output.sh";
        bytes memory output = vm.ffi(inputs);

        // Delete files
        string[] memory rmInput = new string[](2);
        rmInput[0] = "rm";

        rmInput[1] = "input.json";
        vm.ffi(rmInput);
        rmInput[1] = "proof.json";
        vm.ffi(rmInput);
        rmInput[1] = "public.json";
        vm.ffi(rmInput);

        uint256[] memory pubSignals = new uint256[](3);
        pubSignals[0] = bytesToUint(output);
        pubSignals[1] = a;
        pubSignals[2] = b;

        assertTrue(verifier.verifyProof(proof, pubSignals));
    }
}
