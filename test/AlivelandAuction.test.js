const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
    constants,
    expectRevert,
    balance
} = require('@openzeppelin/test-helpers');
const { parseEther, ZeroAddress } = require("ethers");
const { ZERO_ADDRESS, MAX_UINT256 } = constants;
const BiddingContractMock = artifacts.require('BiddingContractMock');

describe("Aliveland Auction Contract", () => {
    const firstTokenId = '0';
    const secondTokenId = '1';
    const platformFee = '25';
    const pricePerItem = ethers.parseEther("1");
    const reservePrice = ethers.parseEther("1");
    const minBidReserve = true;
    const bidAmount = ethers.parseEther("1.2");
    const bidLowAmount = ethers.parseEther("0.5");

    async function deployTokenFixture() {
        const [owner, feeRecipient, minter, bidder, marketplace] = await ethers.getSigners();

        const AlivelandMarketplace = await ethers.deployContract("AlivelandMarketplace");
        AlivelandMarketplace.initialize(feeRecipient, platformFee);

        const AlivelandAuction = await ethers.deployContract("AlivelandAuctionMock");

        const AlivelandNFT = await ethers.deployContract(
            "AlivelandERC721", 
            [
                "Aliveland NFT",
                "ALNFT",
                AlivelandAuction.target,
                AlivelandMarketplace.target,
                "ipfs",
                pricePerItem,
                feeRecipient.address,
                owner.address
            ]
        );
        await AlivelandNFT.mint(owner.address, { from: owner.address, value: pricePerItem });
        await AlivelandNFT.mint(owner.address, { from: owner.address, value: pricePerItem });

        return { AlivelandMarketplace, AlivelandNFT, AlivelandAuction, owner, feeRecipient, minter, bidder, marketplace };
    }
  
    describe('Create auction', async () => {
        it('Should revert when not approved', async () => {
            const { AlivelandAuction, AlivelandNFT, owner } = await loadFixture(deployTokenFixture);
            await expect(
                AlivelandAuction.createAuction(
                    AlivelandNFT.target,
                    firstTokenId,
                    ZERO_ADDRESS,
                    reservePrice,
                    '1',
                    minBidReserve,
                    '10'
                )
            ).to.be.reverted;
        });

        it('Should revert when end time is larger than start (by 5 minutes)', async () => {
            const { AlivelandAuction, AlivelandNFT, owner } = await loadFixture(deployTokenFixture);
            await AlivelandNFT.setApprovalForAll(AlivelandAuction.target, true);
            await AlivelandAuction.setNowOverride('12');
            await expect(
                AlivelandAuction.createAuction(
                    AlivelandNFT.target,
                        firstTokenId,
                        ZERO_ADDRESS,
                        reservePrice,
                        '1',
                        minBidReserve,
                        '10'
                )
            ).to.be.reverted;
        });

        it('Should revert when endTime is in the past', async () => {
            const { AlivelandAuction, AlivelandNFT, owner } = await loadFixture(deployTokenFixture);
            await AlivelandNFT.setApprovalForAll(AlivelandAuction.target, true);
            await AlivelandAuction.setNowOverride('10');
            await expect(
                AlivelandAuction.createAuction(
                    AlivelandNFT.target,
                    firstTokenId,
                    ZERO_ADDRESS,
                    reservePrice,
                    '1',
                    minBidReserve,
                    '310'
                )
            ).to.be.reverted;
        });

        it('Should create auction successfully and emit AuctionCreated event', async () => {
            const { AlivelandAuction, AlivelandNFT, owner } = await loadFixture(deployTokenFixture);
            await AlivelandNFT.setApprovalForAll(AlivelandAuction.target, true);
            await AlivelandAuction.setNowOverride('10');
            await expect(
                AlivelandAuction.createAuction(
                    AlivelandNFT.target,
                    firstTokenId,
                    ZERO_ADDRESS,
                    reservePrice,
                    '12',
                    minBidReserve,
                    '350'
                )
            ).to.emit(AlivelandAuction, "AuctionCreated").withArgs(
                AlivelandNFT.target,
                firstTokenId,
                ZERO_ADDRESS
            );
        });
    });

    async function auctionFixture() {
        const [owner, feeRecipient, minter, bidder, marketplace] = await ethers.getSigners();

        const AlivelandMarketplace = await ethers.deployContract("AlivelandMarketplace");
        AlivelandMarketplace.initialize(feeRecipient, platformFee);

        const AlivelandAuction = await ethers.deployContract("AlivelandAuctionMock");

        const AlivelandNFT = await ethers.deployContract(
            "AlivelandERC721", 
            [
                "Aliveland NFT",
                "ALNFT",
                AlivelandAuction.target,
                AlivelandMarketplace.target,
                "ipfs",
                pricePerItem,
                feeRecipient.address,
                owner.address
            ]
        );
        await AlivelandNFT.mint(owner.address, { from: owner.address, value: pricePerItem });
        await AlivelandNFT.mint(owner.address, { from: owner.address, value: pricePerItem });

        await AlivelandNFT.setApprovalForAll(AlivelandAuction.target, true);
        await AlivelandAuction.setNowOverride('10');
        await AlivelandAuction.createAuction(
            AlivelandNFT.target,
            firstTokenId,
            ZERO_ADDRESS,
            reservePrice,
            '12',
            minBidReserve,
            '350'
        );

        return { AlivelandMarketplace, AlivelandNFT, AlivelandAuction, owner, feeRecipient, minter, bidder, marketplace };
    }

    describe('Place bid', async () => {
        it('Should revert when bidder is smart contract', async () => {
            // const { AlivelandAuction, AlivelandNFT, owner } = await loadFixture(auctionFixture);
            // const biddingContract = await BiddingContractMock.new(AlivelandAuction.target);
            // await expect(
            //    biddingContract.bid(AlivelandNFT.target, firstTokenId, bidAmount)
            // ).to.be.reverted;
        });

        it('Should revert when bidding outside of the auction duration', async () => {
            const { AlivelandAuction, AlivelandNFT, owner } = await loadFixture(auctionFixture);
            await expect(
                AlivelandAuction.placeBid(
                    AlivelandNFT.target,
                    firstTokenId,
                    bidAmount
                )
            ).to.be.reverted;
        });

        it('Should revert when bid is lower than reserved price', async () => {
            const { AlivelandAuction, AlivelandNFT, owner } = await loadFixture(auctionFixture);
            await AlivelandAuction.setNowOverride(20);
            await expect(
                AlivelandAuction.placeBid(
                    AlivelandNFT.target,
                    firstTokenId,
                    bidLowAmount
                )
            ).to.be.reverted;
        });

        it('Should place bid successfully and emit BidPlaced event', async () => {
            const { AlivelandAuction, AlivelandNFT, owner } = await loadFixture(auctionFixture);
            await AlivelandAuction.setNowOverride(20);
            await expect(
                AlivelandAuction.placeBid(
                    AlivelandNFT.target,
                    firstTokenId,
                    pricePerItem
                )
            ).to.emit(AlivelandAuction, "BidPlaced").withArgs(
                AlivelandNFT.target,
                firstTokenId,
                owner.address,
                pricePerItem
            );
        });
    });

    async function placeBidFixture() {
        const [owner, feeRecipient, minter, bidder, bidder2] = await ethers.getSigners();

        const AlivelandMarketplace = await ethers.deployContract("AlivelandMarketplace");
        AlivelandMarketplace.initialize(feeRecipient, platformFee);

        const AlivelandAuction = await ethers.deployContract("AlivelandAuctionMock", { from: owner.address });

        const AlivelandNFT = await ethers.deployContract(
            "AlivelandERC721", 
            [
                "Aliveland NFT",
                "ALNFT",
                AlivelandAuction.target,
                AlivelandMarketplace.target,
                "ipfs",
                pricePerItem,
                feeRecipient.address,
                owner.address
            ]
        );
        await AlivelandNFT.mint(owner.address, { from: owner.address, value: pricePerItem });
        await AlivelandNFT.mint(owner.address, { from: owner.address, value: pricePerItem });

        await AlivelandNFT.setApprovalForAll(AlivelandAuction.target, true);
        await AlivelandAuction.setNowOverride('10');
        await AlivelandAuction.createAuction(
            AlivelandNFT.target,
            firstTokenId,
            ZERO_ADDRESS,
            reservePrice,
            '12',
            minBidReserve,
            '350'
        );

        await AlivelandAuction.setNowOverride(20);
        await AlivelandAuction.connect(bidder).placeBid(
            AlivelandNFT.target,
            firstTokenId,
            pricePerItem
        );

        return { AlivelandMarketplace, AlivelandNFT, AlivelandAuction, owner, feeRecipient, minter, bidder, bidder2 };
    }

    describe('Withdraw bid', async () => {
        it('Should revert when msgSender is not highest bidder', async () => {
            const { AlivelandAuction, AlivelandNFT, owner, bidder2 } = await loadFixture(placeBidFixture);
            await expect(
                AlivelandAuction.connect(bidder2).withdrawBid(AlivelandNFT.target, firstTokenId)
            ).to.be.reverted;
        });

        it('Should revert when trying to withdraw within 12 hours', async () => {
            const { AlivelandAuction, AlivelandNFT, owner, bidder } = await loadFixture(placeBidFixture);
            await expect(
                AlivelandAuction.connect(bidder).withdrawBid(AlivelandNFT.target, firstTokenId)
            ).to.be.reverted;
        });

        it('Should revert when withdrawing a bid which does not exist', async () => {
            const { AlivelandAuction, AlivelandNFT, owner, bidder } = await loadFixture(placeBidFixture);
            await AlivelandAuction.setNowOverride(45000);
            await expect(
                AlivelandAuction.connect(bidder).withdrawBid(AlivelandNFT.target, '999')
            ).to.be.reverted;
        });

        it('Should revert when the contract is paused', async () => {
            const { AlivelandAuction, AlivelandNFT, owner, bidder } = await loadFixture(placeBidFixture);
            const {_bidder: originalBidder, _bid: originalBid, _lastBidTime: lastBidTime} = await AlivelandAuction.getHighestBidder(AlivelandNFT.target, firstTokenId);
            expect(originalBid).to.equal(pricePerItem);
            expect(originalBidder).to.equal(bidder.address);
    
            await AlivelandAuction.connect(owner.address).toggleIsPaused();
            // await expectRevert(
            //     AlivelandAuction.withdrawBid(AlivelandNFT.target, firstTokenId, {from: bidder}),
            //     "Function is currently paused"
            // );
        });

        it('Should withdraw bid successfully and emit BidWithdrawn event', async () => {
            // const { AlivelandAuction, AlivelandNFT, owner, bidder } = await loadFixture(placeBidFixture);
            // await AlivelandAuction.setNowOverride(45000);
            // await expect(
            //     AlivelandAuction.connect(bidder).withdrawBid(AlivelandNFT.target, firstTokenId)
            // ).to.emit(AlivelandAuction, "BidWithdrawn").withArgs(
            //     AlivelandNFT.target,
            //     firstTokenId,
            //     bidder.address,
            //     pricePerItem
            // );
        });
    });
});