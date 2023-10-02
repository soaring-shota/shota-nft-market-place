const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AlivelandERC721 Contract", () => {
  it("It should mint NFT successfully", async () => {
    const [owner] = await ethers.getSigners();

    const MyAlivelandERC721 = await ethers.deployContract("AlivelandERC721");

    const ownerOldBalance = await MyAlivelandERC721.balanceOf(owner.address);
    expect(ownerOldBalance).to.equal(0);
    const mint = await MyAlivelandERC721.mint(owner.address);
    const ownerNewBalance = await MyAlivelandERC721.balanceOf(owner.address);
    expect(await MyAlivelandERC721.totalSupply()).to.equal(ownerNewBalance);
    expect(ownerNewBalance).to.equal(1);
  });

  it("It should pause NFT transfer successfully", async () => {
    
  });

  it("It should burn NFT successfully", async () => {
    
  });

  it("It should update mintFee successfully", async () => {
    
  });

  it("It should update feeRecipient successfully", async () => {
    
  });
});