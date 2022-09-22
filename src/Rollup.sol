// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/tornado-core/contracts/MerkleTreeWithHistory.sol";

contract Rollup is MerkleTreeWithHistory {
    constructor(uint32 levels, address hasher)
        MerkleTreeWithHistory(levels, IHasher(hasher))
    {}

    function deposit() external payable {
        bytes32 _leaf = bytes32(
            uint256(keccak256(abi.encodePacked(msg.sender, msg.value))) %
                FIELD_SIZE
        );

        _insert(_leaf);
    }
}
