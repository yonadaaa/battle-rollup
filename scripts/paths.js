const MerkleTree = require("fixed-merkle-tree");
const snarkjs = require("snarkjs");
const { mimc } = require("./mimc");

const LEVELS = 3;
const EVENT_ACCOUNTS = [
  982574409541258509042542689523372698064870854576n,
  649562641434947955654834859981556155081347864431n,
  980811066407722879624862203474661508049044519654n,
  649562641434947955654834859981556155081347864431n,
  0,
  0,
  0,
  0,
];
const EVENT_VALUES = [100, 75, 250, 50, 0, 0, 0, 0];

const BALANCES = EVENT_ACCOUNTS.map((a, i) => {
  const index = EVENT_ACCOUNTS.findIndex((e) => e === a);

  if (index === i) {
    return EVENT_VALUES.filter((_v, i) => EVENT_ACCOUNTS[i] === a).reduce(
      (partialSum, v) => partialSum + v,
      0
    );
  } else {
    return 0;
  }
});

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const getPaths = (leaves) => {
  const merkleTree = new MerkleTree.MerkleTree(LEVELS, leaves, {
    hashFunction: mimc.hash,
  });

  const paths = EVENT_ACCOUNTS.map((_a, i) => merkleTree.path(i));

  const pathElementss = paths.map((x) => x.pathElements);
  const pathIndicess = paths.map((x) => x.pathIndices);
  return [merkleTree.root, pathElementss, pathIndicess];
};

const generateInputs = async () => {
  await sleep(100);

  const [eventRoot, eventPathElementss, eventPathIndicess] = getPaths(
    EVENT_ACCOUNTS.map((account, i) => mimc.hash(account, EVENT_VALUES[i]))
  );
  const [stateRoot, statePathElementss, statePathIndicess] = getPaths(
    EVENT_ACCOUNTS.map((account, i) => [account, BALANCES[i]]).map(
      ([address, value]) => mimc.hash(address, value)
    )
  );

  return {
    eventRoot: eventRoot.toString(),
    stateRoot: stateRoot.toString(),
    eventAccounts: EVENT_ACCOUNTS,
    eventValues: EVENT_VALUES,
    eventPathElementss,
    eventPathIndicess,
    statePathElementss,
    statePathIndicess,
  };
};

generateInputs().then((input) => {
  console.log(input);

  snarkjs.plonk
    .fullProve(
      input,
      "./circuits/Rollup_js/Rollup.wasm",
      "./circuits/Rollup.zkey"
    )
    .then(({ proof, publicSignals }) =>
      snarkjs.plonk
        .exportSolidityCallData(proof, publicSignals)
        .then((s) => console.log(s))
    );
});
