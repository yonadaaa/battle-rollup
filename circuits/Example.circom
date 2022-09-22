pragma circom 2.0.5;

template Example () {
    signal input a;
    signal input b;
    signal output c;
    
    c <== a * b;

    assert(a > 2);
}

component main { public [ a, b ] } = Example();
