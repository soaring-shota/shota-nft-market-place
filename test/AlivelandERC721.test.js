const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Aliveland ERC-721 NFT Contract", async () => {
  const mintFee = ethers.parseEther("1");
  const mintFee2 = ethers.parseEther("2");
  const royalty = 250;

  async function deployTokenFixture() {
    const [owner, feeRecipient] = await ethers.getSigners();

    const AlivelandNFT = await ethers.deployContract(
      "AlivelandERC721",
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

  it("Should mint NFT successfully", async () => {
    const { AlivelandNFT, owner, feeRecipient } = await loadFixture(deployTokenFixture);

    expect(await AlivelandNFT.balanceOf(owner.address)).to.equal(0);

    await AlivelandNFT.mint(owner.address, "test1", royalty, "nft1", { from: owner.address, value: mintFee });
    expect(await AlivelandNFT.balanceOf(owner.address)).to.equal(1);

    await AlivelandNFT.mint(owner.address, "test2", royalty, "nft2", { from: owner.address, value: mintFee });
    expect(await AlivelandNFT.balanceOf(owner.address)).to.equal(2);

    expect(feeRecipient).to.changeEtherBalance(feeRecipient.address, mintFee2);
  });

  it("Should burn NFT successfully", async () => {
    const { AlivelandNFT, owner } = await loadFixture(deployTokenFixture);

    await AlivelandNFT.mint(owner.address, "test1", royalty, "nft1", { from: owner.address, value: mintFee });
    await AlivelandNFT.mint(owner.address, "test2", royalty, "nft2", { from: owner.address, value: mintFee });

    expect(await AlivelandNFT.balanceOf(owner.address)).to.equal(2);

    await AlivelandNFT.burn(1);
    expect(await AlivelandNFT.balanceOf(owner.address)).to.equal(1);

    await AlivelandNFT.burn(0);
    expect(await AlivelandNFT.balanceOf(owner.address)).to.equal(0);
  });
});