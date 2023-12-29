require('dotenv').config();
const { 
  FEE_RECIPIENT, 
} = process.env;

async function main() {
  const AlivelandAuction = await ethers.getContractFactory('AlivelandAuction');
  const AlivelandAuctionDeployed = await AlivelandAuction.deploy();
  await AlivelandAuctionDeployed.waitForDeployment();
  console.log("deployed Aliveland auction contract address: ", AlivelandAuctionDeployed.target);
  
  await AlivelandAuctionDeployed.initialize(FEE_RECIPIENT);
  console.log('Auction contract was initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
