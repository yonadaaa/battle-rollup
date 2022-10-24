# battle-rollup

## Usage
1. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
2. Install [Circom](https://docs.circom.io/getting-started/installation/) and SnarkJS
3. Download powersOfTau file from [Hermez repository](https://github.com/iden3/snarkjs#7-prepare-phase-2)
4. Run `./compile.sh` to compile the circuits
5. You are good to go! Run `forge test` etc.

## Gotchas

The Forge tests use SnarkJS (via Foundry [FFI](https://book.getfoundry.sh/cheatcodes/ffi)) to generate proofs for every input. This leads to two issues:
- Currently, the SnarkJS prover contract always uses the same filename for input and proof files. As Forge tests run in parallel, if two tests use the prover, they will likely fail as they overwite each others files. You can specify a particular test with `forge test --match-test...`.
- The standard number of 256 fuzz runs take a long time to run. I reccomend you set `FOUNDRY_FUZZ_RUNS` to a low value _eg. < 10_.
