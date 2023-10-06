/** @type import('hardhat/config').HardhatUserConfig */
require('dotenv').config();
require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-chai-matchers");

const { POLYGON_API_URL, MUMBAI_API_URL, PRIVATE_KEY } = process.env;

module.exports = {
  solidity: "0.8.19",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 1337
    },
    polygon: {
      url: POLYGON_API_URL,
      chainId: 137,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    mumbai: {
      url: MUMBAI_API_URL,
      chainId: 80001,
      accounts: [`0x${PRIVATE_KEY}`]
    }
  },
};
