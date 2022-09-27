pragma circom 2.0.5;

include "./merkleTree.circom";
include "../lib/circomlib/circuits/comparators.circom";

template MerkleTreeCheckerFull(levels) {
    var n = 2**levels;

    signal input leaves[n];
    signal input pathElements[n][levels];
    signal input pathIndices[n][levels];

    signal output root;

    component selectors[n][levels];
    component hashers[n][levels];

    for (var i = 0; i < n; i++) {
        for (var j = 0; j < levels; j++) {
            selectors[i][j] = DualMux();
            selectors[i][j].in[0] <== j == 0 ? leaves[i] : hashers[i][j - 1].hash;
            selectors[i][j].in[1] <== pathElements[i][j];
            selectors[i][j].s <== pathIndices[i][j];

            hashers[i][j] = HashLeftRight();
            hashers[i][j].left <== selectors[i][j].out[0];
            hashers[i][j].right <== selectors[i][j].out[1];
        }
        if (i > 0) {
            hashers[i][levels - 1].hash === hashers[i - 1][levels - 1].hash;
        }
    }

    root <== hashers[n - 1][levels - 1].hash;
}

template RollupValidator(levels) {
    var n = 2**levels;

    signal input eventAccounts[n];
    signal input eventValues[n];
    signal input eventPathElementss[n][levels];
    signal input eventPathIndicess[n][levels];
    signal input statePathElementss[n][levels];
    signal input statePathIndicess[n][levels];

    signal counts[n][n];
    signal balances[n][n];

    signal output eventRoot;
    signal output stateRoot;

    component eventHashers[n];
    component stateHashers[n];
    component stateCheckers[n];

    component isIndex[n][n-1];
    component isZero[n][n-1];
    component isAccount[n][n];

    for (var i=0; i < n; i++) {

        // TODO: diagonal?
        for (var j=0; j < n; j++) {
            if (j==0) {
                counts[i][0] <== 0;
            } else {
                isIndex[i][j-1] = IsEqual();
                isIndex[i][j-1].in[0] <== eventAccounts[i];
                isIndex[i][j-1].in[1] <== eventAccounts[j];

                isZero[i][j-1] = IsZero();
                isZero[i][j-1].in <== counts[i][j-1];

                counts[i][j] <== counts[i][j-1] + j * isZero[i][j-1].out * isIndex[i][j-1].out;
            }
        }
    }

    component eventCheck = MerkleTreeCheckerFull(levels);
    component stateCheck = MerkleTreeCheckerFull(levels);

    for (var i=0; i < n; i++){
        // Total up each accounts balance
        for (var j=0; j < n; j++) {
            isAccount[i][j] = IsEqual();
            isAccount[i][j].in[0] <== i;
            isAccount[i][j].in[1] <== counts[j][n-1];
            
            if (j==0) {
                balances[i][j] <== isAccount[i][j].out * eventValues[j];
            } else {
                balances[i][j] <== isAccount[i][j].out * eventValues[j] + balances[i][j-1];
            }
        }

        // Check the event merkle tree
        eventHashers[i] = MiMCSponge(2, 220, 1);
        eventHashers[i].ins[0] <== eventAccounts[i];
        eventHashers[i].ins[1] <== eventValues[i];
        eventHashers[i].k <== 0;

        // Check the state merkle tree
        stateHashers[i] = MiMCSponge(2, 220, 1);
        stateHashers[i].ins[0] <== eventAccounts[i];
        stateHashers[i].ins[1] <== balances[i][n-1];
        stateHashers[i].k <== 0;

        eventCheck.leaves[i] <== eventHashers[i].outs[0];
        for (var j=0; j < levels; j++){
            eventCheck.pathElements[i][j] <== eventPathElementss[i][j];
            eventCheck.pathIndices[i][j] <== eventPathIndicess[i][j];
        }

        stateCheck.leaves[i] <== stateHashers[i].outs[0];
        for (var j=0; j < levels; j++){
            stateCheck.pathElements[i][j] <== statePathElementss[i][j];
            stateCheck.pathIndices[i][j] <== statePathIndicess[i][j];
        }
    }

    eventRoot <== eventCheck.root;
    stateRoot <== stateCheck.root;
}

component main = RollupValidator(3);
