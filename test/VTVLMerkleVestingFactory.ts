import { expect } from "chai";
import { ethers, network } from "hardhat";
import Chance from "chance";
import { BigNumber } from "ethers";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";
import VestingJson from "../vesting.json";
import {
  VTVLMerkleVesting,
  VTVLMerkleVestingFactory,
} from "../typechain-types";
import { ClaimInputStruct } from "../typechain-types/contracts/merkleVesting/VTVLMerkelVesting";

const VaultFactoryJson = require("../artifacts/contracts/VTVLMerkleVestingFactory.sol/VTVLMerkleVestingFactory.json");

const iface = new ethers.utils.Interface(VaultFactoryJson.abi);

const chance = new Chance(43153); // Make sure we have a predictable seed for repeatability
const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const INCH_ADDRESS = "0x111111111117dc0aa78b770fa6a738034120c302";
const USDC_IMPERSONATE_ACCOUNT = "0xf3B0073E3a7F747C7A38B36B805247B222C302A3";
const INCH_IMPERSONATE_ACCOUNT = "0x3744da57184575064838bbc87a0fc791f5e39ea2";
const initialSupplyTokens = 1000;

const tokenName = chance.string({ length: 10 });
const tokenSymbol = chance.string({ length: 3 }).toUpperCase();

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

  // (3)
  console.log("Merkle Root:", tree.root);

  // (4)
  fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));
}

function getMkerkleProof(recipient: string) {
  const tree = StandardMerkleTree.load(
    JSON.parse(fs.readFileSync("tree.json", "utf8"))
  );

  for (const [i, v] of tree.entries()) {
    if (v[7].toLowerCase() === recipient.toLowerCase()) {
      const proof = tree.getProof(i);
      console.log("Proof:", proof);
      return proof;
    }
  }
  return [];
}

function getMkerkleRoot() {
  const tree = StandardMerkleTree.load(
    JSON.parse(fs.readFileSync("tree.json", "utf8"))
  );
  return tree.root;
}

/**
 * Get the created vault address from the transaction
 * @returns vault address
 */
function getParamFromEvent(
  transaction: any,
  eventName: string,
  paramIndex: number
) {
  const logs = transaction.logs.filter((l: any) =>
    l.topics.includes(ethers.utils.id(eventName))
  );
  const event = iface.parseLog(logs[0]);
  return event.args[paramIndex];
}

const randomAddress = async () => {
  return await ethers.Wallet.createRandom().getAddress();
};

const getLastBlockTs = async () => {
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const timestampBefore = await getBlockTs(blockNumBefore);
  return timestampBefore;
};

const getBlockTs = async (blockNumber: number) => {
  const blockBefore = await ethers.provider.getBlock(blockNumber);
  const timestampBefore = blockBefore.timestamp;
  return timestampBefore;
};

const createContractFactory = async () =>
  await ethers.getContractFactory("VTVLMerkleVestingFactory");

let factoryContract: VTVLMerkleVestingFactory;

const deployVestingContract = async (tokenAddress: string) => {
  const factory = await createContractFactory();
  factoryContract = await factory.deploy();
  await factoryContract.deployed();

  const transaction = await factoryContract.createVestingContract(
    tokenAddress ?? (await randomAddress()),
    0
  );

  const vestingContractAddress = getParamFromEvent(
    await transaction.wait(),
    "CreateVestingContract(address,address)",
    0
  );

  // TODO: check if we need any checks that the token be valid, etc
  const VestingContract = await ethers.getContractFactory("VTVLMerkleVesting");
  const contract = await VestingContract.attach(vestingContractAddress);
  return contract;
};

const dateToTs = (date: Date | string) =>
  ethers.BigNumber.from(
    Math.floor((date instanceof Date ? date : new Date(date)).getTime() / 1000)
  );

const createPrefundedVestingContract = async (props: {
  tokenName: string;
  tokenSymbol: string;
  initialSupplyTokens: number;
}) => {
  const { tokenName, tokenSymbol, initialSupplyTokens } = props;

  // Create an example token
  const tokenContractFactory = await ethers.getContractFactory(
    "TestERC20Token"
  );
  // const initialSupply = ethers.utils.parseUnits(initialSupplyTokens.toString(), decimals);
  const initialSupply = BigNumber.from(initialSupplyTokens); // The contract is already multiplying by decimals
  const tokenContract = await tokenContractFactory.deploy(
    tokenName,
    tokenSymbol,
    initialSupply
  );

  // Create an example vesting contract
  const vestingContract = await deployVestingContract(tokenContract.address);
  await vestingContract.deployed();

  expect(await vestingContract.tokenAddress()).to.be.equal(
    tokenContract.address
  );

  // Fund the vesting contract - transfer everything to the vesting contract (from the user)
  await tokenContract.transfer(
    vestingContract.address,
    await tokenContract.totalSupply()
  );

  return { tokenContract, vestingContract };
};

type VestingContractType = VTVLMerkleVesting;

describe("Contract creation", async function () {
  let tokenAddress: string;

  before(async () => {
    // TODO: check if we need any checks that the token be valid, etc
  });

  it("can be created with a ERC20 token address", async function () {
    tokenAddress = await randomAddress();
    const contract = await deployVestingContract(tokenAddress);
    await contract.deployed();

    expect(await contract.tokenAddress()).to.equal(tokenAddress);
  });

  it("fails if initialized without a valid ERC20 token address", async function () {
    // TODO: check if we need any checks that the token be valid, etc
    const zeroAddressStr = "0x" + "0".repeat(40);
    const [owner] = await ethers.getSigners();

    const invalidParamsSets = [
      undefined,
      null,
      0,
      "0x0",
      "0x11",
      zeroAddressStr,
    ];

    for (const invalidParam of invalidParamsSets) {
      try {
        const factory = await ethers.getContractFactory("VTVLMerkleVesting");
        // @ts-ignore - Need to ignore invalid type because initializing with an invalid type is the whole point of this test
        const contractDeploymentPromise = factory.deploy(
          invalidParam as string,
          0,
          owner.address
        );

        if (invalidParam === zeroAddressStr) {
          await expect(contractDeploymentPromise).to.be.revertedWith(
            "INVALID_ADDRESS"
          );
        } else {
          try {
            await contractDeploymentPromise;
            expect(true).to.be.equal(
              false,
              `Invalid failure mode with argument ${invalidParam}.`
            );
          } catch (e) {
            // Correct failure mode
          }
        }
      } catch (e) {
        expect(true).to.be.equal(
          false,
          `Invalid failure mode with argument ${invalidParam}.`
        );
      }
    }
  });

  it("the deployer is the owner", async function () {
    const [owner] = await ethers.getSigners();
    tokenAddress = await randomAddress();

    const contract = await deployVestingContract(tokenAddress);

    expect(await contract.owner()).to.be.equal(owner.address);
  });
});

const claimInput: ClaimInputStruct = {
  recipient: VestingJson[0][7] as string,
  startTimestamp: VestingJson[0][0],
  endTimestamp: VestingJson[0][1],
  cliffReleaseTimestamp: VestingJson[0][2],
  releaseIntervalSecs: VestingJson[0][3],
  linearVestAmount: VestingJson[0][5],
  scheduleIndex: VestingJson[0][4],
  cliffAmount: VestingJson[0][6],
};

describe("Withdraw", async () => {
  // const recipientAddress = await randomAddress();
  const [, owner2] = await ethers.getSigners();
  it("disallow withdraw with wrong vesting information", async () => {
    const { tokenContract, vestingContract: claimCreateContractInstance } =
      await createPrefundedVestingContract({
        tokenName,
        tokenSymbol,
        initialSupplyTokens,
      });

    const initialBalance = await tokenContract.balanceOf(claimInput.recipient);

    await claimCreateContractInstance.setMerleRoot(getMkerkleRoot());
    const vestingContract = claimCreateContractInstance.connect(owner2);
    const proof = getMkerkleProof(claimInput.recipient);

    await ethers.provider.send("evm_mine", [
      BigNumber.from(BigNumber.from(claimInput.startTimestamp)).add(150),
    ]); // by now, we should've vested the cliff and one unlock interval

    await expect(
      vestingContract.withdraw({ ...claimInput, linearVestAmount: 23 }, proof)
    ).to.be.revertedWith("Invalid proof");
  });

  it("disallow withdraw with wrong recipient", async () => {
    const { tokenContract, vestingContract: claimCreateContractInstance } =
      await createPrefundedVestingContract({
        tokenName,
        tokenSymbol,
        initialSupplyTokens,
      });

    await claimCreateContractInstance.setMerleRoot(getMkerkleRoot());
    const vestingContract = claimCreateContractInstance.connect(owner2);
    const proof = getMkerkleProof(claimInput.recipient);

    await ethers.provider.send("evm_mine", [
      BigNumber.from(BigNumber.from(claimInput.startTimestamp)).add(150),
    ]); // by now, we should've vested the cliff and one unlock interval

    await expect(
      vestingContract.withdraw(
        { ...claimInput, recipient: owner2.address },
        proof
      )
    ).to.be.revertedWith("Invalid proof");
  });

  it("allows withdrawal up to the allowance and fails after the allowance is spent", async () => {
    const { tokenContract, vestingContract: claimCreateContractInstance } =
      await createPrefundedVestingContract({
        tokenName,
        tokenSymbol,
        initialSupplyTokens,
      });

    const initialBalance = await tokenContract.balanceOf(claimInput.recipient);

    await claimCreateContractInstance.setMerleRoot(getMkerkleRoot());
    await ethers.provider.send("evm_mine", [
      BigNumber.from(BigNumber.from(claimInput.startTimestamp)).sub(50),
    ]); // Make sure we're before the claim start
    const vestingContract = claimCreateContractInstance.connect(owner2);
    const proof = getMkerkleProof(claimInput.recipient);

    await expect(
      vestingContract.withdraw(claimInput, proof)
    ).to.be.revertedWith("NOTHING_TO_WITHDRAW");
    // await ethers.provider.send("evm_setNextBlockTimestamp", [1000])
    await ethers.provider.send("evm_mine", [
      BigNumber.from(claimInput.startTimestamp).add(15),
    ]); // by now, we should've vested the cliff and one unlock interval
    (await vestingContract.withdraw(claimInput, proof)).wait();
    const balanceAfterFirstWithdraw = await tokenContract.balanceOf(
      claimInput.recipient
    );
    // The cliff has vested plus 10% of the linear vest amount
    expect(balanceAfterFirstWithdraw).to.be.equal(
      initialBalance
        .add(claimInput.cliffAmount)
        .add(BigNumber.from(claimInput.linearVestAmount).mul(0.1))
    );
    await ethers.provider.send("evm_mine", [
      BigNumber.from(claimInput.startTimestamp).add(17),
    ]); // Fast forward until the moment nothign further has vested
    // Now we don't have anything to withdraw again - as we've withdrawn just before the last vest
    await expect(
      vestingContract.withdraw(claimInput, proof)
    ).to.be.revertedWith("NOTHING_TO_WITHDRAW");
    await ethers.provider.send("evm_mine", [
      BigNumber.from(claimInput.startTimestamp).add(25),
    ]); // mine another one
    await (await vestingContract.withdraw(claimInput, proof)).wait();
    const balanceAfterSecondWithdraw = await tokenContract.balanceOf(
      claimInput.recipient
    );
    // Expect to have 10% more after the last withdraw
    expect(balanceAfterSecondWithdraw).to.be.equal(
      balanceAfterFirstWithdraw.add(
        BigNumber.from(claimInput.linearVestAmount).mul(0.1)
      )
    );
  });

  it("withdraw the vested amount after revoke claim", async () => {
    const { vestingContract } = await createPrefundedVestingContract({
      tokenName,
      tokenSymbol,
      initialSupplyTokens,
    });
    await vestingContract.setMerleRoot(getMkerkleRoot());
    const timePass = 1000;
    await ethers.provider.send("evm_mine", [
      BigNumber.from(claimInput.startTimestamp).add(timePass),
    ]);
    // Revoke the claim, and try to withdraw afterwards
    const proof = getMkerkleProof(claimInput.recipient);
    const tx = await vestingContract.revokeClaim(claimInput, proof);
    await tx.wait();

    // Get `revokeClaim` transaction block timestamp
    const txTimestamp = await getBlockTs(tx.blockNumber!);

    // Expect the claimable amount after revoking
    const expectClaimableAmount = BigNumber.from(claimInput.linearVestAmount)
      .mul(
        BigNumber.from(txTimestamp).sub(
          BigNumber.from(BigNumber.from(claimInput.startTimestamp))
        )
      )
      .div(
        BigNumber.from(
          BigNumber.from(claimInput.endTimestamp).sub(
            BigNumber.from(claimInput.startTimestamp)
          )
        )
      );

    expect(await vestingContract.claimableAmount(claimInput)).to.be.equal(
      expectClaimableAmount
    );
  });
});

describe("Revoke Claim", async () => {
  it("allows admin to revoke a valid claim after withdraw", async () => {
    const { vestingContract } = await createPrefundedVestingContract({
      tokenName,
      tokenSymbol,
      initialSupplyTokens,
    });

    await vestingContract.setMerleRoot(getMkerkleRoot());
    const proof = getMkerkleProof(claimInput.recipient);
    await ethers.provider.send("evm_mine", [
      parseInt(claimInput.startTimestamp.toString()) + 1000,
    ]);
    expect(await vestingContract.withdraw(claimInput, proof)).to.be.reverted;
    (await vestingContract.revokeClaim(claimInput, proof)).wait();
    // Make sure it gets reverted
    expect(
      await await vestingContract.isRevoked(claimInput.recipient, 0)
    ).to.be.equal(true);
  });

  it("fails to revoke an invalid proof", async () => {
    const { vestingContract } = await createPrefundedVestingContract({
      tokenName,
      tokenSymbol,
      initialSupplyTokens,
    });
    const recipientAddress = await randomAddress();
    await vestingContract.setMerleRoot(getMkerkleRoot());
    const proof = getMkerkleProof(claimInput.recipient);

    await expect(
      vestingContract.revokeClaim(
        {
          ...claimInput,
          recipient: recipientAddress,
        },
        proof
      )
    ).to.be.revertedWith("Invalid proof");
  });
});

describe("Vested amount", async () => {
  let vestingContract: VestingContractType;
  // Default params
  // linearly Vest 10000, every 1s, between TS 1000 and 2000
  // additionally, cliff vests another 5000, at TS = 900

  before(async () => {
    const { vestingContract: _vc } = await createPrefundedVestingContract({
      tokenName,
      tokenSymbol,
      initialSupplyTokens,
    });
    vestingContract = _vc as VestingContractType;
    await vestingContract.setMerleRoot(getMkerkleRoot());
  });
  it("calculates the vested amount before the cliff time to be 0", async () => {
    expect(
      await vestingContract.vestedAmount(
        claimInput,
        BigNumber.from(claimInput.startTimestamp)
      )
    ).to.be.equal(0);
  });
  it("calculates the vested amount at the cliff time to be equal cliff amount", async () => {
    // Note: at exactly the cliff time, linear vested amount won't yet come in play as we're only at second 0
    expect(
      await vestingContract.vestedAmount(
        claimInput,
        claimInput.cliffReleaseTimestamp
      )
    ).to.be.equal(claimInput.cliffAmount);
  });
  it("correctly calculates the vested amount after the cliff time, but before the linear start time", async () => {
    await ethers.provider.send("evm_mine", [
      parseInt(claimInput.cliffReleaseTimestamp.toString()),
    ]);
    expect(
      await vestingContract.vestedAmount(
        claimInput,
        BigNumber.from(claimInput.cliffReleaseTimestamp).add(1)
      )
    ).to.be.equal(claimInput.cliffAmount);
    expect(
      await vestingContract.vestedAmount(
        claimInput,
        BigNumber.from(claimInput.startTimestamp).sub(1)
      )
    ).to.be.equal(claimInput.cliffAmount);
  });
  it("vests correctly if cliff and linear vesting begin are at the same time", async () => {
    const { vestingContract } = await createPrefundedVestingContract({
      tokenName,
      tokenSymbol,
      initialSupplyTokens,
    });
    await ethers.provider.send("evm_mine", [
      parseInt(claimInput.cliffReleaseTimestamp.toString()),
    ]);
    // at the start (shared start and cliff TS), we've vested exactly the cliff amount
    expect(
      await vestingContract.vestedAmount(
        claimInput,
        BigNumber.from(claimInput.startTimestamp)
      )
    ).to.be.equal(claimInput.cliffAmount);
    // Half the interval past, we've vested the cliff and half the linear amount
    expect(
      await vestingContract.vestedAmount(
        claimInput,
        BigNumber.from(claimInput.startTimestamp).add(500)
      )
    ).to.be.equal(
      BigNumber.from(claimInput.cliffAmount).mul(
        BigNumber.from(claimInput.linearVestAmount).div(2)
      )
    );
  });
  it("correctly calculates the vested amount at the linear start time", async () => {
    // We've just released the cliff at the first second
    await ethers.provider.send("evm_mine", [
      parseInt(claimInput.cliffReleaseTimestamp.toString()),
    ]);
    expect(
      await vestingContract.vestedAmount(
        claimInput,
        BigNumber.from(claimInput.startTimestamp)
      )
    ).to.be.equal(claimInput.cliffAmount);
  });
  it("correctly calculates the vested amount after the start", async () => {
    // We've just released the cliff at the first second
    const vestAmt = await vestingContract.vestedAmount(
      claimInput,
      BigNumber.from(claimInput.startTimestamp).add(1)
    );
    // 10% vested, ie 10 out of 10000, so add that to the cliff amound
    expect(vestAmt).to.be.equal(BigNumber.from(claimInput.cliffAmount).add(10));
  });
  [10, 25, 45, 50, 70, 80, 95].forEach((percentage) => {
    it(`correctly calculates the vested amount at ${percentage} of linear interval`, async () => {
      // Due to how our vesting is set up (length 1000, amount 10000), every 10*x a release of 100x should happen
      const vestAmt = await vestingContract.vestedAmount(
        claimInput,
        BigNumber.from(claimInput.startTimestamp).add(percentage * 10)
      );
      const expectedVestAmt = BigNumber.from(claimInput.cliffAmount).add(
        percentage * 100
      );
      expect(vestAmt).to.be.equal(expectedVestAmt);
    });
  });
  it("calculates the vested amount at the end of the linear interval to be the full amount allocated", async () => {
    // The full amount vested at the end
    expect(
      await vestingContract.vestedAmount(claimInput, claimInput.endTimestamp)
    ).to.be.equal(
      BigNumber.from(claimInput.cliffAmount).add(claimInput.linearVestAmount)
    );
  });
  it("doesn't vest further after the end of the linear interval", async () => {
    // Again the full amount even if we go a long way in the future
    expect(
      await vestingContract.vestedAmount(
        claimInput,
        BigNumber.from(claimInput.endTimestamp).add(100000000)
      )
    ).to.be.equal(
      BigNumber.from(claimInput.cliffAmount).add(claimInput.linearVestAmount)
    );
  });
  it("calculates the finalVestedAmount to be equal the total amount to be vested", async () => {
    expect(await vestingContract.finalVestedAmount(claimInput)).to.be.equal(
      BigNumber.from(claimInput.cliffAmount).add(claimInput.linearVestAmount)
    );
  });
  it("takes the release interval into account", async () => {
    const { vestingContract } = await createPrefundedVestingContract({
      tokenName,
      tokenSymbol,
      initialSupplyTokens,
    });
    // with a release of 500, we should have cliff amount at start timestamp, cliffamount + 0.5 * linearvest at 1500, and full amonunt at 2000
    const releaseIntervalSecs = 500;

    const vestedAtStart = await vestingContract.vestedAmount(
      claimInput,
      BigNumber.from(claimInput.startTimestamp)
    );
    expect(vestedAtStart).to.be.equal(claimInput.cliffAmount);
    // Just before the release interval gets triggered, we should still get just the cliff ts
    expect(
      await vestingContract.vestedAmount(
        claimInput,
        BigNumber.from(claimInput.startTimestamp).add(releaseIntervalSecs - 1)
      )
    ).to.be.equal(claimInput.cliffAmount);
    // at the release interval (release interval + 1 added, expect half of the linear vested amt)
    expect(
      await vestingContract.vestedAmount(
        claimInput,
        BigNumber.from(claimInput.startTimestamp).add(releaseIntervalSecs)
      )
    ).to.be.equal(
      BigNumber.from(claimInput.cliffAmount).add(
        BigNumber.from(claimInput.linearVestAmount).div(2)
      )
    );
    // Expect everything at the end
    expect(
      await vestingContract.vestedAmount(claimInput, claimInput.endTimestamp)
    ).to.be.equal(
      BigNumber.from(claimInput.cliffAmount).add(claimInput.linearVestAmount)
    );
  });
});
describe("Claimable amount", async () => {
  const [, owner2] = await ethers.getSigners();
  // Default params - a bit different than those above
  // linearly Vest 10000, every 1s, between last block ts+100 and 1000 secs forward
  // No cliff
  const cliffReleaseTimestamp = BigNumber.from(0);
  const linearVestAmount = BigNumber.from(10000);
  const cliffAmount = BigNumber.from(0);
  const releaseIntervalSecs = BigNumber.from(1);
  it(`calculates the claimable amount to be equal to the vested amount if we have no withdrawals`, async () => {
    const startTimestamp = parseInt(claimInput.startTimestamp.toString());
    const endTimestamp = parseInt(claimInput.endTimestamp.toString());
    const { vestingContract } = await createPrefundedVestingContract({
      tokenName,
      tokenSymbol,
      initialSupplyTokens,
    });

    await vestingContract.setMerleRoot(getMkerkleRoot());
    // Try couple of different points, no matter where we are, it should be the same since we have no withdrawals
    for (let ts = startTimestamp; ts <= endTimestamp; ts += 100) {
      await ethers.provider.send("evm_mine", [ts]); // Make sure we're at the relevant ts
      const vestAmt = await vestingContract.vestedAmount(claimInput, ts);
      const claimableAmount = await vestingContract.claimableAmount(claimInput);
      expect(claimableAmount).to.be.equal(vestAmt);
    }
  });
  it("takes withdrawals into account when calculating the claimable amount", async () => {
    const startTimestamp = BigNumber.from(claimInput.startTimestamp);
    const endTimestamp = claimInput.endTimestamp;
    const { vestingContract } = await createPrefundedVestingContract({
      tokenName,
      tokenSymbol,
      initialSupplyTokens,
    });
    const proof = getMkerkleProof(claimInput.recipient);

    await vestingContract.setMerleRoot(getMkerkleRoot());

    const ts = startTimestamp.add(5000);
    await ethers.provider.send("evm_mine", [ts]); // Make sure we're at half of the interval
    // const amtFirstWithdraw = vestingContract.vestedAmount(owner2.address, ts);
    // second owner withdraws
    const tx = await vestingContract
      .connect(owner2)
      .withdraw(claimInput, proof);
    // TODO: fetch the withdraw amount in a better way
    const amtFirstWithdraw = (await tx.wait()).events?.[1]?.args
      ?._withdrawalAmount;
    // Nothing should be claimable
    expect(await vestingContract.claimableAmount(claimInput)).to.be.equal(0);
    // now wait a bit till the end of the interval for everything to get vested
    await ethers.provider.send("evm_mine", [endTimestamp]);
    // we expect the claimble be less than vested for the amt withdrawn
    const vestAmtEnd = await vestingContract.finalVestedAmount(claimInput);
    const expectedClaimable = vestAmtEnd.sub(amtFirstWithdraw);
    expect(await vestingContract.claimableAmount(claimInput)).to.be.equal(
      expectedClaimable
    );
  });
});
