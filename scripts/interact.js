require('dotenv').config();
const { 
  FEE_RECIPIENT,
  DEPLOYER_ADDRESS, 
  BASE_URI, 
  MINT_FEE, 
  COLLECTION_FEE,
  FACTORY721_ADDRESS,
  FACTORY1155_ADDRESS,
} = process.env;
const { ethers } = require('hardhat');

async function main() {
    const AlivelandERC721Factory = await ethers.getContractFactory("AlivelandERC721Factory");
    const erc721FactoryContract = AlivelandERC721Factory.attach(FACTORY721_ADDRESS);
    await erc721FactoryContract.updateMintFee(ethers.parseEther(MINT_FEE));
    await erc721FactoryContract.updatePlatformFee(ethers.parseEther(COLLECTION_FEE));

    const AlivelandERC1155Factory = await ethers.getContractFactory("AlivelandERC1155Factory");
    const erc1155FactoryContract = AlivelandERC1155Factory.attach(FACTORY1155_ADDRESS);
    await erc1155FactoryContract.updateMintFee(ethers.parseEther(MINT_FEE));
    await erc1155FactoryContract.updatePlatformFee(ethers.parseEther(COLLECTION_FEE));

    console.log('finished');

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
  