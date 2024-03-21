const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
// const { expect } = require("@nomicfoundation/hardhat-chai-matchers");
const {
    constants,
    expectRevert,
} = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;
const BiddingContractMock = artifacts.require('BiddingContractMock');

describe("Aliveland Auction Contract", () => {
    const firstTokenId = '0';
    const platformFee = '25';
    const pricePerItem = ethers.parseEther("1");
    const reservePrice = ethers.parseEther("1");
    const minBidReserve = true;
    const bidAmount = ethers.parseEther("1.2");
    const bidLowAmount = ethers.parseEther("0.5");
    const TWENTY_TOKENS = ethers.parseEther("2000");
    const TOKENS = ethers.parseEther("1000");
    const payToken = '0x0000000000000000000000000000000000001010';
    const royalty = 250;

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
                TWENTY_TOKENS,
            ],
            bidder
        );

        const AlivelandTokenRegistry = await ethers.deployContract("AlivelandTokenRegistry");
        await AlivelandTokenRegistry.add(payToken);
        const AlivelandAddressRegistry = await ethers.deployContract("AlivelandAddressRegistry");
        await AlivelandAddressRegistry.updateTokenRegistry(AlivelandTokenRegistry.target);
        await AlivelandAddressRegistry.updateMarketplace(AlivelandMarketplace.target);
        await AlivelandAuction.updateAddressRegistry(AlivelandAddressRegistry.target);

        return { AlivelandMarketplace, AlivelandNFT, AlivelandAuction, mockToken, owner, feeRecipient, minter, bidder, marketplace };
    }
  
    describe('Create auction', async () => {
        it('Should revert when not approved', async () => {
            const { AlivelandAuction, AlivelandNFT, mockToken, owner } = await loadFixture(deployTokenFixture);
            await expectRevert(
                AlivelandAuction.createAuction(
                    AlivelandNFT.target,
                    firstTokenId,
                    'art',
                    payToken,
                    reservePrice,
                    '1',
                    minBidReserve,
                    '10'
                ),
                "not owner or contract not approved"
            );
        });

        it('Should revert when end time is larger than start (by 5 minutes)', async () => {
            const { AlivelandAuction, AlivelandNFT, mockToken, owner } = await loadFixture(deployTokenFixture);
            await AlivelandNFT.setApprovalForAll(AlivelandAuction.target, true);
            await AlivelandAuction.setNowOverride('12');
            await expectRevert(
                AlivelandAuction.createAuction(
                    AlivelandNFT.target,
                    firstTokenId,
                    'art',
                    payToken,
                    reservePrice,
                    '1',
                    minBidReserve,
                    '10'
                ),
                "end time must be greater than start (by 5 minutes)"
            );
        });

        it('Should revert when starttime is invalid', async () => {
            const { AlivelandAuction, AlivelandNFT, mockToken, owner } = await loadFixture(deployTokenFixture);
            await AlivelandNFT.setApprovalForAll(AlivelandAuction.target, true);
            await AlivelandAuction.setNowOverride('10');
            await expectRevert(
                AlivelandAuction.createAuction(
                    AlivelandNFT.target,
                    firstTokenId,
                    'art',
                    payToken,
                    reservePrice,
                    '1',
                    minBidReserve,
                    '310'
                ),
                "invalid start time"
            );
        });

        it('Should create auction successfully and emit AuctionCreated event', async () => {
            const { AlivelandAuction, AlivelandNFT, mockToken, owner } = await loadFixture(deployTokenFixture);
            await AlivelandNFT.setApprovalForAll(AlivelandAuction.target, true);
            await AlivelandAuction.setNowOverride('10');
            await expect(
                AlivelandAuction.connect(owner).createAuction(
                    AlivelandNFT.target,
                    firstTokenId,
                    'art',
                    payToken,
                    reservePrice,
                    '12',
                    minBidReserve,
                    '350'
                )
            ).to.emit(AlivelandAuction, "AuctionCreated").withArgs(
                AlivelandNFT.target,
                firstTokenId,
                'art',
                '12',
                '350',
                payToken,
                reservePrice,
                owner.address,
                '1200'
            );
        });
    });

    async function auctionFixture() {
        const [owner, bidder, feeRecipient, minter] = await ethers.getSigners();

        const AlivelandMarketplace = await ethers.deployContract("AlivelandMarketplace");
        AlivelandMarketplace.initialize(feeRecipient, platformFee);

        const AlivelandAuction = await ethers.deployContract("AlivelandAuctionMock");

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
        await AlivelandNFT.mint(owner.address, "", royalty, "nft1", { from: owner.address, value: pricePerItem });
        await AlivelandNFT.mint(owner.address, "", royalty, "nft2", { from: owner.address, value: pricePerItem });

        const mockToken = await ethers.deployContract(
            "MockERC20",
            [
                'Mock ERC20',
                'MOCK',
                TOKENS,
            ],
            bidder
        );

        const AlivelandTokenRegistry = await ethers.deployContract("AlivelandTokenRegistry");
        await AlivelandTokenRegistry.add(mockToken.target);
        const AlivelandAddressRegistry = await ethers.deployContract("AlivelandAddressRegistry");
        await AlivelandAddressRegistry.updateTokenRegistry(AlivelandTokenRegistry.target);
        await AlivelandAddressRegistry.updateMarketplace(AlivelandMarketplace.target);
        await AlivelandAuction.updateAddressRegistry(AlivelandAddressRegistry.target);

        await AlivelandNFT.setApprovalForAll(AlivelandAuction.target, true);
        await AlivelandAuction.setNowOverride('10');
        await AlivelandAuction.createAuction(
            AlivelandNFT.target,
            firstTokenId,
            'art',
            mockToken.target,
            reservePrice,
            '12',
            minBidReserve,
            '350'
        );

        return { AlivelandMarketplace, AlivelandNFT, AlivelandAuction, mockToken, owner, bidder, feeRecipient, minter };
    }

    describe('Place bid', async () => {
        it('Should revert when bidder is smart contract', async () => {
            const { AlivelandAuction, AlivelandNFT, owner } = await loadFixture(auctionFixture);
            const biddingContract = await BiddingContractMock.new(AlivelandAuction.target);
            await expectRevert(
               biddingContract.bid(AlivelandNFT.target, firstTokenId, owner.address, bidAmount),
               "no contracts permitted"
            );
        });

        it('Should revert when bidding outside of the auction duration', async () => {
            const { AlivelandAuction, AlivelandNFT, owner } = await loadFixture(auctionFixture);
            await expectRevert(
                AlivelandAuction.placeBid(
                    AlivelandNFT.target,
                    firstTokenId,
                    owner.address,
                    bidAmount
                ),
                "bidding outside of the auction duration"
            );
        });

        it('Should revert when bid is lower than reserved price', async () => {
            const { AlivelandAuction, AlivelandNFT, owner } = await loadFixture(auctionFixture);
            await AlivelandAuction.setNowOverride(20);
            await expectRevert(
                AlivelandAuction.placeBid(
                    AlivelandNFT.target,
                    firstTokenId,
                    owner.address,
                    bidLowAmount
                ),
                "bid cannot be lower than reserve price"
            );
        });

        it('Should place bid successfully and emit BidPlaced event', async () => {
            const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(auctionFixture);
            await AlivelandAuction.setNowOverride(20);
            await mockToken.approve(AlivelandAuction.target, TOKENS);
            await expect(
                AlivelandAuction.connect(bidder).placeBid(
                    AlivelandNFT.target,
                    firstTokenId,
                    owner.address,
                    pricePerItem
                )
            ).to.emit(AlivelandAuction, "BidPlaced").withArgs(
                AlivelandNFT.target,
                firstTokenId,
                bidder.address,
                owner.address,
                mockToken.target,
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
                TOKENS,
            ],
            bidder
        );

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
        await AlivelandNFT.mint(owner.address, "", royalty, "nft1", { from: owner.address, value: pricePerItem });
        await AlivelandNFT.mint(owner.address, "", royalty, "nft2", { from: owner.address, value: pricePerItem });

        const AlivelandTokenRegistry = await ethers.deployContract("AlivelandTokenRegistry");
        await AlivelandTokenRegistry.add(mockToken.target);
        const AlivelandAddressRegistry = await ethers.deployContract("AlivelandAddressRegistry");
        await AlivelandAddressRegistry.updateTokenRegistry(AlivelandTokenRegistry.target);
        await AlivelandAddressRegistry.updateMarketplace(AlivelandMarketplace.target);
        await AlivelandAuction.updateAddressRegistry(AlivelandAddressRegistry.target);

        await AlivelandNFT.setApprovalForAll(AlivelandAuction.target, true);
        await AlivelandAuction.setNowOverride('10');
        await AlivelandAuction.createAuction(
            AlivelandNFT.target,
            firstTokenId,
            'art',
            mockToken.target,
            reservePrice,
            '12',
            minBidReserve,
            '350'
        );

        await AlivelandAuction.setNowOverride(20);
        await mockToken.approve(AlivelandAuction.target, TOKENS);        
        await AlivelandAuction.connect(bidder).placeBid(
            AlivelandNFT.target,
            firstTokenId,
            owner.address,
            pricePerItem
        );
        return { AlivelandMarketplace, AlivelandNFT, AlivelandAuction, AlivelandAddressRegistry, mockToken, owner, feeRecipient, minter, bidder, bidder2 };
    }

    describe('Withdraw bid', async () => {
        it('Should revert when msgSender is not highest bidder', async () => {
            const { AlivelandAuction, AlivelandNFT, owner, bidder2 } = await loadFixture(placeBidFixture);
            await expectRevert(
               AlivelandAuction.connect(bidder2).withdrawBid(AlivelandNFT.target, firstTokenId),
               "you are not the highest bidder"
            );
        });

        it('Should revert when trying to withdraw within 12 hours', async () => {
            const { AlivelandAuction, AlivelandNFT, owner, bidder } = await loadFixture(placeBidFixture);
            await expectRevert(
                AlivelandAuction.connect(bidder).withdrawBid(AlivelandNFT.target, firstTokenId),
                "can withdraw only after 12 hours (after auction ended)"
            );
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
            await expectRevert(
                AlivelandAuction.connect(bidder).withdrawBid(AlivelandNFT.target, firstTokenId),
                "contract paused"
            );
        });

        it('Should withdraw bid successfully and emit BidWithdrawn event', async () => {
            const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
            const {_bidder: originalBidder, _bid: originalBid, _lastBidTime: lastBidTime} = await AlivelandAuction.getHighestBidder(AlivelandNFT.target, firstTokenId);
            expect(originalBid).to.equal(pricePerItem);
            expect(originalBidder).to.equal(bidder.address);
    
            await AlivelandAuction.setNowOverride(45000);
            await AlivelandAuction.connect(owner).updateBidWithdrawalLockTime('0');

            await expect(
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
                await expectRevert(
                    AlivelandAuction.connect(bidder).resultAuction(AlivelandNFT.target, firstTokenId),
                    "sender must be item owner"
                );
            });
    
            it('Should revert when auction is not ended', async () => {
                const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
                await expectRevert(
                    AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId),
                    "auction not ended"
                );
            });
    
            it('Should revert when there is no open bid', async () => {
                const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(auctionFixture);
                await AlivelandAuction.setNowOverride(45000);
                await expectRevert(
                    AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId),
                    "no open bids"
                );
            });
            
            it('Should revert when highest bid is below reservePrice', async () => {
                const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(auctionFixture);
                await AlivelandAuction.setNowOverride(20);
                await mockToken.approve(AlivelandAuction.target, TOKENS);
                await AlivelandAuction.connect(bidder).placeBid(
                    AlivelandNFT.target,
                    firstTokenId,
                    owner.address,
                    pricePerItem
                );
                await AlivelandAuction.updateAuctionReservePrice(
                    AlivelandNFT.target,
                    firstTokenId,
                    bidAmount
                )
                await AlivelandAuction.setNowOverride(45000);
                await expectRevert(
                    AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId),
                    'highest bid is below reservePrice'
                );
            });
            
            it('Should revert when auction already resulted', async () => {
                const { AlivelandNFT, AlivelandAuction, owner, bidder } = await loadFixture(placeBidFixture);

                await AlivelandAuction.setNowOverride(45000);
                await AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId);
                await expect(
                    AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId)
                ).to.be.reverted;
            });
        });
        
        describe('Successfully resulting an auction', async () => {
            it('Should transfer token to the winner', async () => {
                const { AlivelandNFT, AlivelandAuction, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
                await AlivelandAuction.setNowOverride(45000);
        
                expect(await AlivelandNFT.ownerOf(firstTokenId)).to.be.equal(owner.address);
        
                await AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId);
        
                expect(await AlivelandNFT.ownerOf(firstTokenId)).to.be.equal(bidder.address);
            });
    
            it('Should transfer funds to the token creator and platform', async () => {
                const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder, feeRecipient } = await loadFixture(auctionFixture);
                await AlivelandAuction.initialize(feeRecipient.address);

                await AlivelandAuction.setNowOverride(20);
                await mockToken.approve(AlivelandAuction.target, TOKENS);
                await AlivelandAuction.connect(bidder).placeBid(
                    AlivelandNFT.target,
                    firstTokenId,
                    owner.address,
                    bidAmount
                );

                await AlivelandAuction.setNowOverride(45000);
                await AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId);

                expect(feeRecipient).to.changeEtherBalance(bidder.address, ethers.parseEther("0.025"));
                expect(owner).to.changeEtherBalance(bidder.address, bidAmount);
            });
    
            it('Should transfer funds to the token to only the creator when reserve meet directly', async () => {
                const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder, feeRecipient } = await loadFixture(placeBidFixture);
                await AlivelandAuction.setNowOverride(45000);
        
                await AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId);

                expect(owner).to.changeEtherBalance(bidder.address, pricePerItem);
                expect(feeRecipient).to.changeEtherBalance(bidder.address, '0');
            });
    
            it('Should record primary sale price on garment NFT', async () => {
                const { AlivelandMarketplace, AlivelandNFT, AlivelandAuction, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
                await AlivelandAuction.setNowOverride(45000);
        
                await expect(
                    AlivelandAuction.resultAuction(
                        AlivelandNFT.target, 
                        firstTokenId
                    )
                ).to.emit(AlivelandAuction, "AuctionResulted").withArgs(
                    owner.address,
                    AlivelandNFT.target,
                    firstTokenId,
                    bidder.address,
                    mockToken.target,
                    pricePerItem
                );
            });
        });
    });

    describe('Cancel auction', async () => {
        it('Should revert when sender is not item owner', async () => {
            const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
            await expectRevert(
                AlivelandAuction.connect(bidder).cancelAuction(AlivelandNFT.target, firstTokenId),
                "sender must be owner"
            );
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
            const { AlivelandAuction, AlivelandNFT, mockToken, owner, bidder } = await loadFixture(placeBidFixture);
            await AlivelandAuction.setNowOverride('400');

            await AlivelandAuction.resultAuction(AlivelandNFT.target, firstTokenId);

            await expect(
                AlivelandAuction.cancelAuction(AlivelandNFT.target, firstTokenId)
            ).to.be.reverted;
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

    describe('reclaimERC20()', async () => {
        describe('validation', async () => {
            it('Should reclaim erc20 by only owner', async () => {
                const { AlivelandAuction, mockToken, owner, bidder } = await loadFixture(deployTokenFixture);
                await expectRevert(
                    AlivelandAuction.connect(bidder).reclaimERC20(mockToken.target),
                    'Ownable: caller is not the owner'
                );
            });
        
            it('Should reclaim Erc20 successfully', async () => {
                const { AlivelandAuction, mockToken, owner, bidder } = await loadFixture(deployTokenFixture);

                await mockToken.transfer(AlivelandAuction.target, TWENTY_TOKENS, { from: bidder });        
                const adminBalanceBeforeReclaim = await mockToken.balanceOf(owner.address);
                expect(await mockToken.balanceOf(AlivelandAuction.target)).to.be.equal(TWENTY_TOKENS);

                await AlivelandAuction.connect(owner).reclaimERC20(mockToken.target);
        
                expect(await mockToken.balanceOf(AlivelandAuction.target)).to.be.equal('0');
                expect(await mockToken.balanceOf(owner.address)).to.be.greaterThan(adminBalanceBeforeReclaim);
            });
        });
    });
});