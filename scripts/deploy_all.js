require('dotenv').config();
const { 
  FEE_RECIPIENT,
  DEPLOYER_ADDRESS, 
  BASE_URI, 
  MINT_FEE, 
  PLATFORM_FEE, 
  COLLECTION_FEE 
} = process.env;
const { ethers } = require('hardhat');

async function main() {
  const mintFee = ethers.parseEther(MINT_FEE);
  const collectionFee = ethers.parseEther(COLLECTION_FEE);

  ///////////////////////////Marketplace Contract////////////////////////////
  const AlivelandMarketplace = await ethers.getContractFactory('AlivelandMarketplace');
  const AlivelandMarketplaceDeployed = await AlivelandMarketplace.deploy();
  await AlivelandMarketplaceDeployed.waitForDeployment();
  console.log("deployed Aliveland marketplace contract address: ", AlivelandMarketplaceDeployed.target);
  await AlivelandMarketplaceDeployed.initialize(FEE_RECIPIENT, PLATFORM_FEE);
  console.log('Marketplace contract was initialized');

	///////////////////////////Auction Contract////////////////////////////
	const AlivelandAuction = await ethers.getContractFactory('AlivelandAuction');
  const AlivelandAuctionDeployed = await AlivelandAuction.deploy();
  await AlivelandAuctionDeployed.waitForDeployment();
  console.log("deployed Aliveland auction contract address: ", AlivelandAuctionDeployed.target);
  await AlivelandAuctionDeployed.initialize(FEE_RECIPIENT);
  console.log('Auction contract was initialized');

	///////////////////////////TokenRegistry Contract////////////////////////////
	const AlivelandTokenRegistry = await ethers.getContractFactory('AlivelandTokenRegistry');
  const AlivelandTokenRegistryDeployed = await AlivelandTokenRegistry.deploy();
  await AlivelandTokenRegistryDeployed.waitForDeployment();
  console.log("deployed Aliveland token registry contract address: ", AlivelandTokenRegistryDeployed.target);

	///////////////////////////AddressRegistry Contract////////////////////////////
	const AlivelandAddressRegistry = await ethers.getContractFactory('AlivelandAddressRegistry');
  const AlivelandAddressRegistryDeployed = await AlivelandAddressRegistry.deploy();
  await AlivelandAddressRegistryDeployed.waitForDeployment();
  console.log("deployed Aliveland address registry contract address: ", AlivelandAddressRegistryDeployed.target);
	const ALIVELAND_ADDRESS_REGISTRY = AlivelandAddressRegistryDeployed.target;
	
  ///////////////////////////ERC721 Token Contract////////////////////////////
  // const AlivelandERC721 = await ethers.getContractFactory("AlivelandERC721");
  // const AlivelandERC721Deployed = await AlivelandERC721.deploy(
  //   "Aliveland NFT",
  //   "ALNFT",
  //   BASE_URI,
  //   "ipfs://metadata",
  //   mintFee,
  //   FEE_RECIPIENT,
  //   DEPLOYER_ADDRESS
  // );
  // await AlivelandERC721Deployed.waitForDeployment();
  // console.log("deployed Aliveland NFT(erc-721) contract address: ", AlivelandERC721Deployed.target);

  ///////////////////////////ERC1155 Token Contract////////////////////////////
  // const AlivelandERC1155 = await ethers.getContractFactory("AlivelandERC1155");
  // const AlivelandERC1155Deployed = await AlivelandERC1155.deploy(
  //   "Aliveland NFT",
  //   "ALNFT",
  //   BASE_URI,
  //   "ipfs://metadata",
  //   mintFee,
  //   FEE_RECIPIENT,
  //   DEPLOYER_ADDRESS
  // );
  // await AlivelandERC1155Deployed.waitForDeployment();
  // console.log("deployed Aliveland NFT(erc-1155) contract address: ", AlivelandERC1155Deployed.target);

  ///////////////////////////ERC-721 Factory Contract////////////////////////////
  const AlivelandERC721Factory = await ethers.getContractFactory("AlivelandERC721Factory");
  const AlivelandERC721FactoryDeployed = await AlivelandERC721Factory.deploy(
    BASE_URI,
    mintFee,
    collectionFee,
    FEE_RECIPIENT
  );
  await AlivelandERC721FactoryDeployed.waitForDeployment();
  console.log("deployed Aliveland ERC-721 token factory contract address: ", AlivelandERC721FactoryDeployed.target);

  ///////////////////////////ERC-1155 Factory Contract////////////////////////////
  const AlivelandERC1155Factory = await ethers.getContractFactory("AlivelandERC1155Factory");
  const AlivelandERC1155FactoryDeployed = await AlivelandERC1155Factory.deploy(
    BASE_URI,
    mintFee,
    collectionFee,
    FEE_RECIPIENT
  );
  await AlivelandERC1155FactoryDeployed.waitForDeployment();
  console.log("deployed Aliveland ERC-1155 token factory contract address: ", AlivelandERC1155FactoryDeployed.target);

	///////////////////////////Updating Contract Address////////////////////////////
	await AlivelandMarketplaceDeployed.updateAddressRegistry(ALIVELAND_ADDRESS_REGISTRY);	
	await AlivelandAuctionDeployed.updateAddressRegistry(ALIVELAND_ADDRESS_REGISTRY);
	
	await AlivelandAddressRegistryDeployed.updateAuction(AlivelandAuctionDeployed.target);
	await AlivelandAddressRegistryDeployed.updateMarketplace(AlivelandMarketplaceDeployed.target);
	await AlivelandAddressRegistryDeployed.updateERC721Factory(AlivelandERC721FactoryDeployed.target);
	await AlivelandAddressRegistryDeployed.updateERC1155Factory(AlivelandERC1155FactoryDeployed.target);
	await AlivelandAddressRegistryDeployed.updateTokenRegistry(AlivelandTokenRegistryDeployed.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
