pragma circom 2.0.5;

include "./merkleTree.circom";
include "../lib/circomlib/circuits/comparators.circom";

// From https://github.com/privacy-scaling-explorations/maci/blob/v1/circuits/circom/trees/incrementalMerkleTree.circom
template CheckRoot(levels) {
    // The total number of leaves
    var totalLeaves = 2 ** levels;

    // The number of HashLeftRight components which will be used to hash the
    // leaves
    var numLeafHashers = totalLeaves / 2;

    // The number of HashLeftRight components which will be used to hash the
    // output of the leaf hasher components
    var numIntermediateHashers = numLeafHashers - 1;

    // Inputs to the snark
    signal input leaves[totalLeaves];

    // The output
    signal output root;

    // The total number of hashers
    var numHashers = totalLeaves - 1;
    component hashers[numHashers];

    // Instantiate all hashers
    var i;
    for (i=0; i < numHashers; i++) {
        hashers[i] = HashLeftRight();
    }

    // Wire the leaf values into the leaf hashers
    for (i=0; i < numLeafHashers; i++){
        hashers[i].left <== leaves[i*2];
        hashers[i].right <== leaves[i*2+1];
    }

    // Wire the outputs of the leaf hashers to the intermediate hasher inputs
    var k = 0;
    for (i=numLeafHashers; i<numLeafHashers + numIntermediateHashers; i++) {
        hashers[i].left <== hashers[k*2].hash;
        hashers[i].right <== hashers[k*2+1].hash;
        k++;
    }

    // Wire the output of the final hash to this circuit's output
    root <== hashers[numHashers-1].hash;
}

template RollupValidator(levels) {
    var n = 2**levels;

    signal input eventAccounts[n];
    signal input eventValues[n];

    signal counts[n][n];
    signal balances[n][n];

    signal output eventRoot;
    signal output stateRoot;

    component eventHashers[n];
    component stateHashers[n];

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

    component eventCheck = CheckRoot(levels);
    component stateCheck = CheckRoot(levels);

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
        stateCheck.leaves[i] <== stateHashers[i].outs[0];
    }

    eventRoot <== eventCheck.root;
    stateRoot <== stateCheck.root;
}

component main = RollupValidator(3);
