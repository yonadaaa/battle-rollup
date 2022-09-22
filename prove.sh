name=Example

# Create input file
echo "{\"a\":$1,\"b\":$2}" > input.json

# Generate proof
snarkjs plonk fullprove input.json circuits/Example_js/$name.wasm circuits/$name.zkey proof.json public.json

# Export proof calldata
proof=$(snarkjs zkey export soliditycalldata public.json proof.json)

echo ${proof:0:1602} 