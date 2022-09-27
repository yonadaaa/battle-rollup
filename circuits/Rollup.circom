pragma circom 2.0.9;

include "../lib/circomlib/circuits/comparators.circom";
include "../lib/circomlib/circuits/mimcsponge.circom";

// Computes MiMC([left, right])
template HashLeftRight() {
    signal input left;
    signal input right;
    signal output hash;

    component hasher = MiMCSponge(2, 220, 1);
    hasher.ins[0] <== left;
    hasher.ins[1] <== right;
    hasher.k <== 0;
    hash <== hasher.outs[0];
}

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

    signal shouldCountBalance[n][n];
    signal balances[n][n];

    signal output eventRoot;
    signal output stateRoot;

    component eventHashers[n];
    component stateHashers[n];
    component sameAccount[n][n];
    component accountSeen[n][n];
    
    component eventCheck = CheckRoot(levels);
    component stateCheck = CheckRoot(levels);

    for (var i=0; i < n; i++){
        for (var j=0; j < n; j++) {
            sameAccount[i][j] = IsEqual();
            sameAccount[i][j].in[0] <== eventAccounts[i];
            sameAccount[i][j].in[1] <== eventAccounts[j];
            
            accountSeen[i][j] = IsZero();
            accountSeen[i][j].in <== (j > 0 ? accountSeen[i][j-1].in : 0) + (j < i ? sameAccount[i][j].out : 0);
            
            shouldCountBalance[i][j] <== accountSeen[i][j].out * sameAccount[i][j].out;
            
            balances[i][j] <== shouldCountBalance[i][j] * eventValues[j] + (j > 0 ? balances[i][j-1] : 0);
        }

        // Check the event merkle tree
        eventHashers[i] = HashLeftRight();
        eventHashers[i].left <== eventAccounts[i];
        eventHashers[i].right <== eventValues[i];

        // Check the state merkle tree
        stateHashers[i] = HashLeftRight();
        stateHashers[i].left <== eventAccounts[i];
        stateHashers[i].right <== balances[i][n-1];

        eventCheck.leaves[i] <== eventHashers[i].hash;
        stateCheck.leaves[i] <== stateHashers[i].hash;
    }

    eventRoot <== eventCheck.root;
    stateRoot <== stateCheck.root;
}

component main = RollupValidator(2);
