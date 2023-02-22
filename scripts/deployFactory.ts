import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const VTVLVestingFactory = await ethers.getContractFactory(
    "VTVLVestingFactory"
  );
  const vestingFactoryContract = await VTVLVestingFactory.deploy();
  console.log(
    `vestingFactoryContract initialized on ${vestingFactoryContract.address}, waiting to be deployed...`
  );
  await vestingFactoryContract.deployed();
  console.log(
    "Deployed a vesting contract to:",
    vestingFactoryContract.address
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
