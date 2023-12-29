require('dotenv').config();
const { 
  BASE_URI, 
  MINT_FEE, 
  FEE_RECIPIENT,
  DEPLOYER_ADDRESS 
} = process.env;
const { ethers } = require('hardhat');

const mintFee = ethers.parseEther(MINT_FEE);

module.exports = [
  "Aliveland NFT",
  "ALNFT",
  BASE_URI,
  "ipfs://metadata",
  mintFee,
  FEE_RECIPIENT,
  DEPLOYER_ADDRESS
  ];