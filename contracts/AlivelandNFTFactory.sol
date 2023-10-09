// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AlivelandERC721.sol";
import "./AlivelandERC1155.sol";

contract AlivelandNFTFactory is Ownable {
   
    event ContractCreated(address creator, address nft);

    address public auction;
    address public marketplace;
    uint256 public mintFee;
    uint256 public platformFee;
    string public baseURI;
    address payable public feeRecipient;
    mapping(address => bool) public exists;

    constructor(
        address _auction,
        address _marketplace,
        string memory _baseURI,
        uint256 _mintFee,
        address payable _feeRecipient,
        uint256 _platformFee
    ) public {
        auction = _auction;
        marketplace = _marketplace;
        baseURI = _baseURI;
        mintFee = _mintFee;
        feeRecipient = _feeRecipient;
        platformFee = _platformFee;
    }

    function updateAuction(address _auction) external onlyOwner {
        auction = _auction;
    }

    function updateMarketplace(address _marketplace) external onlyOwner {
        marketplace = _marketplace;
    }

    function updateMintFee(uint256 _mintFee) external onlyOwner {
        mintFee = _mintFee;
    }

    function updatePlatformFee(uint256 _platformFee) external onlyOwner {
        platformFee = _platformFee;
    }

    function updateFeeRecipient(address payable _feeRecipient)
        external
        onlyOwner
    {
        feeRecipient = _feeRecipient;
    }

    function createERC721Contract(string memory _name, string memory _symbol)
        external
        payable
        returns (address)
    {
        require(msg.value >= platformFee, "Insufficient funds.");
        (bool success_,) = feeRecipient.call{value: msg.value}("");
        require(success_, "Transfer failed");

        AlivelandERC721 nft = new AlivelandERC721(
            _name,
            _symbol,
            baseURI,
            mintFee,
            feeRecipient
        );
        exists[address(nft)] = true;
        emit ContractCreated(_msgSender(), address(nft));
        return address(nft);
    }

    function createERC1155Contract()
        external
        payable
        returns (address)
    {
        require(msg.value >= platformFee, "Insufficient funds.");
        (bool success_,) = feeRecipient.call{value: msg.value}("");
        require(success_, "Transfer failed");

        AlivelandERC1155 nft = new AlivelandERC1155(
            baseURI,
            mintFee,
            feeRecipient
        );
        exists[address(nft)] = true;
        emit ContractCreated(_msgSender(), address(nft));
        return address(nft);
    }
}
