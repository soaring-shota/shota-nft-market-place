async function main() {
  const AlivelandAddressRegistry = await ethers.getContractFactory('AlivelandAddressRegistry');
  const AlivelandAddressRegistryDeployed = await AlivelandAddressRegistry.deploy();
  await AlivelandAddressRegistryDeployed.waitForDeployment();
  console.log("deployed Aliveland address registry contract address: ", AlivelandAddressRegistryDeployed.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
