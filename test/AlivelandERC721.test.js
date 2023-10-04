const { ether } = require('@openzeppelin/test-helpers');

const { expect } = require("chai");
const { ethers } = require("hardhat");

const AlivelandERC721 = artifacts.require('AlivelandERC721');

const MINT_FEE = '1';

contract('Aliveland ERC-721 NFT Contract', (owner, tokenURI, feeRecipient) => {
  const mintFee = ether(MINT_FEE);

  beforeEach(async () => {
    AlivelandInstance = await AlivelandERC721.new(
      "Aliveland NFT",
      "ALNFT",
      tokenURI,
      mintFee,
      feeRecipient
    );
  });

  describe("Minting NFT", () => {
    it("Should mint NFT successfully", async () => {
      let ownerBalance = await AlivelandInstance.balanceOf(owner);
      expect(ownerBalance).to.equal(0);
  
      await AlivelandInstance.mint(owner, { from: owner });
  
      ownerBalance = await AlivelandInstance.balanceOf(owner);
      expect(await AlivelandInstance.totalSupply()).to.equal(ownerBalance);
      expect(ownerBalance).to.equal(1);
    });
  
    it("Should send fee to the recipient successfully", async () => {
      let recipient = accounts[1];
      await AlivelandInstance.mint(owner, { from: owner });
  
      let myBalance = await ethers.provider.getBalance(recipient);
      expect(myBalance).to.equal(1);
    });
  });
});