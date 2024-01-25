// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AlivelandERC721 is
    Context,
    AccessControlEnumerable,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Pausable,
    ERC721Royalty,
    Ownable
{
    using Counters for Counters.Counter;
    using Strings for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    Counters.Counter private tokenIdTracker;

    string private baseTokenURI;
    string public metadataUrl;
    uint256 public mintFee;
    address payable public feeRecipient;

    event Minted(
        uint256 tokenId,
        address beneficiary,
        string  tokenUri,
        address minter,
        string name
    );

    event UpdateMintFee(
        uint256 mintFee
    );

    event UpdateFeeRecipient(
        address payable feeRecipient
    );

    constructor(
        string memory _name, 
        string memory _symbol,
        string memory _baseTokenURI,
        string memory _metadataUrl,
        uint256 _mintFee,
        address payable _feeRecipient,
        address _deployer
    ) ERC721(_name, _symbol) {
        baseTokenURI = _baseTokenURI;
        mintFee = _mintFee;
        feeRecipient = _feeRecipient;
        metadataUrl = _metadataUrl;

        super._transferOwnership(_deployer);

        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        _setupRole(MINTER_ROLE, _deployer);
        _setupRole(PAUSER_ROLE, _deployer);
    }

    function updateMetadataUrl(string memory _url) external onlyOwner {
        metadataUrl = _url;
    }

    function updateMintFee(uint256 _mintFee) external onlyOwner {
        mintFee = _mintFee;
        emit UpdateMintFee(_mintFee);
    }

    function updateFeeRecipient(address payable _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
        emit UpdateFeeRecipient(_feeRecipient);
    }
    
    function tokenURI(uint256 _tokenId) public view virtual override (ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(_tokenId);
    }

    function mint(address _to, string calldata _cid, uint96 _royalty, string memory _name) public payable virtual returns (uint256) {
        require(hasRole(MINTER_ROLE, _msgSender()), "AlivelandERC721: must have minter role to mint");
        require(msg.value >= mintFee, "AlivelandERC721: insufficient funds to mint");

        uint256 newTokenId = tokenIdTracker.current();
        tokenIdTracker.increment();
        
        (bool success,) = feeRecipient.call{value : msg.value}("");
        require(success, "AlivelandERC721: transfer failed");

        _mint(_to, newTokenId);
        _setTokenURI(newTokenId, _cid);
        _setTokenRoyalty(newTokenId, _msgSender(), _royalty);

        emit Minted(newTokenId, _to, tokenURI(newTokenId), _msgSender(), _name);

        return newTokenId;
    }

    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _burn(tokenId);
    }

    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "AlivelandERC721: must have pauser role to pause");
        _pause();
    }

    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "AlivelandERC721: must have pauser role to unpause");
        _unpause();
    }

    function supportsInterface(
        bytes4 _interfaceId
    ) public view virtual override(AccessControlEnumerable, ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Royalty) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    function _burn(uint256 _tokenId) internal virtual override(ERC721, ERC721URIStorage, ERC721Royalty) {
        ERC721URIStorage._burn(_tokenId);
        _resetTokenRoyalty(_tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _firstTokenId,
        uint256 _batchSize
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(_from, _to, _firstTokenId, _batchSize);
    }
}
