// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;
pragma abicoder v2;

import "tornado-core/MerkleTreeWithHistory.sol";
import "./PlonkVerifier.sol";

contract Rollup is MerkleTreeWithHistory {
    PlonkVerifier private verifier;
    bytes32 private stateRoot;
    uint256 private expiry;

    constructor(
        uint32 levels,
        IHasher hasher,
        uint256 _expiry
    ) MerkleTreeWithHistory(levels, hasher) {
        verifier = new PlonkVerifier();
        expiry = _expiry;
    }

    function deposit() external payable {
        require(
            block.timestamp < expiry,
            "The rollup has entered the resolution stage"
        );

        bytes32 leaf = hashLeftRight(
            hasher,
            bytes32(uint256(msg.sender)),
            bytes32(msg.value)
        );

        _insert(leaf);
    }

    function resolve(bytes32 state, bytes calldata proof) external {
        require(
            block.timestamp > expiry,
            "The rollup has not entered the resolution stage"
        );

        uint256[] memory pubSignals = new uint256[](2);
        pubSignals[0] = uint256(getLastRoot());
        pubSignals[1] = uint256(state);

        require(
            verifier.verifyProof(proof, pubSignals),
            "Proof verification failed"
        );

        stateRoot = state;
    }

    function withdraw(
        address account,
        uint256 value,
        bytes32[] calldata pathElements,
        bool[] calldata pathIndices
    ) external {
        require(stateRoot != "", "The rollup has not been resolved");

        bytes32 leaf = hashLeftRight(
            hasher,
            bytes32(uint256(account)),
            bytes32(value)
        );

        checkMerkleTree(leaf, pathElements, pathIndices);

        (bool success, ) = account.call{value: value}("");
        require(success, "Send failed");
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
            currentLevelHash == stateRoot,
            "Provided root does not match result"
        );
    }
}
