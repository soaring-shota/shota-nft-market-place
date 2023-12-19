async function main() {
  const ProxyAdminContract = await ethers.getContractFactory("ProxyAdmin");
  const ProxyAdminContractDeployed = await ProxyAdminContract.deploy();
  await ProxyAdminContractDeployed.waitForDeployment();
  console.log("deployed Proxy Admin contract address: ", ProxyAdminContractDeployed.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
