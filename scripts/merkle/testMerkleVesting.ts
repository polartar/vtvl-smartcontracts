import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import { ethers } from "hardhat";
import fs from "fs";
import VestingJson from "./vesting";
import { ClaimInputStruct } from "../../typechain-types/contracts/merkleVesting/VTVLMerkelVesting";
import csvToJson from "csvtojson";

async function generateMerkleTree() {
  let whitelist = await csvToJson({
    trim: true,
  }).fromFile("./scripts/merkle/vesting.csv");

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
  // console.log("root", getMerkleRoot());
  const VTVLVesting = await ethers.getContractFactory("VTVLMerkleVesting");
  const vestingContract = await VTVLVesting.attach(
    "0xc271F1FE7779F982FE582B979B274c9945c5D41c"
  );

  console.log(getMerkleRoot());
  try {
    const claimableAmount = await vestingContract.claimableAmount(
      claimInputs[0]
    );
    console.log({ claimableAmount });

    const proof = getMerkleProof(
      claimInputs[0].recipient,
      claimInputs[0].scheduleIndex as number
    );
    console.log({ proof });

    await vestingContract.withdraw(claimInputs[2], proof);
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
