const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Aliveland ERC-1155 NFT Contract", async () => {
  const mintFee = ethers.parseEther("1");
  const mintFee3 = ethers.parseEther("3");
  const mintFee7 = ethers.parseEther("7");

  async function deployTokenFixture() {
    const [owner, feeRecipient] = await ethers.getSigners();

    const AlivelandNFT = await ethers.deployContract(
      "AlivelandERC1155",
      [
        "Aliveland NFT",
        "ALNFT",
        "ipfs",
        "ipfs://metadata",
        mintFee,
        feeRecipient.address,
        owner
      ]
    );

    return { AlivelandNFT, owner, feeRecipient };
  }

  it("Should mint & burn NFTs successfully", async () => {
    const { AlivelandNFT, owner, feeRecipient } = await loadFixture(deployTokenFixture);

    expect(await AlivelandNFT.balanceOf(owner.address, 1)).to.equal(0);

    await AlivelandNFT.mint(owner.address, 3, "test1", "nft1", { from: owner.address, value: mintFee3 });

    expect(await AlivelandNFT.balanceOf(owner.address, 0)).to.equal(3);
  });
});