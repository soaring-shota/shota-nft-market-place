// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "../AlivelandMarketplace.sol";

contract AlivelandAuctionMock is AlivelandMarketplace {
    uint256 public nowOverride;

    function setNowOverride(uint256 _now) external {
        nowOverride = _now;
    }

    function _getNow() internal override view returns (uint256) {
        return nowOverride;
    }
}
