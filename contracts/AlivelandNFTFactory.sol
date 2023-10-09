// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AlivelandERC721.sol";
import "./AlivelandERC1155.sol";

contract AlivelandNFTFactory is Ownable {
    address public auction;
    address public marketplace;
    string public baseURI;
    uint256 public mintFee;
    uint256 public platformFee;
    address payable public feeRecipient;

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;
    
    mapping(address => bool) public exists;
    
    event ContractCreated(address creator, address nft);
    event ContractDisabled(address caller, address nft);

    constructor(
        address _auction,
        address _marketplace,
        string memory _baseURI,
        uint256 _mintFee,
        uint256 _platformFee,
        address payable _feeRecipient
    ) public {
        auction = _auction;
        marketplace = _marketplace;
        baseURI = _baseURI;
        mintFee = _mintFee;
        platformFee = _platformFee;
        feeRecipient = _feeRecipient;
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
            auction,
            marketplace,
            baseURI,
            mintFee,
            feeRecipient,
            msg.sender
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
            feeRecipient,
            msg.sender
        );
        exists[address(nft)] = true;
        emit ContractCreated(_msgSender(), address(nft));
        return address(nft);
    }

    function registerERC721Contract(address _tokenContractAddress)
        external
        onlyOwner
    {
        require(!exists[_tokenContractAddress], "AlivelandERC721 contract already registered");
        require(IERC165(_tokenContractAddress).supportsInterface(INTERFACE_ID_ERC721), "Not an ERC721 contract");
        exists[_tokenContractAddress] = true;
        emit ContractCreated(_msgSender(), _tokenContractAddress);
    }

    function registerERC1155Contract(address _tokenContractAddress)
        external
        onlyOwner
    {
        require(!exists[_tokenContractAddress], "AlivelandERC1155 contract already registered");
        require(IERC165(_tokenContractAddress).supportsInterface(INTERFACE_ID_ERC1155), "Not an ERC1155 contract");
        exists[_tokenContractAddress] = true;
        emit ContractCreated(_msgSender(), _tokenContractAddress);
    }

    function disableTokenContract(address _tokenContractAddress)
        external
        onlyOwner
    {
        require(exists[_tokenContractAddress], "AlivelandNFT contract is not registered");
        exists[_tokenContractAddress] = false;
        emit ContractDisabled(_msgSender(), _tokenContractAddress);
    }
}
