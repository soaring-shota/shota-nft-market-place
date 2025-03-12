// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "../AlivelandMarketplace.sol";

contract BiddingContractMock {
    AlivelandMarketplace public auctionContract;

    constructor(AlivelandMarketplace _auctionContract) {
        auctionContract = _auctionContract;
    }

    function bid(address _nftAddress, uint256 _tokenId, address _owner, uint256 _bidAmount) external {
        auctionContract.placeBid(_nftAddress, _tokenId, _bidAmount);
    }
}
