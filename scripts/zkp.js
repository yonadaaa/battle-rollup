const MerkleTree = require("fixed-merkle-tree");
const snarkjs = require("snarkjs");
const { mimc } = require("./mimc");

const LEVELS = 2;
// TODO: per the contract, these leaves must be set to the apprioprate zero if needed
const LEAVES = [
  [649562641434947955654834859981556155081347864431n, 100],
  [649562641434947955654834859981556155081347864431n, 100],
  [649562641434947955654834859981556155081347864431n, 100],
  [649562641434947955654834859981556155081347864431n, 100],
];

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const getPaths = async () => {
  await sleep(500);

  const hashedLeaves = LEAVES.map(([address, value]) =>
    mimc.hash(address, value)
  );

  const merkleTree = new MerkleTree.MerkleTree(LEVELS, hashedLeaves, {
    hashFunction: mimc.hash,
  });

  const pathElementss = LEAVES.map((pair) => {
    let index = LEAVES.findIndex((leaf) =>
      leaf.every(function (element, index) {
        return element === pair[index];
      })
    );

    if (index < 0) return null;
    const { pathElements, pathIndices } = merkleTree.path(index);
    return pathElements;
  });

  const pathIndicess = LEAVES.map((pair) => {
    let index = LEAVES.findIndex((leaf) =>
      leaf.every(function (element, index) {
        return element === pair[index];
      })
    );

    if (index < 0) return null;
    const { pathIndices } = merkleTree.path(index);
    return pathIndices;
  });

  return [merkleTree.root, pathElementss, pathIndicess];
};

// We need pathElements and indices for all
getPaths().then(([root, pathElements, pathIndices]) => {
  const hashedLeaves = LEAVES.map(([address, value]) =>
    mimc.hash(address, value)
  );

  const input = {
    leaves: hashedLeaves,
    root: root.toString(),
    pathElementss: pathElements,
    pathIndicess: pathIndices,
  };

  console.log(input);

  snarkjs.plonk
    .fullProve(
      input,
      "./circuits/Example_js/Example.wasm",
      "./circuits/Example.zkey"
    )
    .then(({ proof, publicSignals }) => {
      snarkjs.plonk
        .exportSolidityCallData(proof, publicSignals)
        .then((s) => console.log(s));
    });
});
