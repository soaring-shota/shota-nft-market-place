require('dotenv').config();
const { ethers }  = require("hardhat");

const mintFee = ethers.parseEther(process.env.MINT_FEE);

module.exports = [
    process.env.BASE_URI,
    mintFee,
    process.env.FEE_RECIPIENT
  ];