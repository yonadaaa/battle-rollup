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
        uint256[] memory pubSignals = new uint256[](2);
        pubSignals[0] = uint256(roots[currentRootIndex]);

        require(
            verifier.verifyProof(proof, pubSignals),
            "Proof verification failed"
        );

        resolved = true;
    }

    function withdraw(address account, uint256 value) external payable {
        require(resolved, "The rollup has not been resolved");

        // Check if account and value are in the most recent merkle root.
        // To do this on-chain they'd have to provide a merkle proof.
        // Maybe do with ZK?

        (bool success, ) = account.call{value: value}("");
        require(success);
    }
}
