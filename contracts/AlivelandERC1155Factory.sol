// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AlivelandERC1155.sol";

contract AlivelandERC1155Factory is Ownable {
    address public marketplace;
    string public baseURI;
    uint256 public mintFee;
    uint256 public platformFee;
    address payable public feeRecipient;

    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;
    
    mapping(address => bool) public exists;
    mapping(address => uint256) public indexes;
    mapping(address => mapping(uint256 => address)) public contracts;  
    mapping (address => string) public ipfsUrl;  
    
    event ContractCreated(address creator, address nft, string name, bool iserc721);
    event ContractDisabled(address caller, address nft);

    constructor(
        address _marketplace,
        string memory _baseURI,
        uint256 _mintFee,
        uint256 _platformFee,
        address payable _feeRecipient
    ) {
        marketplace = _marketplace;
        baseURI = _baseURI;
        mintFee = _mintFee;
        platformFee = _platformFee;
        feeRecipient = _feeRecipient;
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

    function updateCollectionIpfsUrl(address _collection, string memory _ipfsUrl) external onlyOwner {
        ipfsUrl[_collection] = _ipfsUrl;
    }

    function getCollectionIpfsUrl(address _collection) external onlyOwner view returns (string memory) {
        return ipfsUrl[_collection];
    }

    function createNFTContract(string memory _name, string memory _symbol, string memory _ipfsUrl)
        external
        payable
        returns (address)
    {
        require(msg.value >= platformFee, "Insufficient funds.");
        (bool success,) = feeRecipient.call{value: msg.value}("");
        require(success, "Transfer failed");

        AlivelandERC1155 nft = new AlivelandERC1155(
            _name,
            _symbol,
            baseURI,
            mintFee,
            feeRecipient,
            msg.sender
        );
        exists[address(nft)] = true;
        contracts[msg.sender][indexes[msg.sender]] = address(nft);
        ipfsUrl[address(nft)] = _ipfsUrl;
        indexes[msg.sender]++;

        emit ContractCreated(_msgSender(), address(nft), _name, false);
        return address(nft);
    }

    function registerERC1155Contract(address _tokenContractAddress, string memory _name)
        external
        onlyOwner
    {
        require(!exists[_tokenContractAddress], "AlivelandERC1155 contract already registered");
        require(IERC165(_tokenContractAddress).supportsInterface(INTERFACE_ID_ERC1155), "Not an ERC1155 contract");
        exists[_tokenContractAddress] = true;
        emit ContractCreated(_msgSender(), _tokenContractAddress, _name, false);
    }

    function disableTokenContract(address _tokenContractAddress)
        external
        onlyOwner
    {
        require(exists[_tokenContractAddress], "AlivelandNFT contract is not registered");
        exists[_tokenContractAddress] = false;
        emit ContractDisabled(_msgSender(), _tokenContractAddress);
    }

    function getContractList(address _creator) external view returns (address[] memory) {
        address[] memory ret = new address[](indexes[_creator]);
        for (uint256 i = 0; i < indexes[_creator]; i++) {
            ret[i] = contracts[_creator][i];
        }
        return ret;
    }
}
