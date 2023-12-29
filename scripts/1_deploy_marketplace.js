require('dotenv').config();
const { 
  FEE_RECIPIENT, 
  PLATFORM_FEE, 
} = process.env;

async function main() {
  const AlivelandMarketplace = await ethers.getContractFactory('AlivelandMarketplace');
  const AlivelandMarketplaceDeployed = await AlivelandMarketplace.deploy();
  await AlivelandMarketplaceDeployed.waitForDeployment();
  console.log("deployed Aliveland marketplace contract address: ", AlivelandMarketplaceDeployed.target);
  
  await AlivelandMarketplaceDeployed.initialize(FEE_RECIPIENT, PLATFORM_FEE);
  console.log('Marketplace contract was initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
