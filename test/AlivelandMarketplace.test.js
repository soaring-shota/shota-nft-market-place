const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
    BN,
    constants,
    expectEvent,
    expectRevert,
    balance,
} = require('@openzeppelin/test-helpers');
const { parseEther, ZeroAddress } = require("ethers");
const { ZERO_ADDRESS, MAX_UINT256 } = constants;

describe("Aliveland Marketplace Contract", () => {
    const firstTokenId = '0';
    const secondTokenId = '1';
    const platformFee = '25';
    const pricePerItem = ethers.parseEther("1");
    const newPrice = ethers.parseEther("0.5");

    async function deployTokenFixture() {
        const [owner, feeRecipient, minter, auction, marketplace] = await ethers.getSigners();

        const AlivelandMarketplace = await ethers.deployContract(
            "AlivelandMarketplace"
        );
        AlivelandMarketplace.initialize(feeRecipient, platformFee);

        const AlivelandNFT = await ethers.deployContract(
            "AlivelandERC721", 
            [
                "Aliveland NFT",
                "ALNFT",
                auction.address,
                marketplace.address,
                "ipfs",
                pricePerItem,
                feeRecipient.address,
                owner.address
            ]
        );
        await AlivelandNFT.mint(owner.address, { from: owner.address, value: pricePerItem });
        await AlivelandNFT.mint(owner.address, { from: owner.address, value: pricePerItem });

        return { AlivelandMarketplace, AlivelandNFT, owner, feeRecipient, minter, auction, marketplace };
    }
  
    describe('Listing Item', () => {
        it('Should revert when not approved', async () => {
            const { AlivelandMarketplace, AlivelandNFT, owner } = await loadFixture(deployTokenFixture);
            await expect(
                AlivelandMarketplace.connect(owner).listItem(
                    AlivelandNFT.target,
                    firstTokenId,
                    '1',
                    ZERO_ADDRESS,
                    pricePerItem,
                    '0'
                )
            ).to.be.reverted;
        });

        it('Should list item successfully', async () => {
            const { AlivelandMarketplace, AlivelandNFT, owner } = await loadFixture(deployTokenFixture);
            await AlivelandNFT.setApprovalForAll(AlivelandMarketplace.target, true, { from: owner.address });
            await AlivelandMarketplace.connect(owner).listItem(
                AlivelandNFT.target,
                firstTokenId,
                '1',
                ZERO_ADDRESS,
                pricePerItem,
                '0'
            );
        });

        it('Should emit ItemListed event', async () => {
            const { AlivelandMarketplace, AlivelandNFT, owner } = await loadFixture(deployTokenFixture);
            await AlivelandNFT.setApprovalForAll(AlivelandMarketplace.target, true, { from: owner.address });
            await expect(
                AlivelandMarketplace.connect(owner).listItem(
                    AlivelandNFT.target,
                    firstTokenId,
                    '1',
                    ZERO_ADDRESS,
                    pricePerItem,
                    '0'
                )
            ).to.emit(AlivelandMarketplace, "ItemListed").withArgs(
                owner.address,
                AlivelandNFT.target,
                firstTokenId,
                '1',
                ZERO_ADDRESS,
                pricePerItem,
                '0'
            );
        });
    });

    async function listItemFixture() {
        const [owner, feeRecipient, buyer, minter, auction, marketplace] = await ethers.getSigners();

        const AlivelandMarketplace = await ethers.deployContract(
            "AlivelandMarketplace"
        );
        AlivelandMarketplace.initialize(feeRecipient, platformFee);

        const AlivelandNFT = await ethers.deployContract(
            "AlivelandERC721", 
            [
                "Aliveland NFT",
                "ALNFT",
                auction.address,
                marketplace.address,
                "ipfs",
                pricePerItem,
                feeRecipient.address,
                owner.address
            ]
        );
        await AlivelandNFT.mint(owner.address, { from: owner.address, value: pricePerItem });
        await AlivelandNFT.mint(owner.address, { from: owner.address, value: pricePerItem });

        await AlivelandNFT.setApprovalForAll(AlivelandMarketplace.target, true, { from: owner.address });
        await AlivelandMarketplace.connect(owner).listItem(
            AlivelandNFT.target,
            firstTokenId,
            '1',
            ZERO_ADDRESS,
            pricePerItem,
            '0'
        );

        return { AlivelandMarketplace, AlivelandNFT, owner, feeRecipient, buyer, minter, auction, marketplace };
    }

    describe('Canceling Item', () => {
        it('reverts when item is not listed', async () => {
            const { AlivelandMarketplace, AlivelandNFT, owner } = await loadFixture(listItemFixture);
            await expect(
                AlivelandMarketplace.connect(owner).cancelListing(
                    AlivelandNFT.target,
                    secondTokenId
                )
            ).to.be.reverted;
        });

        it('successfully cancel the item', async function() {
            const { AlivelandMarketplace, AlivelandNFT, owner } = await loadFixture(listItemFixture);
            await AlivelandMarketplace.connect(owner).cancelListing(
                AlivelandNFT.target,
                firstTokenId
            );
        });

        it('Should emit ItemCanceled event', async () => {
            const { AlivelandMarketplace, AlivelandNFT, owner } = await loadFixture(listItemFixture);
            await expect(
                AlivelandMarketplace.connect(owner).cancelListing(
                    AlivelandNFT.target,
                    firstTokenId
                )
            ).to.emit(AlivelandMarketplace, "ItemCanceled").withArgs(
                owner.address,
                AlivelandNFT.target,
                firstTokenId
            );
        });
    });

    describe('Updating Item Price', () => {
        it('reverts when item is not listed', async () => {
            const { AlivelandMarketplace, AlivelandNFT, owner } = await loadFixture(listItemFixture);
            await expect(
                AlivelandMarketplace.connect(owner).updateListing(
                    AlivelandNFT.target,
                    secondTokenId,
                    ZERO_ADDRESS,
                    newPrice
                )
            ).to.be.reverted;
        });

        it('successfully update the item', async () => {
            const { AlivelandMarketplace, AlivelandNFT, owner } = await loadFixture(listItemFixture);
            await AlivelandMarketplace.connect(owner).updateListing(
                AlivelandNFT.target,
                firstTokenId,
                ZERO_ADDRESS,
                newPrice
            );
        });

        it('Should emit ItemUpdated event', async () => {
            const { AlivelandMarketplace, AlivelandNFT, owner } = await loadFixture(listItemFixture);
            await expect(
                AlivelandMarketplace.connect(owner).updateListing(
                    AlivelandNFT.target,
                    firstTokenId,
                    ZERO_ADDRESS,
                    newPrice
                )
            ).to.emit(AlivelandMarketplace, "ItemUpdated").withArgs(
                owner.address,
                AlivelandNFT.target,
                firstTokenId,
                ZERO_ADDRESS,
                newPrice
            );
        });
    });

    describe('Buying Item', () => {
        it('reverts when seller doesnt own the item', async () => {
            const { AlivelandMarketplace, AlivelandNFT, owner, buyer, minter } = await loadFixture(listItemFixture);
            await AlivelandNFT.connect(owner).safeTransferFrom(owner, minter, firstTokenId);
            await expect(
                AlivelandMarketplace.connect(buyer).buyItem(
                    AlivelandNFT.target,
                    firstTokenId,
                    ZERO_ADDRESS,
                    owner,
                    { value: pricePerItem }
                )
            ).to.be.reverted;
        });

        it('reverts when buying before the scheduled time', async () => {
            const { AlivelandMarketplace, AlivelandNFT, owner, buyer, minter } = await loadFixture(listItemFixture);
            await AlivelandNFT.connect(owner).setApprovalForAll(AlivelandMarketplace.target, true);
            await AlivelandMarketplace.connect(owner).listItem(
                AlivelandNFT.target,
                secondTokenId,
                '1',
                ZERO_ADDRESS,
                pricePerItem,
                '1000000000000000'
            );
            await expect(
                AlivelandMarketplace.connect(buyer).buyItem(
                    AlivelandNFT.target,
                    secondTokenId,
                    ZERO_ADDRESS,
                    owner,
                    { value: pricePerItem }
                )
            ).to.be.reverted;
        });

        it('reverts when the amount is not enough', async () => {
            const { AlivelandMarketplace, AlivelandNFT, owner, buyer, minter } = await loadFixture(listItemFixture);
            await expect(
                AlivelandMarketplace.connect(buyer).buyItem(
                    AlivelandNFT.target,
                    firstTokenId,
                    ZERO_ADDRESS,
                    owner
                )
            ).to.be.reverted;
        });

        it('successfully purchase item', async () => {
            const { AlivelandMarketplace, AlivelandNFT, owner, feeRecipient, buyer } = await loadFixture(listItemFixture);
            await AlivelandMarketplace.connect(buyer).buyItem(
                AlivelandNFT.target,
                firstTokenId,
                ZERO_ADDRESS,
                owner,
                { value: pricePerItem }
            );
            expect(await AlivelandNFT.ownerOf(firstTokenId)).to.be.equal(buyer.address);
            expect(feeRecipient).to.changeEtherBalance(feeRecipient.address, parseEther('0.025'));
            expect(owner).to.changeEtherBalance(owner.address, parseEther('0.975'));
        });

        it('Should emit ItemSold event successfully', async () => {
            const { AlivelandMarketplace, AlivelandNFT, owner, buyer } = await loadFixture(listItemFixture);
            await expect(
                AlivelandMarketplace.connect(buyer).buyItem(
                    AlivelandNFT.target,
                    firstTokenId,
                    ZERO_ADDRESS,
                    owner,
                    { value: pricePerItem }
                )
            ).to.emit(AlivelandMarketplace, "ItemSold").withArgs(
                owner.address,
                buyer.address,
                AlivelandNFT.target,
                firstTokenId,
                '1',
                ZERO_ADDRESS,
                pricePerItem
            );
        });
    });
});