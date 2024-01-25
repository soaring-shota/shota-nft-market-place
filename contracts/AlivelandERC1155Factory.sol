// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AlivelandERC1155.sol";

interface IERC1155Tradable {
    function name() external returns (string memory _name);
    function symbol() external returns (string memory _symbol);
}

contract AlivelandERC1155Factory is Ownable {
    string public baseURI;
    uint256 public mintFee;
    uint256 public platformFee;
    address payable public feeRecipient;

    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;
    
    mapping(address => bool) public exists;
    mapping(address => uint256) public indexes;
    mapping(address => mapping(uint256 => address)) public contracts;
    
    event ContractCreated(address creator, address nft, string name);
    event ContractDisabled(address caller, address nft);

    constructor(
        string memory _baseURI,
        uint256 _mintFee,
        uint256 _platformFee,
        address payable _feeRecipient
    ) {
        baseURI = _baseURI;
        mintFee = _mintFee;
        platformFee = _platformFee;
        feeRecipient = _feeRecipient;
    }

    function updateBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
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
            _ipfsUrl,
            mintFee,
            feeRecipient,
            msg.sender
        );
        exists[address(nft)] = true;
        contracts[msg.sender][indexes[msg.sender]] = address(nft);
        indexes[msg.sender]++;

        emit ContractCreated(_msgSender(), address(nft), _name);
        return address(nft);
    }

    function registerERC1155Contract(address _tokenContractAddress)
        external
        onlyOwner
    {
        require(!exists[_tokenContractAddress], "AlivelandERC1155 contract already registered");
        require(IERC165(_tokenContractAddress).supportsInterface(INTERFACE_ID_ERC1155), "Not an ERC1155 contract");
        exists[_tokenContractAddress] = true;
        contracts[msg.sender][indexes[msg.sender]] = _tokenContractAddress;
        indexes[msg.sender]++;
        emit ContractCreated(_msgSender(), _tokenContractAddress, IERC1155Tradable(_tokenContractAddress).name());
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
