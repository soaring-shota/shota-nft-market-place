// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract AlivelandERC1155 is Context, AccessControlEnumerable, ERC1155Burnable, ERC1155Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public mintFee;
    address payable public feeRecipient;
    mapping(uint256 => string) private tokenURIs;
    mapping(uint256 => address) public creators;
    mapping(uint256 => uint256) public tokenSupply;

    constructor(
        string memory _uri,
        uint256 _mintFee,
        address payable _feeRecipient
    ) ERC1155(_uri) {
        mintFee = _mintFee;
        feeRecipient = _feeRecipient;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    function uri(uint256 _id) public view override returns (string memory) {
        require(_exists(_id), "AlivelandERC1155#uri: NONEXISTENT_TOKEN");
        return tokenURIs[_id];
    }

    function totalSupply(uint256 _id) public view returns (uint256) {
        return tokenSupply[_id];
    }

    function mint(address _to, uint256 _id, uint256 _amount, string calldata _uri) external payable {
        require(hasRole(MINTER_ROLE, _msgSender()), "AlivelandERC1155: must have minter role to mint");
        require(msg.value >= (mintFee * _amount), "AlivelandERC1155: insufficient funds to mint");
        
        creators[_id] = msg.sender;
        _setTokenURI(_id, _uri);
        if (bytes(_uri).length > 0) {
            emit URI(_uri, _id);
        }

        _mint(_to, _id, _amount, bytes(""));
         tokenSupply[_id] = _amount;

        (bool success_,) = feeRecipient.call{value : msg.value}("");
        require(success_, "AlivelandERC1155: transfer failed");
    }

    function mintBatch(address _to, uint256[] memory _ids, uint256[] memory _amounts, string[] calldata _uris) external payable {
        require(hasRole(MINTER_ROLE, _msgSender()), "AlivelandERC1155: must have minter role to mint");

        uint256 totalFee_;
        for (uint i = 0; i < _ids.length; i++)
        {            
            totalFee_ += (mintFee * _amounts[i]);
        }
        require(msg.value >= totalFee_, "AlivelandERC1155: insufficient funds to mintBatch");

        for (uint i = 0; i < _ids.length; i++)
        {
            creators[_ids[i]] = msg.sender;
            _setTokenURI(_ids[i], _uris[i]);
            if (bytes(_uris[i]).length > 0) {
                emit URI(_uris[i], _ids[i]);
            }
            tokenSupply[_ids[i]] = _amounts[i];
        }

        _mintBatch(_to, _ids, _amounts, bytes(""));

        (bool success_,) = feeRecipient.call{value : msg.value}("");
        require(success_, "AlivelandERC1155: transfer failed to mintBatch");
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

    function _exists(uint256 _id) public view returns (bool) {
        return creators[_id] != address(0);
    }

    function _setTokenURI(uint256 _id, string memory _uri) internal {
        require(_exists(_id), "AlivelandERC1155: Token should exist");
        tokenURIs[_id] = _uri;
    }
}
