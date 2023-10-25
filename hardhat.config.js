/** @type import('hardhat/config').HardhatUserConfig */
require('dotenv').config();
require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-chai-matchers");
require("@nomiclabs/hardhat-truffle4");

const { 
  POLYGON_API_URL, 
  MUMBAI_API_URL, 
  METAMASK_PRIVATE_KEY,
  POLYGONSCAN_API_KEY
} = process.env;

module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true,
    }
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 1337
    },
    polygon: {
      url: POLYGON_API_URL,
      chainId: 137,
      accounts: [`0x${METAMASK_PRIVATE_KEY}`]
    },
    mumbai: {
      url: MUMBAI_API_URL,
      chainId: 80001,
      accounts: [`0x${METAMASK_PRIVATE_KEY}`]
    }
  },
  etherscan: {
    apiKey: POLYGONSCAN_API_KEY
  },
};
