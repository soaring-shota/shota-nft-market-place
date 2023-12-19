const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

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

    await AlivelandNFT.mint(owner.address, 3, new Uint8Array([]), { from: owner.address, value: mintFee3 });

    expect(await AlivelandNFT.balanceOf(owner.address, 0)).to.equal(3);

    await AlivelandNFT.burn(owner.address, 0, 3);

    expect(await AlivelandNFT.balanceOf(owner.address, 0)).to.equal(0);
  });

  it("Should batch mint & burn NFTs successfully", async () => {
    const { AlivelandNFT, owner, feeRecipient } = await loadFixture(deployTokenFixture);

    let nftBalance = await AlivelandNFT.balanceOfBatch(
      [owner.address, owner.address], 
      [1, 2]
    );
    expect(nftBalance.toString()).to.equal("0,0");

    await AlivelandNFT.mintBatch(owner.address, [1, 2], [3, 4], new Uint8Array([]), { from: owner.address, value: mintFee7 });

    nftBalance = await AlivelandNFT.balanceOfBatch(
      [owner.address, owner.address], 
      [1, 2]
    );
    expect(nftBalance.toString()).to.equal("3,4");

    await AlivelandNFT.burnBatch(owner.address, [1, 2], [3, 4]);

    nftBalance = await AlivelandNFT.balanceOfBatch(
      [owner.address, owner.address], 
      [1, 2]
    );
    expect(nftBalance.toString()).to.equal("0,0");
  });
});