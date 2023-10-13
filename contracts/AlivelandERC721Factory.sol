// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AlivelandERC721.sol";

contract AlivelandERC721Factory is Ownable {
    address public auction;
    address public marketplace;
    string public baseURI;
    uint256 public mintFee;
    uint256 public platformFee;
    address payable public feeRecipient;

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    
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
    ) {
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

    function createNFTContract(string memory _name, string memory _symbol)
        external
        payable
        returns (address)
    {
        require(msg.value >= platformFee, "Insufficient funds.");
        (bool success,) = feeRecipient.call{value: msg.value}("");
        require(success, "Transfer failed");

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

    function registerERC721Contract(address _tokenContractAddress)
        external
        onlyOwner
    {
        require(!exists[_tokenContractAddress], "AlivelandERC721 contract already registered");
        require(IERC165(_tokenContractAddress).supportsInterface(INTERFACE_ID_ERC721), "Not an ERC721 contract");
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
