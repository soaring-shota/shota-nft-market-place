// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract AlivelandERC1155 is Context, Ownable, AccessControlEnumerable, ERC1155Burnable, ERC1155Pausable {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    Counters.Counter private tokenIdTracker;

    uint256 public mintFee;
    string public baseTokenURI;
    address payable public feeRecipient;
    string public name;
    string public symbol;
    mapping (uint256 => string) private cid;

    event Minted(
        uint256 tokenId,
        address beneficiary,
        string  tokenUri,
        address minter
    );

    event BatchMinted(
        address beneficiary,
        address minter
    );
    
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        uint256 _mintFee,
        address payable _feeRecipient,
        address _deployer
    ) ERC1155(_uri) {
        name = _name;
        symbol = _symbol;
        mintFee = _mintFee;
        baseTokenURI = _uri;
        feeRecipient = _feeRecipient;

        super._transferOwnership(_deployer);

        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        _setupRole(MINTER_ROLE, _deployer);
        _setupRole(PAUSER_ROLE, _deployer);
    }

    function uri(uint256 _tokenId) override public view returns (string memory) {
        return string(
            abi.encodePacked(baseTokenURI, cid[_tokenId])
        );
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(address _to, uint256 _amount, string memory _cid) public payable virtual {
        uint256 newTokenId = tokenIdTracker.current();

        mintById(_to, newTokenId, _amount, _cid);

        tokenIdTracker.increment();
    }

    function mintById(address _to, uint256 _id, uint256 _amount, string memory _cid) public payable virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "AlivelandERC1155: must have minter role to mint");
        require(msg.value >= (mintFee * _amount), "AlivelandERC1155: insufficient funds to mint");
        
        cid[_id] = _cid;
        _mint(_to, _id, _amount, "");

        (bool success,) = feeRecipient.call{value : msg.value}("");
        require(success, "AlivelandERC1155: transfer failed");

        emit Minted(_id, _to, uri(_id), _msgSender());
    }

    function mintBatch(address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data) public payable virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "AlivelandERC1155: must have minter role to mint");

        uint256 totalFee;
        for (uint i = 0; i < _ids.length; i++)
        {            
            totalFee += (mintFee * _amounts[i]);
        }
        require(msg.value >= totalFee, "AlivelandERC1155: insufficient funds to mintBatch");

        _mintBatch(_to, _ids, _amounts, _data);

        (bool success,) = feeRecipient.call{value : msg.value}("");
        require(success, "AlivelandERC1155: transfer failed to mintBatch");

        emit BatchMinted(_to, _msgSender());
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
    ) internal virtual override(ERC1155, ERC1155Pausable) {
        super._beforeTokenTransfer(_operator, _from, _to, _ids, _amounts, _data);
    }
}
