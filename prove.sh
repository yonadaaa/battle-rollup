# Export proof calldata
calldata=$(snarkjs zkey export soliditycalldata public.json proof.json)

echo ${calldata:0:1602}