const { ethers } = require("hardhat");
const hre = require("hardhat");

async function main() {
  // We get the contract to deploy
  const VTVLVestingFactory = await ethers.getContractFactory(
    "VTVLVestingFactory"
  );
  const vestingFactoryContract = await VTVLVestingFactory.deploy();
  console.log(
    `vestingFactoryContract initialized on ${vestingFactoryContract.address}, waiting to be deployed...`
  );
  const tx = await vestingFactoryContract.deployed();
  console.log(
    "Deployed a vesting contract to:",
    vestingFactoryContract.address
  );

  await tx.deployTransaction.wait();

  await hre.run("verify:verify", {
    address: vestingFactoryContract.address,
    contract: "contracts/VTVLVestingFactory.sol:VTVLVestingFactory",
    constructorArguments: [],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
