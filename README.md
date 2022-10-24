# battle-rollup

Usage:
1. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
2. Install [Circom](https://docs.circom.io/getting-started/installation/) and SnarkJS
3. Download powersOfTau file from [Hermez repository](https://github.com/iden3/snarkjs#7-prepare-phase-2)
4. Run `./compile.sh` to compile the circuits
5. You are good to go! Run `forge test` etc.

Note that the Forge tests use SnarkJS to generate proof for every input; therefore tests can take a long time to run. I reccomend you set `FOUNDRY_FUZZ_RUNS` to a low value.
