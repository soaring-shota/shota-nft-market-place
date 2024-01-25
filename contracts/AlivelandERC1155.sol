// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract AlivelandERC1155 is Context, Ownable, AccessControlEnumerable, ERC1155Pausable, ERC1155Supply, ERC1155URIStorage {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    Counters.Counter private tokenIdTracker;

    uint256 public mintFee;
    uint256 public totalItems;
    string public metadataUrl;
    address payable public feeRecipient;
    string public name;
    string public symbol;

    event Minted(
        uint256 tokenId,
        address beneficiary,
        string  tokenUri,
        address minter,
        string name
    );

    event BatchMinted(
        address beneficiary,
        address minter
    );
    
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        string memory _metadataUrl,
        uint256 _mintFee,
        address payable _feeRecipient,
        address _deployer
    ) ERC1155(_uri) {
        name = _name;
        symbol = _symbol;
        metadataUrl = _metadataUrl;
        mintFee = _mintFee;
        feeRecipient = _feeRecipient;

        super._transferOwnership(_deployer);

        _setBaseURI(_uri);
        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        _setupRole(MINTER_ROLE, _deployer);
        _setupRole(PAUSER_ROLE, _deployer);
    }

    function updateMetadataUrl(string memory _url) external onlyOwner {
        metadataUrl = _url;
    }

    function uri(uint256 _tokenId) override(ERC1155, ERC1155URIStorage) public view returns (string memory) {
        return super.uri(_tokenId);
    }

    function mint(address _to, uint256 _amount, string memory _cid, string memory _name) public payable virtual {
        uint256 newTokenId = tokenIdTracker.current();
        tokenIdTracker.increment();

        mintById(_to, newTokenId, _amount, _cid, _name);
    }

    function mintById(address _to, uint256 _id, uint256 _amount, string memory _cid, string memory _name) public payable virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "AlivelandERC1155: must have minter role to mint");
        require(msg.value >= (mintFee * _amount), "AlivelandERC1155: insufficient funds to mint");
        
        (bool success,) = feeRecipient.call{value : msg.value}("");
        require(success, "AlivelandERC1155: transfer failed");

        _mint(_to, _id, _amount, "");
        _setURI(_id, _cid);
        
        emit Minted(_id, _to, uri(_id), _msgSender(), _name);
    }

    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "AlivelandERC1155: must have pauser role to pause");
        _pause();
    }

    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "AlivelandERC1155: must have pauser role to unpause");
        _unpause();
    }
    
    function supportsInterface(
        bytes4 _interfaceId
    ) public view virtual override(AccessControlEnumerable, ERC1155) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    function _beforeTokenTransfer(
        address _operator,
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal virtual override(ERC1155, ERC1155Pausable, ERC1155Supply) {
        super._beforeTokenTransfer(_operator, _from, _to, _ids, _amounts, _data);
    }

    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal override {
        totalItems += amount;
        super._mint(to, id, amount, data);
    }
}
