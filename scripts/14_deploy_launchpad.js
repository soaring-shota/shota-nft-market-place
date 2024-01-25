require("dotenv").config();
const { AUCTION_ADDRESS, PROXY_ADMIN } = process.env;
const { ethers } = require("hardhat");

async function main() {
  const LaunchpadERC721 = await ethers.getContractFactory("LaunchpadERC721");
  const LaunchpadERC721Deployed = await LaunchpadERC721.deploy(
    "Pola", // name
    "POL", // symbol
    "https://ipfs.io/ipfs/QmeKBHcLuoHuTywmURt3LuVWG2tu1q9BDtaRjR5DDW7vq2", // token URI
    1706080955, // start time
    1711354986, // end time
    100, // price
    5000 // max supply
  );
  await LaunchpadERC721Deployed.waitForDeployment();
  console.log(
    "deployed launchpad ERC721 contract address: ",
    LaunchpadERC721Deployed.target
  );

  const LaunchpadSale = await ethers.getContractFactory("LaunchpadSale");
  const LaunchpadSaleDeployed = await LaunchpadSale.deploy(
    LaunchpadERC721Deployed.target
  );
  await LaunchpadSaleDeployed.waitForDeployment();
  console.log(
    "deployed launchpad sale contract address: ",
    LaunchpadSaleDeployed.target
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
