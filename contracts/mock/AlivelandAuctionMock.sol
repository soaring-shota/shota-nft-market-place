// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "../AlivelandAuction.sol";

contract AlivelandAuctionMock is AlivelandAuction {
    uint256 public nowOverride;

    function setNowOverride(uint256 _now) external {
        nowOverride = _now;
    }

    function _getNow() internal override view returns (uint256) {
        return nowOverride;
    }
}
