// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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

    address auction;
    address marketplace;
    string private baseTokenURI;
    uint256 public mintFee;
    address payable public feeRecipient;
    address private contractOwner;
    string public baseExtension = ".json";
    
    mapping(uint256 => address) private owners;
    mapping(address => uint256) private balances;
    mapping(uint256 => address) private tokenApprovals;

    event UpdateMintFee(
        uint256 mintFee
    );
    event UpdateFeeRecipient(
        address payable feeRecipient
    );

    constructor(
        string memory _name, 
        string memory _symbol,
        address _auction,
        address _marketplace,
        string memory _baseTokenURI,
        uint256 _mintFee,
        address payable _feeRecipient,
        address _deployer
    ) ERC721(_name, _symbol) {
        auction = _auction;
        marketplace = _marketplace;
        baseTokenURI = _baseTokenURI;
        mintFee = _mintFee;
        feeRecipient = _feeRecipient;
        contractOwner = _deployer;

        super._transferOwnership(contractOwner);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "AlivelandERC721: Only the owner can call this function");
        _;
    }

    function updateMintFee(uint256 _mintFee) external onlyContractOwner {
        mintFee = _mintFee;
        emit UpdateMintFee(_mintFee);
    }

    function updateFeeRecipient(address payable _feeRecipient) external onlyContractOwner {
        feeRecipient = _feeRecipient;
        emit UpdateFeeRecipient(_feeRecipient);
    }
    
    function tokenURI(uint256 _tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        _requireMinted(_tokenId);

        string memory base_ = _baseURI();
        uint num_ = 5001 + _tokenId;
        
        if (bytes(base_).length > 0) {
            return string(abi.encodePacked(base_, num_.toString(), baseExtension));
        }

        return super.tokenURI(_tokenId);
    }

    function mint(address _to) public payable virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "AlivelandERC721: must have minter role to mint");
        require(msg.value >= mintFee, "AlivelandERC721: insufficient funds to mint");

        uint256 newTokenId_ = tokenIdTracker.current();
        _mint(_to, newTokenId_);
        
        string memory newTokenURI_ = tokenURI(newTokenId_);
        _setTokenURI(newTokenId_, newTokenURI_);

        (bool success_,) = feeRecipient.call{value : msg.value}("");
        require(success_, "AlivelandERC721: transfer failed");

        tokenIdTracker.increment();
    }

    function burn(uint256 _tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
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
        address owner_ = ERC721.ownerOf(_tokenId);

        _beforeTokenTransfer(owner_, address(0), _tokenId, 1);

        // Update ownership in case tokenId was transferred by `_beforeTokenTransfer` hook
        owner_ = ERC721.ownerOf(_tokenId);

        // Clear approvals
        delete tokenApprovals[_tokenId];

        unchecked {
            // Cannot overflow, as that would require more tokens to be burned/transferred
            // out than the owner initially received through minting and transferring in.
            balances[owner_] -= 1;
        }
        delete owners[_tokenId];

        emit Transfer(owner_, address(0), _tokenId);

        _afterTokenTransfer(owner_, address(0), _tokenId, 1);
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
