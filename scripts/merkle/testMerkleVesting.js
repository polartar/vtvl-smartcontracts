const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const { ethers } = require("hardhat");
const fs = require("fs");

const csvToJson = require("csvtojson");
const { parseEther } = require("ethers/lib/utils");

const startTime = Math.floor(new Date().getTime() / 1000);
const endTime = startTime + 1000;
const releaseFrequency = 10;

async function generateMerkleTree() {
  let whitelist = await csvToJson({
    trim: true,
  }).fromFile("./scripts/merkle/vesting.csv");

  const vestings = whitelist.map((list) => [
    startTime,
    endTime,
    startTime,
    releaseFrequency,
    0,
    parseEther(list.allocation),
    0,
    list.address,
  ]);
  const tree = StandardMerkleTree.of(vestings, [
    "uint40",
    "uint40",
    "uint40",
    "uint40",
    "uint40",
    "uint256",
    "uint256",
    "address",
  ]);

  fs.writeFileSync("./scripts/merkle/tree.json", JSON.stringify(tree.dump()));
}

function getMerkleRoot() {
  const tree = StandardMerkleTree.load(
    JSON.parse(fs.readFileSync("./scripts/merkle/tree.json", "utf8"))
  );
  return tree.root;
}

function getMerkleProof(recipient, scheduleIndex = 0) {
  const tree = StandardMerkleTree.load(
    JSON.parse(fs.readFileSync("./scripts/merkle/tree.json", "utf8"))
  );

  let index = 0;
  for (const [i, v] of tree.entries()) {
    if (v[7].toLowerCase() === recipient.toLowerCase()) {
      const proof = tree.getProof(i);
      if (index === scheduleIndex) return proof;
      index++;
    }
  }
  return [];
}

async function main() {
  // We get the contract to deploy
  generateMerkleTree();
  const [deployer] = await ethers.getSigners();
  const root = getMerkleRoot();

  const VTVLVesting = await ethers.getContractFactory("VTVLMerkleVesting");
  const vestingContract = await VTVLVesting.attach(
    "0xaA753c29E42cb37C165a2116B02501d0C50bf521"
  );
  const feeData = await deployer.provider.getFeeData();
  const nonce = await deployer.getTransactionCount();
  await vestingContract.setMerleRoot(root, {
    nonce: nonce,
    maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
    maxFeePerGas: feeData.maxFeePerGas * 2,
  });

  console.log({ root });

  let whitelist = await csvToJson({
    trim: true,
  }).fromFile("./scripts/merkle/vesting.csv");

  const vestings = whitelist.map((list) => [
    startTime,
    endTime,
    startTime,
    releaseFrequency,
    0,
    parseEther(list.allocation),
    0,
    list.address,
  ]);

  const claimInputs = vestings.map((vesting) => ({
    recipient: vesting[7],
    startTimestamp: vesting[0],
    endTimestamp: vesting[1],
    cliffReleaseTimestamp: vesting[2],
    releaseIntervalSecs: vesting[3],
    linearVestAmount: vesting[5],
    scheduleIndex: vesting[4],
    cliffAmount: vesting[6],
  }));

  try {
    const claimableAmount = await vestingContract.claimableAmount(
      claimInputs[0]
    );
    console.log({ claimableAmount });

    const proof = getMerkleProof(
      claimInputs[0].recipient,
      claimInputs[0].scheduleIndex
    );
    console.log({ proof });

    // await vestingContract.withdraw(claimInputs[2], proof);
  } catch (err) {
    console.log(err);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
