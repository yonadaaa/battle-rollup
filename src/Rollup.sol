// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Rollup {
    uint32 public constant levels = 4;
    uint32 public constant ROOT_HISTORY_SIZE = 30;

    uint32 public currentRootIndex = 0;
    uint32 public nextIndex = 0;
    mapping(uint256 => bytes32) public filledSubtrees;
    bytes32 public root;

    function deposit() external payable {
        bytes32 _leaf = keccak256(abi.encodePacked(msg.sender, msg.value));

        uint32 _nextIndex = nextIndex;
        require(
            _nextIndex != uint32(2)**levels,
            "Merkle tree is full. No more leaves can be added"
        );
        uint32 currentIndex = _nextIndex;
        bytes32 currentLevelHash = _leaf;
        bytes32 left;
        bytes32 right;

        for (uint32 i = 0; i < levels; i++) {
            if (currentIndex % 2 == 0) {
                left = currentLevelHash;
                right = "";
                filledSubtrees[i] = currentLevelHash;
            } else {
                left = filledSubtrees[i];
                right = currentLevelHash;
            }
            currentLevelHash = keccak256(abi.encodePacked(left, right));
            currentIndex /= 2;
        }

        uint32 newRootIndex = (currentRootIndex + 1) % ROOT_HISTORY_SIZE;
        root = currentLevelHash;
        currentRootIndex = newRootIndex;
        nextIndex = _nextIndex + 1;
    }
}
