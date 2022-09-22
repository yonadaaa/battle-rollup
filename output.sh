name=Example

# Create input file
echo "{\"a\":$1,\"b\":$2}" > input.json

# Generate proof
snarkjs plonk fullprove input.json circuits/Example_js/$name.wasm circuits/$name.zkey proof.json public.json

# Export proof calldata
calldata=$(snarkjs zkey export soliditycalldata public.json proof.json)

rm input.json
rm proof.json
rm public.json

echo ${calldata:1605:66} 