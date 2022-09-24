const MerkleTree = require("fixed-merkle-tree");
const snarkjs = require("snarkjs");
const { mimc } = require("./mimc");

const LEVELS = 2;
// TODO: per the contract, these leaves must be set to the apprioprate zero if needed
const LEAVES = [
  [982574409541258509042542689523372698064870854576n, 100],
  [649562641434947955654834859981556155081347864431n, 100],
  [649562641434947955654834859981556155081347864431n, 250],
  [649562641434947955654834859981556155081347864431n, 100],
];

const BALANCES = [
  [982574409541258509042542689523372698064870854576n, 100],
  [649562641434947955654834859981556155081347864431n, 450],
  [649562641434947955654834859981556155081347864431n, 0],
  [649562641434947955654834859981556155081347864431n, 0],
];

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const getPathsEvents = async () => {
  await sleep(500);

  const hashedLeaves = LEAVES.map(([address, value]) =>
    mimc.hash(address, value)
  );

  const merkleTree = new MerkleTree.MerkleTree(LEVELS, hashedLeaves, {
    hashFunction: mimc.hash,
  });

  const paths = LEAVES.map((l, i) => merkleTree.path(i));

  const pathElementss = paths.map((x) => x.pathElements);
  const pathIndicess = paths.map((x) => x.pathIndices);
  return [merkleTree.root, pathElementss, pathIndicess];
};

const getPathsState = () => {
  const hashedLeaves = BALANCES.map(([address, value]) =>
    mimc.hash(address, value)
  );

  const merkleTree = new MerkleTree.MerkleTree(LEVELS, hashedLeaves, {
    hashFunction: mimc.hash,
  });

  const paths = BALANCES.map((b, i) => merkleTree.path(i));

  const pathElementss = paths.map((x) => x.pathElements);
  const pathIndicess = paths.map((x) => x.pathIndices);
  return [merkleTree.root, pathElementss, pathIndicess];
};

getPathsEvents().then(([eventRoot, eventPathElementss, eventPathIndicess]) => {
  const [stateRoot, statePathElementss, statePathIndicess] = getPathsState();

  const input = {
    eventRoot: eventRoot.toString(),
    stateRoot: stateRoot.toString(),
    eventAccounts: LEAVES.map((l) => l[0]),
    eventValues: LEAVES.map((l) => l[1]),
    eventPathElementss,
    eventPathIndicess,
    statePathElementss,
    statePathIndicess,
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
