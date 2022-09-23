// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;
pragma abicoder v2;

import "tornado-core/MerkleTreeWithHistory.sol";
import "./PlonkVerifier.sol";

contract Rollup is MerkleTreeWithHistory {
    PlonkVerifier private verifier;
    bool private resolved;

    constructor(uint32 levels, address hasher)
        MerkleTreeWithHistory(levels, IHasher(hasher))
    {
        verifier = new PlonkVerifier();
    }

    function deposit() external payable {
        require(!resolved, "The rollup has been resolved");

        uint256 leaf = uint256(
            hashLeftRight(
                hasher,
                bytes32(uint256(msg.sender)),
                bytes32(msg.value)
            )
        );

        _insert(bytes32(leaf));
    }

    function resolve(bytes calldata proof) external payable {
        uint256[] memory pubSignals = new uint256[](1);
        pubSignals[0] = uint256(getLastRoot());

        require(
            verifier.verifyProof(proof, pubSignals),
            "Proof verification failed"
        );

        resolved = true;
    }

    function withdraw(
        address account,
        uint256 value,
        bytes32[] calldata pathElements,
        bool[] calldata pathIndices
    ) external payable {
        require(resolved, "The rollup has not been resolved");

        bytes32 leaf = hashLeftRight(
            hasher,
            bytes32(uint256(account)),
            bytes32(value)
        );

        checkMerkleTree(leaf, pathElements, pathIndices);

        (bool success, ) = account.call{value: value}("");
        require(success);
    }

    function checkMerkleTree(
        bytes32 leaf,
        bytes32[] calldata pathElements,
        bool[] calldata pathIndices
    ) private view {
        bytes32 currentLevelHash = leaf;

        for (uint32 i = 0; i < levels; i++) {
            bytes32 left;
            bytes32 right;
            if (pathIndices[i]) {
                left = pathElements[i];
                right = currentLevelHash;
            } else {
                left = currentLevelHash;
                right = pathElements[i];
            }
            currentLevelHash = hashLeftRight(hasher, left, right);
        }

        require(
            currentLevelHash == getLastRoot(),
            "Provided root does not match result"
        );
    }
}
