const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AlivelandERC721 Contract", () => {
  let myAlivelandERC721Deployed;
  let owner;

  beforeEach(async ()=> {
    const MyAlivelandERC721 = await ethers.getContractFactory("AlivelandERC721");
    myAlivelandERC721Deployed = await MyAlivelandERC721.deploy(
      "AliveLandNFT", 
      "ALNFT", 
      "https://ipfs.io/ipfs/QmXXzRSwSPs4DHLS7RDPRyG1GinjGVFv2fS5TdX3fW33FX/", 
      "1", 
      "0x3986faA59C28D082F3E6D61c5f52e1520d172205"
    );

    [owner] = await ethers.getSigners();
  })

  it("Should mint NFT successfully", async () => {
    const ownerOldBalance = await myAlivelandERC721Deployed.balanceOf(owner.address);
    expect(ownerOldBalance).to.equal(0);

    await myAlivelandERC721Deployed.mint(owner.address);
    const ownerNewBalance = await myAlivelandERC721Deployed.balanceOf(owner.address);
    expect(await myAlivelandERC721Deployed.totalSupply()).to.equal(ownerNewBalance);
    expect(ownerNewBalance).to.equal(1);
  });

  it("Should send fee to the recipient successfully", async () => {
    await myAlivelandERC721Deployed.mint(owner.address);

    let myBalance = await ethers.provider.getBalance("0x3986faA59C28D082F3E6D61c5f52e1520d172205");
    expect(myBalance).to.equal(1);
  });
});