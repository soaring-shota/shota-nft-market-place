const { 
  BASE_URI, 
  MINT_FEE, 
  FEE_RECIPIENT, 
  AUCTION_ADDRESS, 
  MARKETPLACE_ADDRESS, 
  DEPLOYER_ADDRESS 
} = require('./constants');
const { ethers } = require('hardhat');

const mintFee = ethers.parseEther(MINT_FEE);

module.exports = [
  "Aliveland NFT",
  "ALNFT",
  AUCTION_ADDRESS,
  MARKETPLACE_ADDRESS,
  BASE_URI,
  mintFee,
  FEE_RECIPIENT,
  DEPLOYER_ADDRESS
];