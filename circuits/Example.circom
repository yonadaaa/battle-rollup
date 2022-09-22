pragma circom 2.0.5;

include "./merkleTree.circom";

template MerkleTreeCheckerFull(levels) {
    var n = 2**levels;

    signal input leaves[n];
    signal input root;
    signal input pathElementss[n][levels];
    signal input pathIndicess[n][levels];

    component checkers[n];

    for (var i=0; i < n; i++){
        checkers[i] = MerkleTreeChecker(2);

        checkers[i].leaf <== leaves[i];
        checkers[i].root <== root;
        for (var j=0; j < levels; j++){
            checkers[i].pathElements[j] <== pathElementss[i][j];
            checkers[i].pathIndices[j] <== pathIndicess[i][j];
        }
    }
}

component main { public [ root ] } = MerkleTreeCheckerFull(2);
