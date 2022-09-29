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

template HashThree() {
    signal input one;
    signal input two;
    signal input three;
    signal output hash;

    component hasher1 = HashLeftRight();
    hasher1.left <== one;
    hasher1.right <== two;

    component hasher2 = HashLeftRight();
    hasher2.left <== hasher1.hash;
    hasher2.right <== three;

    hash <== hasher2.hash;
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

    signal input eventFroms[n];
    signal input eventTos[n];
    signal input eventValues[n];

    signal shouldIncreaseBalance[n][n];
    signal shouldDecreaseBalance[n][n];
    signal credit[n][n];
    signal debit[n][n];
    signal balances[n][n];

    signal output eventRoot;
    signal output stateRoot;

    component eventHashers[n];
    component stateHashers[n];
    component rootHashers[n];
    component isTo[n][n];
    component isFrom[n][n];
    component toSeen[n][n];
    component fromSeen[n][n];
    
    component stateCheck = CheckRoot(levels);

    for (var i=0; i < n; i++){
        for (var j=0; j < n; j++) {
            // Check if this event corresponds to the `to` account
            isTo[i][j] = IsEqual();
            isTo[i][j].in[0] <== eventTos[i];
            isTo[i][j].in[1] <== eventTos[j];

            // Check if this event corresponds to the `from` account
            isFrom[i][j] = IsEqual();
            isFrom[i][j].in[0] <== eventTos[i];
            isFrom[i][j].in[1] <== eventFroms[j];
            
            // Check if this account occurs previously in the array (to prevent recording an accounts balance twice)
            toSeen[i][j] = IsZero();
            toSeen[i][j].in <== (j > 0 ? toSeen[i][j-1].in : 0) + (i > j ? isTo[i][j].out : 0);
            fromSeen[i][j] = IsZero();
            fromSeen[i][j].in <== (j > 0 ? fromSeen[i][j-1].in : 0) + (i > j ? isFrom[i][j].out : 0);
            
            shouldIncreaseBalance[i][j] <== toSeen[i][j].out * isTo[i][j].out;
            shouldDecreaseBalance[i][j] <== fromSeen[i][j].out * isFrom[i][j].out;

            credit[i][j] <== shouldIncreaseBalance[i][j] * eventValues[j];
            debit[i][j] <== shouldDecreaseBalance[i][j] * eventValues[j];       

            // Update the balance for account `i` at event `j`
            balances[i][j] <== (j > 0 ? balances[i][j-1] : 0) + credit[i][j] - debit[i][j];
        }

        // Check the event hashes
        eventHashers[i] = HashThree();
        eventHashers[i].one <== eventFroms[i];
        eventHashers[i].two <== eventTos[i];
        eventHashers[i].three <== eventValues[i];

        rootHashers[i] = HashLeftRight();
        rootHashers[i].left <== i > 0 ? rootHashers[i-1].hash : 0;
        rootHashers[i].right <== eventHashers[i].hash;

        // Check the state merkle tree
        stateHashers[i] = HashLeftRight();
        stateHashers[i].left <== eventTos[i];
        stateHashers[i].right <== balances[i][n-1];

        stateCheck.leaves[i] <== stateHashers[i].hash;
    }

    eventRoot <== rootHashers[n-1].hash;
    stateRoot <== stateCheck.root;
}

component main = RollupValidator(3);
