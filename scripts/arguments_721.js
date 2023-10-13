require('dotenv').config();
const { ethers }  = require("hardhat");

const mintFee = ethers.parseEther(process.env.MINT_FEE);

module.exports = [
  "Aliveland NFT",
  "ALNFT",
  process.env.BASE_URI,
  mintFee,
  process.env.FEE_RECIPIENT
];