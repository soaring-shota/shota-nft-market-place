require('dotenv').config();
const { ethers }  = require("hardhat");
const { BASE_URI, MINT_FEE, FEE_RECIPIENT } = process.env;

async function main() {
  const mintFee = ethers.parseEther(MINT_FEE);

  const AlivelandNFTContract = await ethers.getContractFactory("AlivelandERC1155");
  const AlivelandNFTContractDeployed = await AlivelandNFTContract.deploy(
    BASE_URI,
    mintFee,
    FEE_RECIPIENT
  );

  await AlivelandNFTContractDeployed.waitForDeployment();

  console.log("deployed Aliveland NFT(erc-1155) contract address: ", AlivelandNFTContractDeployed.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
