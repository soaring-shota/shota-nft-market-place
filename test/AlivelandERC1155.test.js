const { ether } = require('@openzeppelin/test-helpers');

const { expect } = require("chai");

const AlivelandERC1155 = artifacts.require('AlivelandERC1155');

const MINT_FEE = '1';

contract('Aliveland ERC-1155 NFT Contract', (owner, tokenURI, feeRecipient) => {
  const mintFee = ether(MINT_FEE);

  beforeEach(async () => {
    AlivelandInstance = await AlivelandERC1155.new(
      tokenURI,
      mintFee,
      feeRecipient
    );
  });

  describe("Minting NFT", () => {
    it("Should mint NFTs successfully", async () => {
      const ownerBalance = await AlivelandInstance.balanceOf(owner, 1);
      expect(ownerBalance).to.equal(0);
  
      await AlivelandInstance.mint(owner, 1, 3, "", { from: owner });
  
      ownerBalance = await AlivelandInstance.balanceOf(owner, 1);
      expect(await AlivelandInstance.totalSupply()).to.equal(ownerBalance);
      expect(ownerBalance).to.equal(3);
    });
  
    it("Should mint batched NFTs successfully", async () => {
      const ownerBalance = await AlivelandInstance.balanceOf(owner, 1);
      expect(ownerBalance).to.equal(0);
      ownerBalance = await AlivelandInstance.balanceOf(owner, 2);    
      expect(ownerBalance).to.equal(0);
  
      await AlivelandInstance.mintBatch(owner, [1, 2], [3, 4], "", { from: owner });
  
      ownerBalance = await AlivelandInstance.balanceOf(owner, 1);
      expect(ownerBalance).to.equal(3);
      ownerBalance = await AlivelandInstance.balanceOf(owner, 2);
      expect(ownerBalance).to.equal(4);
    });
  });
});