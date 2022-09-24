pragma circom 2.0.5;

include "./merkleTree.circom";

template MerkleTreeCheckerFull(levels) {
    var n = 2**levels;

    signal input eventAccounts[n];
    signal input eventValues[n];
    signal input root;
    signal input pathElementss[n][levels];
    signal input pathIndicess[n][levels];

    component checkers[n];
    component hashers[n];

    for (var i=0; i < n; i++){
        hashers[i] = MiMCSponge(2, 220, 1);
        hashers[i].ins[0] <== eventAccounts[i];
        hashers[i].ins[1] <== eventValues[i];
        hashers[i].k <== 0;

        checkers[i] = MerkleTreeChecker(2);

        checkers[i].leaf <== hashers[i].outs[0];
        checkers[i].root <== root;
        for (var j=0; j < levels; j++){
            checkers[i].pathElements[j] <== pathElementss[i][j];
            checkers[i].pathIndices[j] <== pathIndicess[i][j];
        }
    }
}

component main { public [ root ] } = MerkleTreeCheckerFull(2);
