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
        address[N] memory eventAccounts,
        uint256[N] memory eventValues
    ) public returns (bytes memory proof) {
        address[N] memory eventFroms;
        vm.writeFile(
            "input.json",
            string(
                abi.encodePacked(
                    '{"eventFroms":',
                    toString(eventFroms),
                    ',"eventTos":',
                    toString(eventAccounts),
                    ',"eventValues":',
                    toString(eventValues),
                    "}"
                )
            )
        );

        string[] memory inputsP = new string[](8);
        inputsP[0] = "snarkjs";
        inputsP[1] = "plonk";
        inputsP[2] = "fullprove";
        inputsP[3] = "input.json";
        // TODO: fetch filename when users generates prover for circuit
        inputsP[4] = "circuits/Rollup_js/Rollup.wasm";
        inputsP[5] = "circuits/Rollup.zkey";
        inputsP[6] = "proof.json";
        inputsP[7] = "public.json";
        vm.ffi(inputsP);

        string[] memory inputs = new string[](1);
        inputs[0] = "./prove.sh";
        proof = vm.ffi(inputs);

        vm.removeFile("input.json");
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
