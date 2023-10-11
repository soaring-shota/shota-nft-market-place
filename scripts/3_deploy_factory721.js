require('dotenv').config();
const { ethers }  = require("hardhat");
const { BASE_URI, MINT_FEE, FEE_RECIPIENT, PLATFORM_FEE, AUCTION_ADDRESS, MARKETPLACE_ADDRESS } = process.env;

async function main() {
  const mintFee = ethers.parseEther(MINT_FEE);
  const platformFee = ethers.parseEther(PLATFORM_FEE);

  const AlivelandERC721Factory = await ethers.getContractFactory("AlivelandERC721Factory");
  const AlivelandERC721FactoryDeployed = await AlivelandERC721Factory.deploy(
    AUCTION_ADDRESS,
    MARKETPLACE_ADDRESS,
    BASE_URI,
    mintFee,
    platformFee,
    FEE_RECIPIENT
  );
  await AlivelandERC721FactoryDeployed.waitForDeployment();
  console.log("deployed Aliveland ERC-721 token factory contract address: ", AlivelandERC721FactoryDeployed.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
