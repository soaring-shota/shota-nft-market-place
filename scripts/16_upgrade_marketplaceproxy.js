require('dotenv').config();
const { 
  MARKETPLACE_ADDRESS,
  MARKETPLACE_PROXY,
  PROXY_ADMIN,
  ADDRESS_REGISTRY,
  FEE_RECIPIENT,
  PLATFORM_FEE, 
} = process.env;
const { ethers, upgrades } = require("hardhat");

async function main() {
  const AlivelandMarketplace = await ethers.getContractFactory('AlivelandMarketplace');
  const AlivelandMarketplaceDeployed = await AlivelandMarketplace.deploy();
  await AlivelandMarketplaceDeployed.waitForDeployment();
  console.log("deployed Aliveland marketplace contract address: ", AlivelandMarketplaceDeployed.target);
  
  await AlivelandMarketplaceDeployed.initialize(FEE_RECIPIENT, PLATFORM_FEE);
  console.log('Marketplace contract was initialized');

  await AlivelandMarketplaceDeployed.updateAddressRegistry(ADDRESS_REGISTRY);
  console.log('Address registry changed');
  // Get proxy admin contract instance
  const ProxyAdmin = await ethers.getContractFactory("ProxyAdmin");
  const proxyAdmin = ProxyAdmin.attach(PROXY_ADMIN);

  // Upgrade the implementation through the proxy admin
  console.log(`Upgrading proxy at ${MARKETPLACE_PROXY} to new implementation...`);
  const upgradeTx = await proxyAdmin.upgrade(MARKETPLACE_PROXY, AlivelandMarketplaceDeployed.target);
  await upgradeTx.wait();

  console.log("Upgrade complete.");

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
