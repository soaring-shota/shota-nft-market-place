async function main() {
  const AlivelandTokenRegistry = await ethers.getContractFactory('AlivelandTokenRegistry');
  const AlivelandTokenRegistryDeployed = await AlivelandTokenRegistry.deploy();
  await AlivelandTokenRegistryDeployed.waitForDeployment();
  console.log("deployed Aliveland token registry contract address: ", AlivelandTokenRegistryDeployed.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
