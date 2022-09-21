// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MerkleTreeWithHistory.sol";

contract Rollup is MerkleTreeWithHistory {
    constructor(IHasher hasher) MerkleTreeWithHistory(4, hasher) {}

    function deposit() external payable {
        bytes32 _leaf = keccak256(abi.encodePacked(msg.sender, msg.value));
        _insert(_leaf);
    }
}
