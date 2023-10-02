/** @type import('hardhat/config').HardhatUserConfig */
require('dotenv').config();
require("@nomicfoundation/hardhat-toolbox");

const { API_URL, PRIVATE_KEY } = process.env;

module.exports = {
  solidity: "0.8.19",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 1337
    },
    mainnet: {
      url: API_URL,
      chainId: 137,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    testnet: {
      url: "https://rpc-mumbai.maticvigil.com",
      chainId: 80001,
      accounts: [`0x${PRIVATE_KEY}`]
    }
  },
};
