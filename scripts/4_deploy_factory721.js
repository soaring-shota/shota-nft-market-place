require('dotenv').config();
const { 
  BASE_URI, 
  MINT_FEE, 
  FEE_RECIPIENT,  
  COLLECTION_FEE 
} = process.env;
const { ethers } = require('hardhat');

async function main() {
  const mintFee = ethers.parseEther(MINT_FEE);
  const collectionFee = ethers.parseEther(COLLECTION_FEE);

  const AlivelandERC721Factory = await ethers.getContractFactory("AlivelandERC721Factory");
  const AlivelandERC721FactoryDeployed = await AlivelandERC721Factory.deploy(
    BASE_URI,
    mintFee,
    collectionFee,
    FEE_RECIPIENT
  );
  await AlivelandERC721FactoryDeployed.waitForDeployment();
  console.log("deployed Aliveland ERC-721 token factory contract address: ", AlivelandERC721FactoryDeployed.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
