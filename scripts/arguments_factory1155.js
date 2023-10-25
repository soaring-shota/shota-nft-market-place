const { 
  BASE_URI, 
  MINT_FEE, 
  FEE_RECIPIENT,
  MARKETPLACE_ADDRESS, 
  COLLECTION_FEE 
} = require('./constants');
const { ethers } = require('hardhat');

const mintFee = ethers.parseEther(MINT_FEE);
const collectionFee = ethers.parseEther(COLLECTION_FEE);

module.exports = [
  MARKETPLACE_ADDRESS,
  BASE_URI,
  mintFee,
  collectionFee,
  FEE_RECIPIENT
];