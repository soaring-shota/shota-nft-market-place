require('dotenv').config();
const { 
  FACTORY721_ADDRESS,
  PROXY_ADMIN,
} = process.env;
const { ethers } = require("hardhat");

async function main() {
  const TransparentUpgradeableProxyContract = await ethers.getContractFactory("TransparentUpgradeableProxy");
  const TransparentUpgradeableProxyContractDeployed = await TransparentUpgradeableProxyContract.deploy(
    FACTORY721_ADDRESS,
    PROXY_ADMIN,
    new Uint8Array([])
  );
  await TransparentUpgradeableProxyContractDeployed.waitForDeployment();
  console.log("deployed factory721 Proxy contract address: ", TransparentUpgradeableProxyContractDeployed.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
