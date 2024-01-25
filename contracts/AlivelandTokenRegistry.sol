// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract AlivelandTokenRegistry is Ownable {
  event TokenAdded(address token);
  event TokenRemoved(address token);

  mapping(address => bool) public enabled;

  function add(address token) external onlyOwner {
    require(!enabled[token], "token already added");
    enabled[token] = true;
    emit TokenAdded(token);
  }

  function remove(address token) external onlyOwner {
    require(enabled[token], "token not exist");
    enabled[token] = false;
    emit TokenRemoved(token);
  }
}
