// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./PlonkVerifier.sol";

interface IHasher {
  function MiMCSponge(uint256 in_xL, uint256 in_xR) external pure returns (uint256 xL, uint256 xR);
}

contract Rollup {
    uint256 public constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    IHasher public immutable hasher;

    PlonkVerifier private verifier;
    bytes32 private eventRoot;
    bytes32 public stateRoot;
    uint256 public expiry;
    uint256 private total;
    uint32 private levels;

    mapping(bytes32 => bool) private withdrawn;

    event Deposit(address to, uint256 value);
    event Transfer(address from, bytes32 to, bytes32 value);
    event Resolve();
    event Withdraw(address to, uint256 value);

    constructor(
        uint256 _expiry,
        uint32 _levels,
        IHasher _hasher
    ) {
        hasher = _hasher;
        levels = _levels;
        expiry = _expiry;

        verifier = new PlonkVerifier();
    }

    /**
    @dev Hash 2 tree leaves, returns MiMC(_left, _right)
  */
    function hashLeftRight(bytes32 _left, bytes32 _right)
        public
        view
        returns (bytes32)
    {
        require(
            uint256(_left) < FIELD_SIZE,
            "_left should be inside the field"
        );
        require(
            uint256(_right) < FIELD_SIZE,
            "_right should be inside the field"
        );
        uint256 R = uint256(_left);
        uint256 C = 0;
        (R, C) = hasher.MiMCSponge(R, C);
        R = addmod(R, uint256(_right), FIELD_SIZE);
        (R, C) = hasher.MiMCSponge(R, C);
        return bytes32(R);
    }

    function hashThree(
        bytes32 one,
        bytes32 two,
        bytes32 three
    ) public view returns (bytes32) {
        return hashLeftRight(hashLeftRight(one, two), three);
    }

    function deposit() external payable {
        require(
            block.timestamp < expiry,
            "The rollup has entered the resolution stage"
        );
        require(total < 2**levels, "Rollup is full");

        bytes32 leaf = hashThree(
            bytes32(0),
            bytes32(uint256(uint160(msg.sender))),
            bytes32(msg.value)
        );

        eventRoot = hashLeftRight(eventRoot, leaf);
        total++;

        emit Deposit(msg.sender, msg.value);
    }

    function transfer(bytes32 to, bytes32 value) external payable {
        require(
            block.timestamp < expiry,
            "The rollup has entered the resolution stage"
        );
        require(total < 2**levels, "Rollup is full");

        bytes32 leaf = hashThree(bytes32(uint256(uint160(msg.sender))), to, value);

        eventRoot = hashLeftRight(eventRoot, leaf);
        total++;

        emit Transfer(msg.sender, to, value);
    }

    function resolve(bytes32 state, bytes calldata proof) external {
        require(
            block.timestamp > expiry,
            "The rollup has not entered the resolution stage"
        );

        uint256[] memory pubSignals = new uint256[](2);
        pubSignals[0] = uint256(eventRoot);
        pubSignals[1] = uint256(state);

        require(
            verifier.verifyProof(proof, pubSignals),
            "Proof verification failed"
        );

        stateRoot = state;

        emit Resolve();
    }

    function withdraw(
        address to,
        uint256 value,
        bytes32[] calldata pathElements,
        bool[] calldata pathIndices
    ) external {
        bytes32 leaf = hashLeftRight(bytes32(uint256(uint160(to))), bytes32(value));

        require(!withdrawn[leaf], "This account has already withdrawn");
        checkMerkleTree(leaf, pathElements, pathIndices);

        withdrawn[leaf] = true;
        to.call{value: value}("");

        emit Withdraw(to, value);
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
            currentLevelHash = hashLeftRight(left, right);
        }

        require(
            currentLevelHash == stateRoot,
            "Provided root does not match result"
        );
    }
}
