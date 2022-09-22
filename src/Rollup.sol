// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import "tornado-core/MerkleTreeWithHistory.sol";

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
