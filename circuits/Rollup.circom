pragma circom 2.0.5;

include "./merkleTree.circom";
include "../lib/circomlib/circuits/comparators.circom";

template MerkleTreeCheckerFull(levels) {
    var n = 2**levels;

    signal input eventRoot;
    signal input stateRoot;
    signal input eventAccounts[n];
    signal input eventValues[n];
    signal input eventPathElementss[n][levels];
    signal input eventPathIndicess[n][levels];
    signal input statePathElementss[n][levels];
    signal input statePathIndicess[n][levels];

    signal eventAccountIndices[n];
    signal finalBalances[n];
    signal counts[n][n];
    signal balances[n][n];

    component eventHashers[n];
    component stateHashers[n];
    component eventCheckers[n];
    component stateCheckers[n];

    component isIndex[n][n-1];
    component isZero[n][n-1];
    component isAccount[n][n];

    for (var i=0; i < n; i++) {
        counts[i][0] <== 0;

        for (var j=1; j < n; j++) {
            isIndex[i][j-1] = IsEqual();
            isIndex[i][j-1].in[0] <== eventAccounts[i];
            isIndex[i][j-1].in[1] <== eventAccounts[j];

            isZero[i][j-1] = IsZero();
            isZero[i][j-1].in <== counts[i][j-1];

            counts[i][j] <== counts[i][j-1] + j * isZero[i][j-1].out * isIndex[i][j-1].out;
        }
        eventAccountIndices[i] <== counts[i][n-1];
    }

    for (var i=0; i < n; i++){
        // Total up each accounts balance
        for (var j=0; j < n; j++) {
            isAccount[i][j] = IsEqual();
            isAccount[i][j].in[0] <== i;
            isAccount[i][j].in[1] <== eventAccountIndices[j];
            
            if (j==0) {
                balances[i][j] <== isAccount[i][j].out * eventValues[j];
            } else {
                balances[i][j] <== balances[i][j-1] + isAccount[i][j].out * eventValues[j];
            }
        }
        finalBalances[i] <== balances[i][n-1];

        // Check the event merkle tree
        eventHashers[i] = MiMCSponge(2, 220, 1);
        eventHashers[i].ins[0] <== eventAccounts[i];
        eventHashers[i].ins[1] <== eventValues[i];
        eventHashers[i].k <== 0;

        eventCheckers[i] = MerkleTreeChecker(levels);

        eventCheckers[i].leaf <== eventHashers[i].outs[0];
        eventCheckers[i].root <== eventRoot;
        for (var j=0; j < levels; j++){
            eventCheckers[i].pathElements[j] <== eventPathElementss[i][j];
            eventCheckers[i].pathIndices[j] <== eventPathIndicess[i][j];
        }

        // Check the state merkle tree
        stateHashers[i] = MiMCSponge(2, 220, 1);
        stateHashers[i].ins[0] <== eventAccounts[i];
        stateHashers[i].ins[1] <== finalBalances[i];
        stateHashers[i].k <== 0;

        stateCheckers[i] = MerkleTreeChecker(levels);

        stateCheckers[i].leaf <== stateHashers[i].outs[0];
        stateCheckers[i].root <== stateRoot;
        for (var j=0; j < levels; j++){
            stateCheckers[i].pathElements[j] <== statePathElementss[i][j];
            stateCheckers[i].pathIndices[j] <== statePathIndicess[i][j];
        }
    }
}

component main { public [ eventRoot, stateRoot ] } = MerkleTreeCheckerFull(2);
