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

    uint256 public _mintFee;
    address payable public _feeRecipient;

    constructor(
        string memory uri,
        uint256 mintFee,
        address payable feeRecipient
    ) ERC1155(uri) {
        _mintFee = mintFee;
        _feeRecipient = feeRecipient;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) public payable virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "AlivelandERC1155: must have minter role to mint");
        require(msg.value >= _mintFee, "AlivelandERC1155: insufficient funds to mint");

        _mint(to, id, amount, data);

        (bool success,) = _feeRecipient.call{value : _mintFee}("");
        require(success, "AlivelandERC1155: transfer failed");
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public payable virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "AlivelandERC1155: must have minter role to mint");

        uint256 fees = _mintFee * ids.length;
        require(msg.value >= fees, "AlivelandERC1155: insufficient funds to mintBatch");

        _mintBatch(to, ids, amounts, data);

        (bool success,) = _feeRecipient.call{value : fees}("");
        require(success, "AlivelandERC1155: transfer failed to mintBatch");
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
        bytes4 interfaceId
    ) public view virtual override(AccessControlEnumerable, ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155, ERC1155Pausable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
