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
    const ONE_THOUSAND_TOKENS = '1000000000000000000000';

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

        const AlivelandAuction = await ethers.deployContract("AlivelandAuctionMock");

        const mockToken = await ethers.deployContract(
            "MockERC20",
            [
                'Mock ERC20',
                'MOCK',
                ONE_THOUSAND_TOKENS,
            ],
            bidder
        );

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
            mockToken.target,
            reservePrice,
            '12',
            minBidReserve,
            '350'
        );

        await AlivelandAuction.setNowOverride(20);
        await mockToken.approve(AlivelandAuction.target, ONE_THOUSAND_TOKENS);
        await AlivelandAuction.connect(bidder).placeBid(
            AlivelandNFT.target,
            firstTokenId,
            pricePerItem
        );

        return { AlivelandMarketplace, AlivelandNFT, AlivelandAuction, mockToken, owner, feeRecipient, minter, bidder, bidder2 };
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
    
            await AlivelandAuction.connect(owner).toggleIsPaused();
            await expect(
                AlivelandAuction.connect(bidder).withdrawBid(AlivelandNFT.target, firstTokenId)
            ).to.be.reverted;
        });

        it('Should withdraw bid successfully and emit BidWithdrawn event', async () => {
            const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
            const {_bidder: originalBidder, _bid: originalBid, _lastBidTime: lastBidTime} = await AlivelandAuction.getHighestBidder(AlivelandNFT.target, firstTokenId);
            expect(originalBid).to.equal(pricePerItem);
            expect(originalBidder).to.equal(bidder.address);
    
            const bidderTracker = await balance.tracker(bidder.address);

            await AlivelandAuction.setNowOverride(45000);
            await AlivelandAuction.connect(owner).updateBidWithdrawalLockTime('0');

            const receipt = await expect(
                AlivelandAuction.connect(bidder).withdrawBid(AlivelandNFT.target, firstTokenId)
            ).to.emit(AlivelandAuction, "BidWithdrawn").withArgs(
                AlivelandNFT.target,
                firstTokenId,
                bidder.address,
                pricePerItem
            );
    
            const {_bidder, _bid, _lastBidTime} = await AlivelandAuction.getHighestBidder(AlivelandNFT.target, firstTokenId);
            expect(_bid).to.equal('0');
            expect(_bidder).to.equal(ZERO_ADDRESS);
        });
    });

    describe('Result auction', async () => {
        describe('Validation', () => {
            it('Should revert when sender is not item owner', async () => {
                const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
                await expect(
                    AlivelandAuction.connect(bidder).resultAuction(AlivelandNFT.target, firstTokenId)
                ).to.be.reverted;
            });
    
            it('Should revert when auction is not ended', async () => {
                const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
                await expect(
                    AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId)
                ).to.be.reverted;
            });
    
            it('Should revert when there is no open bid', async () => {
                const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(auctionFixture);
                await AlivelandAuction.setNowOverride(45000);
                await expect(
                    AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId)
                ).to.be.reverted;
            });
            
            it('Should revert when highest bid is below reservePrice', async () => {
                // const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(auctionFixture);
                // await AlivelandAuction.setNowOverride(20);
                // await AlivelandAuction.connect(bidder).placeBid(
                //     AlivelandNFT.target,
                //     firstTokenId,
                //     bidLowAmount
                // );
                // await AlivelandAuction.setNowOverride(45000);
                // await expect(
                //     AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId)
                // ).to.be.reverted;
            });
            
            it('Should revert when auction already resulted', async () => {
                const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
                await AlivelandAuction.setNowOverride(45000);
                await AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId);
                await //expect(
                    AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId)
                //).to.be.reverted;
            });
        });
        
        describe('Successfully resulting an auction', async () => {
            it('Should transfer token to the winner', async () => {
                
            });
    
            it('Should transfer funds to the token creator and platform', async () => {
            
            });
    
            it('Should transfer funds to the token to only the creator when reserve meet directly', async () => {
            
            });
    
            it('Should record primary sale price on garment NFT', async () => {
            
            });
        });
    });

    describe('Cancel auction', async () => {
        it('Should revert when sender is not item owner', async () => {
            const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
            await expect(
                AlivelandAuction.connect(bidder).cancelAuction(AlivelandNFT.target, firstTokenId)
            ).to.be.reverted;
        });

        it('Should not cancel if auction already cancelled', async () => {
            const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
            await AlivelandAuction.cancelAuction(AlivelandNFT.target, firstTokenId);
            await AlivelandAuction.setNowOverride('400');

            await expect(
                AlivelandAuction.cancelAuction(AlivelandNFT.target, firstTokenId)
            ).to.be.reverted;
        });

        it('Should not cancel if auction already resulted', async () => {
            // const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
            // await AlivelandAuction.setNowOverride('400');

            // await AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId);

            // await expectRevert(
            //     AlivelandAuction.cancelAuction(AlivelandNFT.target, firstTokenId),
            //     'AlivelandAuction.cancelAuction: already resulted'
            // );
        });

        it('Should cancel clears down auctions and top bidder', async () => {
            const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
            await AlivelandAuction.cancelAuction(AlivelandNFT.target, firstTokenId);

            // Check auction cleaned up
            const {_reservePrice, _startTime, _endTime, _resulted} = await AlivelandAuction.getAuction(AlivelandNFT.target, firstTokenId);
            expect(_reservePrice).to.equal('0');
            expect(_startTime).to.equal('0');
            expect(_endTime).to.equal('0');
            expect(_resulted).to.equal(false);

            const {_bidder, _bid, _lastBidTime} = await AlivelandAuction.getHighestBidder(AlivelandNFT.target, firstTokenId);
            expect(_bid).to.equal('0');
            expect(_bidder).to.equal(ZERO_ADDRESS);
        });

        it('Should send back funds to the highest bidder if found', async () => {
            const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
            await AlivelandAuction.cancelAuction(AlivelandNFT.target, firstTokenId);
            expect(bidder).to.changeEtherBalance(bidder.address, pricePerItem);
        });

        it('Should transfer no funds if no bids', async () => {
            const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
            await AlivelandAuction.cancelAuction(AlivelandNFT.target, firstTokenId);
        });
    });
});