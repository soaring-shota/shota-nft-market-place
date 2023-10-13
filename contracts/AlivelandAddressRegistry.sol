// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AlivelandAddressRegistry is Ownable {
    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    address public auction;
    address public marketplace;
    address public erc721Factory;
    address public erc1155Factory;
    address public tokenRegistry;

    function updateAuction(address _auction) external onlyOwner {
        auction = _auction;
    }

    function updateMarketplace(address _marketplace) external onlyOwner {
        marketplace = _marketplace;
    }

    function updateERC721Factory(address _factory) external onlyOwner {
        erc721Factory = _factory;
    }

    function updateERC1155Factory(address _factory) external onlyOwner {
        erc1155Factory = _factory;
    }

    function updateTokenRegistry(address _tokenRegistry) external onlyOwner {
        tokenRegistry = _tokenRegistry;
    }
}
