const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { parseEther } = require("ethers");

describe("Aliveland Marketplace Contract", () => {
    const firstTokenId = '0';
    const secondTokenId = '1';
    const platformFee = '25';
    const pricePerItem = ethers.parseEther("1");
    const newPrice = ethers.parseEther("0.5");
    const TOKENS = '1000000000000000000000';
    const payToken = '0x0000000000000000000000000000000000001010';
    const royalty = 250;

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
                "ipfs",
                "ipfs://metadata",
                pricePerItem,
                feeRecipient.address,
                owner.address
            ]
        );
        await AlivelandNFT.mint(owner.address, "test1", royalty, "nft1", { from: owner.address, value: pricePerItem });
        await AlivelandNFT.mint(owner.address, "test2", royalty, "nft2", { from: owner.address, value: pricePerItem });

        const mockToken = await ethers.deployContract(
            "MockERC20",
            [
                'Mock ERC20',
                'MOCK',
                TOKENS,
            ],
            owner
        );

        const AlivelandTokenRegistry = await ethers.deployContract("AlivelandTokenRegistry");
        await AlivelandTokenRegistry.add(mockToken.target);
        const AlivelandAddressRegistry = await ethers.deployContract("AlivelandAddressRegistry");
        await AlivelandAddressRegistry.updateTokenRegistry(AlivelandTokenRegistry.target);
        await AlivelandAddressRegistry.updateMarketplace(AlivelandMarketplace.target);
        await AlivelandMarketplace.updateAddressRegistry(AlivelandAddressRegistry.target);

        return { AlivelandMarketplace, AlivelandNFT, mockToken, owner, feeRecipient, minter, auction, marketplace };
    }
  
    describe('Listing Item', () => {
        it('Should revert when not approved', async () => {
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner } = await loadFixture(deployTokenFixture);
            await expect(
                AlivelandMarketplace.connect(owner).listItem(
                    AlivelandNFT.target,
                    'art',
                    firstTokenId,
                    '1',
                    mockToken.target,
                    pricePerItem,
                    '0'
                )
            ).to.be.reverted;
        });

        it('Should list item successfully', async () => {
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner } = await loadFixture(deployTokenFixture);
            await AlivelandNFT.connect(owner).setApprovalForAll(AlivelandMarketplace.target, true);
            await AlivelandMarketplace.connect(owner).listItem(
                AlivelandNFT.target,
                'art',
                firstTokenId,
                '1',
                mockToken.target,
                pricePerItem,
                '0'
            );
        });

        it('Should emit ItemListed event', async () => {
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner } = await loadFixture(deployTokenFixture);
            await AlivelandNFT.setApprovalForAll(AlivelandMarketplace.target, true, { from: owner.address });
            await expect(
                AlivelandMarketplace.connect(owner).listItem(
                    AlivelandNFT.target,
                    'art',
                    firstTokenId,
                    '1',
                    mockToken.target,
                    pricePerItem,
                    '0'
                )
            ).to.emit(AlivelandMarketplace, "ItemListed").withArgs(
                owner.address,
                AlivelandNFT.target,
                'art',
                firstTokenId,
                '1',
                mockToken.target,
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
                "ipfs",
                "ipfs://metadata",
                pricePerItem,
                feeRecipient.address,
                owner.address
            ]
        );
       await AlivelandNFT.mint(owner.address, "test1", royalty, "nft1", { from: owner.address, value: pricePerItem });
        await AlivelandNFT.mint(owner.address, "test2", royalty, "nft2", { from: owner.address, value: pricePerItem });

        const mockToken = await ethers.deployContract(
            "MockERC20",
            [
                'Mock ERC20',
                'MOCK',
                TOKENS,
            ],
            buyer
        );

        const AlivelandTokenRegistry = await ethers.deployContract("AlivelandTokenRegistry");
        await AlivelandTokenRegistry.add(payToken);
        const AlivelandAddressRegistry = await ethers.deployContract("AlivelandAddressRegistry");
        await AlivelandAddressRegistry.updateTokenRegistry(AlivelandTokenRegistry.target);
        await AlivelandAddressRegistry.updateMarketplace(AlivelandMarketplace.target);
        await AlivelandMarketplace.updateAddressRegistry(AlivelandAddressRegistry.target);

        await AlivelandNFT.setApprovalForAll(AlivelandMarketplace.target, true);
        await AlivelandMarketplace.connect(owner).listItem(
            AlivelandNFT.target,
            'art',
            firstTokenId,
            '1',
            payToken,
            pricePerItem,
            '0'
        );

        return { AlivelandMarketplace, AlivelandNFT, mockToken, owner, feeRecipient, buyer, minter, auction, marketplace };
    }

    describe('Canceling Item', () => {
        it('reverts when item is not listed', async () => {
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner } = await loadFixture(listItemFixture);
            await expect(
                AlivelandMarketplace.connect(owner).cancelListing(
                    AlivelandNFT.target,
                    secondTokenId
                )
            ).to.be.reverted;
        });

        it('successfully cancel the item', async function() {
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner } = await loadFixture(listItemFixture);
            await AlivelandMarketplace.connect(owner).cancelListing(
                AlivelandNFT.target,
                firstTokenId
            );
        });

        it('Should emit ItemCanceled event', async () => {
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner } = await loadFixture(listItemFixture);
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
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner } = await loadFixture(listItemFixture);
            await expect(
                AlivelandMarketplace.connect(owner).updateListing(
                    AlivelandNFT.target,
                    secondTokenId,
                    payToken,
                    newPrice
                )
            ).to.be.reverted;
        });

        it('successfully update the item', async () => {
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner } = await loadFixture(listItemFixture);
            await AlivelandMarketplace.connect(owner).updateListing(
                AlivelandNFT.target,
                firstTokenId,
                payToken,
                newPrice
            );
        });

        it('Should emit ItemUpdated event', async () => {
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner } = await loadFixture(listItemFixture);
            await expect(
                AlivelandMarketplace.connect(owner).updateListing(
                    AlivelandNFT.target,
                    firstTokenId,
                    payToken,
                    newPrice
                )
            ).to.emit(AlivelandMarketplace, "ItemUpdated").withArgs(
                owner.address,
                AlivelandNFT.target,
                firstTokenId,
                payToken,
                newPrice
            );
        });
    });

    describe('Buying Item', () => {
        it('reverts when seller doesnt own the item', async () => {
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner, buyer, minter } = await loadFixture(listItemFixture);
            await AlivelandNFT.connect(owner).safeTransferFrom(owner, minter, firstTokenId);
            await expect(
                AlivelandMarketplace.connect(buyer).buyItem(
                    AlivelandNFT.target,
                    firstTokenId,
                    payToken,
                    owner,
                    { value: pricePerItem }
                )
            ).to.be.reverted;
        });

        it('reverts when buying before the scheduled time', async () => {
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner, buyer, minter } = await loadFixture(listItemFixture);
            await AlivelandNFT.connect(owner).setApprovalForAll(AlivelandMarketplace.target, true);
            await AlivelandMarketplace.connect(owner).listItem(
                AlivelandNFT.target,
                'art',
                secondTokenId,
                '1',
                payToken,
                pricePerItem,
                '1000000000000000'
            );
            await expect(
                AlivelandMarketplace.connect(buyer).buyItem(
                    AlivelandNFT.target,
                    secondTokenId,
                    payToken,
                    owner,
                    { value: pricePerItem }
                )
            ).to.be.reverted;
        });

        it('reverts when the amount is not enough', async () => {
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner, buyer, minter } = await loadFixture(listItemFixture);
            await expect(
                AlivelandMarketplace.connect(buyer).buyItem(
                    AlivelandNFT.target,
                    firstTokenId,
                    payToken,
                    owner
                )
            ).to.be.reverted;
        });

        it('successfully purchase item', async () => {
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner, feeRecipient, buyer } = await loadFixture(listItemFixture);
            await AlivelandMarketplace.connect(buyer).buyItem(
                AlivelandNFT.target,
                firstTokenId,
                payToken,
                owner,
                { value: pricePerItem }
            );
            expect(await AlivelandNFT.ownerOf(firstTokenId)).to.be.equal(buyer.address);
            expect(feeRecipient).to.changeEtherBalance(feeRecipient.address, parseEther('0.025'));
            expect(owner).to.changeEtherBalance(owner.address, parseEther('0.975'));
        });

        it('Should emit ItemSold event successfully', async () => {
            const { AlivelandMarketplace, AlivelandNFT, mockToken, owner, buyer } = await loadFixture(listItemFixture);
            await expect(
                AlivelandMarketplace.connect(buyer).buyItem(
                    AlivelandNFT.target,
                    firstTokenId,
                    payToken,
                    owner,
                    { value: pricePerItem }
                )
            ).to.emit(AlivelandMarketplace, "ItemSold").withArgs(
                owner.address,
                buyer.address,
                AlivelandNFT.target,
                firstTokenId,
                '1',
                payToken,
                pricePerItem
            );
        });
    });
});