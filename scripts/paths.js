const MerkleTree = require("fixed-merkle-tree");
const snarkjs = require("snarkjs");
const { mimc } = require("./mimc");

const LEVELS = 2;
const EVENT_ACCOUNTS = [
  982574409541258509042542689523372698064870854576n,
  649562641434947955654834859981556155081347864431n,
  980811066407722879624862203474661508049044519654n,
  649562641434947955654834859981556155081347864431n,
];
const EVENT_VALUES = [100, 75, 250, 50];
const LEAVES = [0, 1, 2, 3].map((i) => [EVENT_ACCOUNTS[i], EVENT_VALUES[i]]);

const balances = EVENT_ACCOUNTS.map((z) =>
  LEAVES.filter((l) => l[0] === z).reduce(
    (partialSum, l) => partialSum + l[1],
    0
  )
);

const BALANCES = [
  [EVENT_ACCOUNTS[0], balances[0]],
  [EVENT_ACCOUNTS[1], balances[1]],
  [EVENT_ACCOUNTS[2], balances[2]],
  [EVENT_ACCOUNTS[1], 0],
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

  const paths = [0, 1, 2, 3].map((i) => merkleTree.path(i));

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

  const paths = [0, 1, 2, 3].map((i) => merkleTree.path(i));

  const pathElementss = paths.map((x) => x.pathElements);
  const pathIndicess = paths.map((x) => x.pathIndices);
  return [merkleTree.root, pathElementss, pathIndicess];
};

getPathsEvents().then(([eventRoot, eventPathElementss, eventPathIndicess]) => {
  const [stateRoot, statePathElementss, statePathIndicess] = getPathsState();

  const input = {
    eventRoot: eventRoot.toString(),
    stateRoot: stateRoot.toString(),
    eventAccounts: EVENT_ACCOUNTS,
    eventValues: EVENT_VALUES,
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
