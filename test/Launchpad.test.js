const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const {
    constants,
    expectRevert,
} = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;
const LaunchpadSale = artifacts.require('LaunchpadSale.sol');
const LaunchpadERC721 = artifacts.require('LaunchpadERC721.sol');

describe("LaunchpadSale Test", () => {

    async function deployTokenFixture() {
        const [owner] = await ethers.getSigners();

        // console.log(owner.address);

        const LaunchPadNFT = await ethers.deployContract(
            "LaunchpadERC721", 
            [
                "Pola", // name
                "POL", // symbol
                "https://ipfs.io/ipfs/QmeKBHcLuoHuTywmURt3LuVWG2tu1q9BDtaRjR5DDW7vq2", // token URI
                1706080955, // start time
                1711354986, // end time
                100, // price
                5000 // max supply
            ]
          );
        // console.log("LaunchPadNft", LaunchPadNFT.target);
        const LaunchpadSale = await ethers.deployContract("LaunchpadSale", [LaunchPadNFT.target]);
        // console.log("LaunchpadSale");
        
        return {LaunchpadSale, LaunchPadNFT, owner};
    }
  
    describe('Buy', async () => {
        it('Should revert when not approved', async () => {
            const { LaunchpadSale, LaunchPadNFT, owner } = await loadFixture(deployTokenFixture);

            const count = 2;
            const valueEther = ethers.parseEther("0.03");
            // console.log(valueEther);
            // await LaunchPadNFT.mint(count, { from: owner.address, value: valueEther });
            await LaunchpadSale.buy(count, { from: owner.address, value: valueEther });
        });
    });
});