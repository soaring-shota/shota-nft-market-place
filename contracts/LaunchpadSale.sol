// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "./LaunchpadERC721.sol";

contract LaunchpadSale {
    LaunchpadERC721 public collection;

    constructor(LaunchpadERC721 _collection) {
        collection = _collection;
    }

    function buy(uint24 count) external payable {
        collection.mint{value: msg.value}(count);
    }

    function soldOut() external view returns (uint256) {
        return collection.totalSupply();
    }

    function remaining() external view returns (uint256) {
        return collection.maxSupply() - collection.totalSupply();
    }

    function maxSelling() external view returns (uint256) {
        return collection.maxSupply();
    }

    function startTime() external view returns (uint256) {
        return collection.saleStartTime();
    }

    function endTime() external view returns (uint256) {
        return collection.saleEndTime();
    }

    receive() external payable {}
}
