import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import { ethers } from "hardhat";
import fs from "fs";
import VestingJson from "./vesting";
import { ClaimInputStruct } from "../../typechain-types/contracts/merkleVesting/VTVLMerkelVesting";
const hre = require("hardhat");

function generateMerkleTree() {
  const tree = StandardMerkleTree.of(VestingJson, [
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

function getMerkleProof(recipient: string, scheduleIndex = 0) {
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

const claimInputs: ClaimInputStruct[] = VestingJson.map((vesting) => ({
  recipient: vesting[7] as string,
  startTimestamp: vesting[0],
  endTimestamp: vesting[1],
  cliffReleaseTimestamp: vesting[2],
  releaseIntervalSecs: vesting[3],
  linearVestAmount: vesting[5],
  scheduleIndex: vesting[4],
  cliffAmount: vesting[6],
}));

async function main() {
  // We get the contract to deploy
  // generateMerkleTree();
  console.log("root", getMerkleRoot());
  const VTVLVesting = await ethers.getContractFactory("VTVLMerkleVesting");
  const vestingContract = await VTVLVesting.attach(
    "0xa19B41735522f69cc7Af0819f2911d8b2cc99A30"
  );
  console.log("Vesting address: ", vestingContract.address);
  console.log(claimInputs[0]);
  try {
    const claimableAmount = await vestingContract.claimableAmount(
      claimInputs[0]
    );
    console.log({ claimableAmount });

    const proof = getMerkleProof(claimInputs[0].recipient);
    console.log({ proof });

    await vestingContract.withdraw(claimInputs[0], proof);
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
