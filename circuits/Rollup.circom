pragma circom 2.0.5;

include "./merkleTree.circom";
include "../lib/circomlib/circuits/comparators.circom";

template GetMerkleTreeRoot(levels) {
    signal input leaf;
    signal input pathElements[levels];
    signal input pathIndices[levels];

    signal output root;

    component selectors[levels];
    component hashers[levels];

    for (var i = 0; i < levels; i++) {
        selectors[i] = DualMux();
        selectors[i].in[0] <== i == 0 ? leaf : hashers[i - 1].hash;
        selectors[i].in[1] <== pathElements[i];
        selectors[i].s <== pathIndices[i];

        hashers[i] = HashLeftRight();
        hashers[i].left <== selectors[i].out[0];
        hashers[i].right <== selectors[i].out[1];
    }

    root <== hashers[levels - 1].hash;
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
    component eventCheckers[n];
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

    component getEventRoot;
    component getStateRoot;

    // TODO: make a component which checks the whole tree at once
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

        if (i==0){
            getEventRoot = GetMerkleTreeRoot(levels);
            getEventRoot.leaf <== eventHashers[i].outs[0];
            for (var j=0; j < levels; j++){
                getEventRoot.pathElements[j] <== eventPathElementss[i][j];
                getEventRoot.pathIndices[j] <== eventPathIndicess[i][j];
            }
            eventRoot <== getEventRoot.root;

            getStateRoot = GetMerkleTreeRoot(levels);
            getStateRoot.leaf <== stateHashers[i].outs[0];
            for (var j=0; j < levels; j++){
                getStateRoot.pathElements[j] <== statePathElementss[i][j];
                getStateRoot.pathIndices[j] <== statePathIndicess[i][j];
            }
            stateRoot <== getStateRoot.root;
        }

        eventCheckers[i] = MerkleTreeChecker(levels);
        eventCheckers[i].leaf <== eventHashers[i].outs[0];
        eventCheckers[i].root <== eventRoot;
        for (var j=0; j < levels; j++){
            eventCheckers[i].pathElements[j] <== eventPathElementss[i][j];
            eventCheckers[i].pathIndices[j] <== eventPathIndicess[i][j];
        }

        stateCheckers[i] = MerkleTreeChecker(levels);
        stateCheckers[i].leaf <== stateHashers[i].outs[0];
        stateCheckers[i].root <== stateRoot;
        for (var j=0; j < levels; j++){
            stateCheckers[i].pathElements[j] <== statePathElementss[i][j];
            stateCheckers[i].pathIndices[j] <== statePathIndicess[i][j];
        }
    }
}

component main = RollupValidator(3);
