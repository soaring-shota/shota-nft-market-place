require('dotenv').config();
const { 
  BASE_URI, 
  MINT_FEE, 
  FEE_RECIPIENT,
  COLLECTION_FEE 
} = process.env;
const { ethers } = require("hardhat");

async function main() {
  const mintFee = ethers.parseEther(MINT_FEE);
  const collectionFee = ethers.parseEther(COLLECTION_FEE);

  const AlivelandERC1155Factory = await ethers.getContractFactory("AlivelandERC1155Factory");
  const AlivelandERC1155FactoryDeployed = await AlivelandERC1155Factory.deploy(
    BASE_URI,
    mintFee,
    collectionFee,
    FEE_RECIPIENT
  );
  await AlivelandERC1155FactoryDeployed.waitForDeployment();
  console.log("deployed Aliveland ERC-1155 token factory contract address: ", AlivelandERC1155FactoryDeployed.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
