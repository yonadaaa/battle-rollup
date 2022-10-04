// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;
pragma abicoder v2;

import "forge-std/Test.sol";

// TODO: Auto-generate prover contract from a template file, based on circuit inputs
contract PlonkProver is Script {
    uint32 public constant LEVELS = 2;
    uint256 public constant N = 2**LEVELS;

    // TODO: Determine argument types and names from circuit inputs
    function fullProve(
        address[N] memory eventFroms,
        address[N] memory eventTos,
        uint256[N] memory eventValues
    ) public returns (bytes memory proof) {
        string memory fileName = "input.json";

        // TODO: can this just be written as an array of signals?
        vm.writeFile(
            fileName,
            string(
                abi.encodePacked(
                    '{"froms":',
                    toString(eventFroms),
                    ',"tos":',
                    toString(eventTos),
                    ',"values":',
                    toString(eventValues),
                    "}"
                )
            )
        );

        return fullProveFromFile(fileName);
    }

    function fullProveFromFile(string memory fileName)
        public
        returns (bytes memory proof)
    {
        string[] memory inputsProof = new string[](8);
        inputsProof[0] = "snarkjs";
        inputsProof[1] = "plonk";
        inputsProof[2] = "fullprove";
        inputsProof[3] = fileName;
        // TODO: fetch filename when users generates prover for circuit
        inputsProof[4] = "circuits/Rollup_js/Rollup.wasm";
        inputsProof[5] = "circuits/Rollup.zkey";
        inputsProof[6] = "proof.json";
        inputsProof[7] = "public.json";
        vm.ffi(inputsProof);

        string[] memory inputs = new string[](1);
        inputs[0] = "./prove.sh";
        proof = vm.ffi(inputs);

        vm.removeFile(fileName);
        vm.removeFile("proof.json");
        vm.removeFile("public.json");

        return proof;
    }

    function toString(uint256[N] memory arr)
        public
        returns (string memory out)
    {
        out = "[";
        for (uint256 i; i < N; i++) {
            out = string(
                abi.encodePacked(
                    out,
                    '"',
                    vm.toString(arr[i]),
                    '"',
                    i == (N - 1) ? "" : ","
                )
            );
        }
        out = string(abi.encodePacked(out, "]"));
    }

    function toString(address[N] memory arr)
        public
        returns (string memory out)
    {
        uint256[N] memory arrUInt;
        for (uint256 i; i < N; i++) {
            arrUInt[i] = uint256(arr[i]);
        }
        return toString(arrUInt);
    }
}
