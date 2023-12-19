// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
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
    ERC721Burnable,
    ERC721Pausable,
    Ownable
{
    using Counters for Counters.Counter;
    using Strings for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    Counters.Counter private tokenIdTracker;

    string private baseTokenURI;
    uint256 public mintFee;
    address payable public feeRecipient;
    mapping (uint256 => string) private cid;
    
    mapping(uint256 => address) private owners;
    mapping(address => uint256) private balances;
    mapping(uint256 => address) private tokenApprovals;

    event Minted(
        uint256 tokenId,
        address beneficiary,
        string  tokenUri,
        address minter
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
        uint256 _mintFee,
        address payable _feeRecipient,
        address _deployer
    ) ERC721(_name, _symbol) {
        baseTokenURI = _baseTokenURI;
        mintFee = _mintFee;
        feeRecipient = _feeRecipient;

        super._transferOwnership(_deployer);

        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        _setupRole(MINTER_ROLE, _deployer);
        _setupRole(PAUSER_ROLE, _deployer);
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
        _requireMinted(_tokenId);

        string memory base = _baseURI();
        
        if (bytes(base).length > 0) {
            return string(abi.encodePacked(base, cid[_tokenId]));
        }

        return super.tokenURI(_tokenId);
    }

    function mint(address _to, string calldata _cid) public payable virtual returns (uint256) {
        require(hasRole(MINTER_ROLE, _msgSender()), "AlivelandERC721: must have minter role to mint");
        require(msg.value >= mintFee, "AlivelandERC721: insufficient funds to mint");

        uint256 newTokenId = tokenIdTracker.current();
        _mint(_to, newTokenId);
        
        cid[newTokenId] = _cid;
        string memory newTokenURI = tokenURI(newTokenId);
        _setTokenURI(newTokenId, newTokenURI);

        (bool success,) = feeRecipient.call{value : msg.value}("");
        require(success, "AlivelandERC721: transfer failed");

        tokenIdTracker.increment();

        emit Minted(newTokenId, _to, newTokenURI, _msgSender());

        return newTokenId;
    }

    function burn(uint256 _tokenId) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "AlivelandERC721: caller is not token owner or approved");
        ERC721._burn(_tokenId);
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
    ) public view virtual override(AccessControlEnumerable, ERC721, ERC721Enumerable, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    function _burn(uint256 _tokenId) internal virtual override(ERC721, ERC721URIStorage) {
        address owner = ERC721.ownerOf(_tokenId);

        _beforeTokenTransfer(owner, address(0), _tokenId, 1);

        owner = ERC721.ownerOf(_tokenId);

        delete tokenApprovals[_tokenId];

        unchecked {
            balances[owner] -= 1;
        }
        delete owners[_tokenId];

        emit Transfer(owner, address(0), _tokenId);

        _afterTokenTransfer(owner, address(0), _tokenId, 1);
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
