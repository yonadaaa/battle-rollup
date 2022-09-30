pragma circom 2.0.9;

include "../lib/circomlib/circuits/comparators.circom";
include "../lib/circomlib/circuits/gates.circom";
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

    signal input froms[n];
    signal input tos[n];
    signal input values[n];
    
    signal isDefault[n];
    signal newHash[n];
    signal currentHash[n];
    signal eventsRootsActual[n];
    signal trackFrom[n][n];
    signal fromBalance[n][n];
    signal shouldDecrease[n][n];
    signal shouldIncrease[n][n];
    signal debit[n][n];
    signal credit[n][n];
    signal balances[n][n];

    signal output eventRoot;
    signal output stateRoot;

    component eventHashers[n];
    component stateHashers[n];
    component eventRootsPotential[n];
    component depositEvent[n];
    component burnEvent[n];
    component sufficientFunds[n];
    component validEvent[n];
    component isFrom[n][n];
    component isTo[n][n];
    component isFromFirst[n][n];

    component stateCheck = CheckRoot(levels);

    for (var i=0; i < n; i++) {
        // Deposits are represented as "transfers" from the zero address
        depositEvent[i] = IsZero();
        depositEvent[i].in <== froms[i];

        burnEvent[i] = IsZero();
        burnEvent[i].in <== tos[i];

        // Find the balance of account `j` during this event `i`
        for (var j=0; j < n; j++) {
            // Array access logic
            isFrom[i][j] = IsEqual();
            isFrom[i][j].in[0] <== froms[i];
            isFrom[i][j].in[1] <== tos[j];

            isTo[i][j] = IsEqual();
            isTo[i][j].in[0] <== tos[i];
            isTo[i][j].in[1] <== tos[j];

            // If we have already counted the balance for `from`, don't count it again
            isFromFirst[i][j] = IsZero();
            isFromFirst[i][j].in <== (j > 0 ? fromBalance[i][j-1] : 0);

            trackFrom[i][j] <== isFromFirst[i][j].out * isFrom[i][j].out;

            fromBalance[i][j] <== (j > 0 ? fromBalance[i][j-1] : 0) + (trackFrom[i][j] * (i > 0 ? balances[i-1][j] : 0));
        }
        
        // If the `from` account had sufficient funds for this transfer, in the previous timestep
        sufficientFunds[i] = GreaterEqThan(252);
        sufficientFunds[i].in[0] <== fromBalance[i][n-1];
        sufficientFunds[i].in[1] <== values[i];

        // Either the event is a deposit or the `from` account needs to have enough funds
        validEvent[i] = OR();
        validEvent[i].a <== depositEvent[i].out;
        validEvent[i].b <== sufficientFunds[i].out;
    
        for (var j=0; j < n; j++) {
            // If this is the "from" account, and the event is valid
            shouldDecrease[i][j] <== isFrom[i][j].out * validEvent[i].out;
            // This is the "to" account and the event is valid
            shouldIncrease[i][j] <== isTo[i][j].out * validEvent[i].out;

            // Subtract `debit` from balance
            debit[i][j] <== shouldDecrease[i][j] * values[i];
            // Add `credit` to balance
            credit[i][j] <== shouldIncrease[i][j] * values[i];

            balances[i][j] <== (i > 0 ? balances[i-1][j] : 0) + credit[i][j] - debit[i][j];
        }

        eventHashers[i] = HashThree();
        eventHashers[i].one <== froms[i];
        eventHashers[i].two <== tos[i];
        eventHashers[i].three <== values[i];

        eventRootsPotential[i] = HashLeftRight();
        eventRootsPotential[i].left <== i > 0 ? eventRootsPotential[i-1].hash : 0;
        eventRootsPotential[i].right <== eventHashers[i].hash;

        // If both accounts are zero, we have processed all events and these are just default signals
        // If so, stop updating the event root, as the smart contract does not "pad" the (n-i) remaining events
        isDefault[i] <== depositEvent[i].out * burnEvent[i].out;
        newHash[i] <== (1 - isDefault[i]) * eventRootsPotential[i].hash;
        currentHash[i] <== isDefault[i] * (i > 0 ? eventsRootsActual[i-1] : 0);

        eventsRootsActual[i] <== currentHash[i] + newHash[i];

        // Check the state merkle tree
        stateHashers[i] = HashLeftRight();
        stateHashers[i].left <== tos[i];
        stateHashers[i].right <== balances[i][n-1];

        stateCheck.leaves[i] <== stateHashers[i].hash;
    }

    eventRoot <== eventsRootsActual[n-1];
    stateRoot <== stateCheck.root;
}

component main = RollupValidator(2);

/* INPUT = {
    "froms":   [0,1,0,1],
    "tos":     [1,2,1,3],
    "values":  [10,7,50,20]
} */