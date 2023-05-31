// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";
const hre = require("hardhat");

async function main() {
  const TestTokenFactory = await ethers.getContractFactory("TestERC20Token");
  const tokenContract = await TestTokenFactory.deploy(
    "VTVLDEV",
    "VTVL",
    parseEther("100")
  );
  console.log("Deploying...");
  const tx = await tokenContract.deployed();
  console.log("Deploye: ", tokenContract.address);
  await tx.deployTransaction.wait();

  // console.log("Address:", tokenContract.address);

  await hre.run("verify:verify", {
    address: "0x6c94905412d7cfb55692d7028c37c64f14c3d38a",
    contract: "contracts/VTVLVesting.sol:VTVLVesting",
    constructorArguments: ["0x5196D52815488271937d0eDaE53a3855A5615597"],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
