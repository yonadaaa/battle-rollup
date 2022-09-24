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

  const paths = LEAVES.map((pair) => {
    let index = LEAVES.findIndex((leaf) =>
      leaf.every(function (element, index) {
        return element === pair[index];
      })
    );

    if (index < 0) return null;

    return merkleTree.path(index);
  });

  const pathElementss = paths.map((x) => x.pathElements);
  const pathIndicess = paths.map((x) => x.pathIndices);
  return [merkleTree.root, pathElementss, pathIndicess];
};

getPaths().then(([root, pathElementss, pathIndicess]) => {
  const input = {
    eventAccounts: LEAVES.map((l) => l[0]),
    eventValues: LEAVES.map((l) => l[1]),
    root: root.toString(),
    pathElementss,
    pathIndicess,
  };

  console.log(input);

  snarkjs.plonk
    .fullProve(
      input,
      "./circuits/Rollup_js/Rollup.wasm",
      "./circuits/Rollup.zkey"
    )
    .then(({ proof, publicSignals }) => {
      snarkjs.plonk
        .exportSolidityCallData(proof, publicSignals)
        .then((s) => console.log(s));
    });
});
