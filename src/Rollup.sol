// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// TODO replace this with lib import
import "../lib/tornado-core/contracts/MerkleTreeWithHistory.sol";

contract Rollup is MerkleTreeWithHistory {
    constructor(uint32 levels, address hasher)
        MerkleTreeWithHistory(levels, IHasher(hasher))
    {}

    function deposit() external payable {
        //  need to hash the inputs into a field element
        bytes32 _leaf = bytes32(
            uint256(keccak256(abi.encodePacked(msg.sender, msg.sender))) %
                FIELD_SIZE
        );

        _insert(_leaf);
    }
}
