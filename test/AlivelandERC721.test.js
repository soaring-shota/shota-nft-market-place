const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BN } = require('@openzeppelin/test-helpers');
const { parseEther, ZeroAddress } = require("ethers");

describe("Aliveland ERC-721 NFT Contract", async () => {
  const mintFee = ethers.parseEther("1");

  async function deployTokenFixture() {
    const [owner, feeRecipient, auction, marketplace] = await ethers.getSigners();

    const AlivelandNFT = await ethers.deployContract(
      "AlivelandERC721", 
      [
        "Aliveland NFT",
        "ALNFT",
        auction,
        marketplace,
        "ipfs",
        mintFee,
        feeRecipient.address,
        owner
      ]
    );
                                                                      
    return { AlivelandNFT, owner, feeRecipient };
  }
  
  it("Should mint NFT successfully", async () => {
    const { AlivelandNFT, owner, feeRecipient } = await loadFixture(deployTokenFixture);

    let nftBalance = await AlivelandNFT.balanceOf(owner.address);
    expect(nftBalance).to.equal(0);

    await AlivelandNFT.mint(owner.address, { from: owner.address, value: mintFee });

    nftBalance = await AlivelandNFT.balanceOf(owner.address);
    expect(nftBalance).to.equal(1);

    let feeBalance = await ethers.provider.getBalance(feeRecipient.address);
    expect(feeRecipient).to.changeEtherBalance(feeRecipient.address, mintFee);
  });

  it("Should burn NFT successfully", async () => {
    const { AlivelandNFT, owner } = await loadFixture(deployTokenFixture);

    await AlivelandNFT.mint(owner.address, { from: owner.address, value: mintFee });
    await AlivelandNFT.mint(owner.address, { from: owner.address, value: mintFee });

    let nftBalance = await AlivelandNFT.balanceOf(owner.address);
    expect(nftBalance).to.equal(2);

    await AlivelandNFT.burn(1);
    nftBalance = await AlivelandNFT.balanceOf(owner.address);
    expect(nftBalance).to.equal(1);

    await AlivelandNFT.burn(0);
    nftBalance = await AlivelandNFT.balanceOf(owner.address);
    expect(nftBalance).to.equal(0);
  });
});