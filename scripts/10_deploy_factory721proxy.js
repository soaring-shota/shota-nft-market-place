const { 
  FACTORY721_ADDRESS,
  PROXY_ADMIN,
} = require('./constants');
const { ethers } = require("hardhat");

async function main() {
  const TransparentUpgradeableProxyContract = await ethers.getContractFactory("TransparentUpgradeableProxy");
  const TransparentUpgradeableProxyContractDeployed = await TransparentUpgradeableProxyContract.deploy(
    FACTORY721_ADDRESS,
    PROXY_ADMIN,
    new Uint8Array([])
  );
  await TransparentUpgradeableProxyContractDeployed.waitForDeployment();
  console.log("deployed Upgradeable Proxy contract address: ", TransparentUpgradeableProxyContractDeployed.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
