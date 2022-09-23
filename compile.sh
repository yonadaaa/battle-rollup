name=Rollup

# Generate constraints
circom circuits/$name.circom -o circuits --r1cs --wasm --sym

# Create zkey
snarkjs plonk setup circuits/$name.r1cs circuits/powersOfTau28_hez_final_17.ptau circuits/$name.zkey

# Export verifier as smart contract
snarkjs zkey export solidityverifier circuits/$name.zkey src/PlonkVerifier.sol
