require('dotenv').config();
const { 
  AUCTION_ADDRESS,
  PROXY_ADMIN,
} = process.env;
const { ethers } = require("hardhat");

async function main() {
  const TransparentUpgradeableProxyContract = await ethers.getContractFactory("TransparentUpgradeableProxy");
  const TransparentUpgradeableProxyContractDeployed = await TransparentUpgradeableProxyContract.deploy(
    AUCTION_ADDRESS,
    PROXY_ADMIN,
    new Uint8Array([])
  );
  await TransparentUpgradeableProxyContractDeployed.waitForDeployment();
  console.log("deployed auction Proxy contract address: ", TransparentUpgradeableProxyContractDeployed.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
