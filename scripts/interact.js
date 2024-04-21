require('dotenv').config();
const { 
  FEE_RECIPIENT,
  DEPLOYER_ADDRESS, 
  BASE_URI, 
  MINT_FEE, 
  COLLECTION_FEE,
  FACTORY721_ADDRESS,
  FACTORY1155_ADDRESS,
  MARKETPLACE_ADDRESS,
} = process.env;
const { ethers } = require('hardhat');

async function main() {
    // const AlivelandERC721Factory = await ethers.getContractFactory("AlivelandERC721Factory");
    // const erc721FactoryContract = AlivelandERC721Factory.attach(FACTORY721_ADDRESS);
    // await erc721FactoryContract.updateMintFee(ethers.parseEther(MINT_FEE));
    // await erc721FactoryContract.updatePlatformFee(ethers.parseEther(COLLECTION_FEE));

    // const AlivelandERC1155Factory = await ethers.getContractFactory("AlivelandERC1155Factory");
    // const erc1155FactoryContract = AlivelandERC1155Factory.attach(FACTORY1155_ADDRESS);
    // await erc1155FactoryContract.updateMintFee(ethers.parseEther(MINT_FEE));
    // await erc1155FactoryContract.updatePlatformFee(ethers.parseEther(COLLECTION_FEE));

    // console.log('finished');

    // const fac = await ethers.getContractFactory("ProxyAdmin");
    // const contract = fac.attach("0xCffc045e3D657725b61ddc8EC1322cFa33151b0F");
    // const result = await contract.getProxyImplementation("0x0e1D36915aBCaf7B5E944B67Bb29e0fF6aFDC839");
    // console.log('result', result);
    // const fac1 = await ethers.getContractFactory("AlivelandERC721Factory");
    // const contract1 = fac1.attach("0x0171dD6e8a572A3515A014cd2eE946738e113638")
    // const result = await contract1.baseURI();
    // console.log('rrr', result);

    // const AlivelandERC721Factory = await ethers.getContractFactory("AlivelandERC721Factory");
    // const erc721FactoryContract = AlivelandERC721Factory.attach(FACTORY721_ADDRESS);
    // const result = await erc721FactoryContract.updateBaseURI("https://ipfs.io/ipfs/");
    // console.log('xxxxxxxxxx', result);

  // const marketplaceFac = await ethers.getContractFactory("AlivelandMarketplace")
  // const marketplaceContract = marketplaceFac.attach("0x3c72726672133F10ff0Ed6ce2a74c2c684a7A541");
  // const result = await marketplaceContract.owner();
  // // const result = await marketplaceContract.updateAddressRegistry("0x9D51433fbBb6bC2A0D74B6A7188373fCb53c57d0");
  // console.log('xxxxxxxxxx', result);

  // const tokenRegistryFactory = await ethers.getContractFactory("AlivelandTokenRegistry");
  // const tokenRegistryContract = tokenRegistryFactory.attach("0x93BF31E2Ff7D9Ab66ED144f025b4CB42245112f9");
  // const result = await tokenRegistryContract.add("0x0000000000000000000000000000000000001010");
  // console.log('xxxx', result);

  const addressRegistryFactory = await ethers.getContractFactory("AlivelandAddressRegistry");
  const addressRegistryContract = addressRegistryFactory.attach("0x9D51433fbBb6bC2A0D74B6A7188373fCb53c57d0");
  const result = await addressRegistryContract.updateMarketplace(MARKETPLACE_ADDRESS);
  console.log(result);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
  