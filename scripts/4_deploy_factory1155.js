require('dotenv').config();
const { ethers }  = require("hardhat");
const { BASE_URI, MINT_FEE, FEE_RECIPIENT, PLATFORM_FEE, AUCTION_ADDRESS, MARKETPLACE_ADDRESS } = process.env;

async function main() {
  const mintFee = ethers.parseEther(MINT_FEE);
  const platformFee = ethers.parseEther(PLATFORM_FEE);

  const AlivelandERC1155Factory = await ethers.getContractFactory("AlivelandERC1155Factory");
  const AlivelandERC1155FactoryDeployed = await AlivelandERC1155Factory.deploy(
    MARKETPLACE_ADDRESS,
    BASE_URI,
    mintFee,
    platformFee,
    FEE_RECIPIENT
  );
  await AlivelandERC1155FactoryDeployed.waitForDeployment();
  console.log("deployed Aliveland ERC-1155 token factory contract address: ", AlivelandERC1155FactoryDeployed.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
