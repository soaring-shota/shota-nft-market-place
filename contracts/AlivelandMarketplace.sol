// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./AlivelandERC721.sol";

interface IAlivelandAddressRegistry {
    function auction() external view returns (address);

    function erc721Factory() external view returns (address);

    function erc1155Factory() external view returns (address);

    function tokenRegistry() external view returns (address);
}

interface IAlivelandAuction {
    function auctions(address, uint256)
        external
        view
        returns (
            address,
            address,
            uint256,
            uint256,
            uint256,
            bool
        );
}

interface IAlivelandERC721Factory {
    function exists(address) external view returns (bool);
}

interface IAlivelandTokenRegistry {
    function enabled(address) external view returns (bool);
}

contract AlivelandMarketplace is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;
    using AddressUpgradeable for address payable;
    using SafeERC20 for IERC20;

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;
    
    uint16 public platformFee;
    address payable public feeReceipient;  

    mapping(address => mapping(uint256 => mapping(address => Listing))) public listings;
    mapping(address => mapping(uint256 => mapping(address => Offer))) public offers;

    struct Listing {
        uint256 quantity;
        IERC20 payToken;
        uint256 pricePerItem;
        uint256 startingTime;
    }

    struct Offer {
        IERC20 payToken;
        uint256 quantity;
        uint256 pricePerItem;
        uint256 deadline;
    }

    event ItemListed(
        address indexed owner,
        address indexed nft,
        string  mediaType,
        uint256 tokenId,
        uint256 quantity,
        address payToken,
        uint256 pricePerItem,
        uint256 startingTime
    );
    event ItemSold(
        address indexed seller,
        address indexed buyer,
        address indexed nft,
        uint256 tokenId,
        uint256 quantity,
        address payToken,
        uint256 pricePerItem
    );    
    event ItemUpdated(
        address indexed owner,
        address indexed nft,
        uint256 tokenId,
        address payToken,
        uint256 newPrice
    );
    event ItemCanceled(
        address indexed owner,
        address indexed nft,
        uint256 tokenId
    );   
    event OfferCreated(
        address indexed creator,
        address indexed nft,
        address indexed owner,
        uint256 tokenId,
        uint256 quantity,
        address payToken,
        uint256 pricePerItem,
        uint256 deadline
    );
    event OfferCanceled(
        address indexed creator,
        address indexed nft,
        uint256 tokenId
    );
    event UpdatePlatformFee(uint16 platformFee);
    event UpdatePlatformFeeRecipient(address payable platformFeeRecipient);

    IAlivelandAddressRegistry public addressRegistry;

    modifier isListed(
        address _nftAddress,
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listing = listings[_nftAddress][_tokenId][_owner];
        require(listing.quantity > 0, "not listed item");
        _;
    }

    modifier notListed(
        address _nftAddress,
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listing = listings[_nftAddress][_tokenId][_owner];
        require(listing.quantity == 0, "already listed");
        _;
    }

    modifier validListing(
        address _nftAddress,
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];

        _validOwner(_nftAddress, _tokenId, _owner, listedItem.quantity);

        require(_getNow() >= listedItem.startingTime, "item not buyable");
        _;
    }

    modifier offerExists(
        address _nftAddress,
        uint256 _tokenId,
        address _creator
    ) {
        Offer memory offer = offers[_nftAddress][_tokenId][_creator];
        require(
            offer.quantity > 0 && offer.deadline > _getNow(),
            "offer not exists or expired"
        );
        _;
    }

    modifier offerNotExists(
        address _nftAddress,
        uint256 _tokenId,
        address _creator
    ) {
        Offer memory offer = offers[_nftAddress][_tokenId][_creator];
        require(
            offer.quantity == 0 || offer.deadline <= _getNow(),
            "offer already created"
        );
        _;
    }

    function initialize(address payable _feeRecipient, uint16 _platformFee) public initializer {
        platformFee = _platformFee;
        feeReceipient = _feeRecipient;

        __Ownable_init();
        __ReentrancyGuard_init();
    }

    function listItem(
        address _nftAddress,
        string memory _mediaType,
        uint256 _tokenId,
        uint256 _quantity,
        address _payToken,
        uint256 _pricePerItem,
        uint256 _startingTime
    ) external notListed(_nftAddress, _tokenId, _msgSender()) {
        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftAddress);
            require(nft.ownerOf(_tokenId) == _msgSender(), "not owning item");
            require(
                nft.isApprovedForAll(_msgSender(), address(this)),
                "item not approved"
            );
        } else if (
            IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)
        ) {
            IERC1155 nft = IERC1155(_nftAddress);
            require(
                nft.balanceOf(_msgSender(), _tokenId) >= _quantity,
                "must hold enough nfts"
            );
            require(
                nft.isApprovedForAll(_msgSender(), address(this)),
                "item not approved"
            );
        } else {
            revert("invalid nft address");
        }

        _validPayToken(_payToken);

        listings[_nftAddress][_tokenId][_msgSender()] = Listing(
            _quantity,
            IERC20(_payToken),
            _pricePerItem,
            _startingTime
        );
        emit ItemListed(
            _msgSender(),
            _nftAddress,
            _mediaType,
            _tokenId,
            _quantity,
            _payToken,
            _pricePerItem,
            _startingTime
        );
    }

    function cancelListing(address _nftAddress, uint256 _tokenId) external nonReentrant
        isListed(_nftAddress, _tokenId, _msgSender())
    {
        _cancelListing(_nftAddress, _tokenId, _msgSender());
    }

    function updateListing(
        address _nftAddress,
        uint256 _tokenId,
        address _payToken,
        uint256 _newPrice
    ) external nonReentrant isListed(_nftAddress, _tokenId, _msgSender()) {
        Listing storage listedItem = listings[_nftAddress][_tokenId][_msgSender()];

        _validOwner(_nftAddress, _tokenId, _msgSender(), listedItem.quantity);

        listedItem.payToken = IERC20(_payToken);
        listedItem.pricePerItem = _newPrice;
        emit ItemUpdated(
            _msgSender(),
            _nftAddress,
            _tokenId,
            _payToken,
            _newPrice
        );
    }

    function buyItem(
        address _nftAddress,
        uint256 _tokenId,
        address _payToken,
        address _owner
    )
        external
        payable
        nonReentrant
        isListed(_nftAddress, _tokenId, _owner)
        validListing(_nftAddress, _tokenId, _owner)
    {
        Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];
        require(address(listedItem.payToken) == _payToken, "invalid pay token");

        uint256 price = listedItem.pricePerItem.mul(listedItem.quantity);
        uint256 feeAmount = price.mul(platformFee).div(1e3);
        if (address(_payToken) == address(0x1010)) {
            require(msg.sender.balance >= msg.value, "insufficient balance");
            require(msg.value >= price, "please send the exact amount");
        }

        _safeTransferFrom(_payToken, feeAmount, _msgSender(), feeReceipient);

        (address minter, uint256 royaltyFee) = AlivelandERC721(_nftAddress).royaltyInfo(_tokenId, price.sub(feeAmount));
        if (royaltyFee > 0) {
            _safeTransferFrom(_payToken, royaltyFee, _msgSender(), minter);
            feeAmount = feeAmount.add(royaltyFee);
        }

        _safeTransferFrom(_payToken, price.sub(feeAmount), _msgSender(), _owner);

        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721(_nftAddress).safeTransferFrom(
                _owner,
                _msgSender(),
                _tokenId
            );
        } else {
            IERC1155(_nftAddress).safeTransferFrom(
                _owner,
                _msgSender(),
                _tokenId,
                listedItem.quantity,
                bytes("")
            );
        }

        emit ItemSold(
            _owner,
            _msgSender(),
            _nftAddress,
            _tokenId,
            listedItem.quantity,
            _payToken,
            price.div(listedItem.quantity)
        );
        delete (listings[_nftAddress][_tokenId][_owner]);
    }

    function createOffer(
        address _nftAddress,
        address _owner,
        uint256 _tokenId,
        IERC20 _payToken,
        uint256 _quantity,
        uint256 _pricePerItem,
        uint256 _deadline
    ) external payable offerNotExists(_nftAddress, _tokenId, _msgSender()) {
        require(
            IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721) ||
                IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155),
            "invalid nft address"
        );
        if (address(_payToken) == address(0x1010)) {
            require(
                msg.value >= _pricePerItem.mul(_quantity),
                "insufficient value"
            );
        }

        IAlivelandAuction auction = IAlivelandAuction(addressRegistry.auction());

        if (address(auction) != address(0)) {
            (, , , uint256 startTime, , bool resulted) = auction.auctions(
                _nftAddress,
                _tokenId
            );

            require(
                startTime == 0 || resulted == true,
                "cannot place an offer if auction is going on"
            );
        }

        require(_deadline > _getNow(), "invalid expiration");

        _validPayToken(address(_payToken));

        offers[_nftAddress][_tokenId][_msgSender()] = Offer(
            _payToken,
            _quantity,
            _pricePerItem,
            _deadline
        );

        emit OfferCreated(
            _msgSender(),
            _nftAddress,
            _owner,
            _tokenId,
            _quantity,
            address(_payToken),
            _pricePerItem,
            _deadline
        );
    }

    function cancelOffer(address _nftAddress, uint256 _tokenId) external {
        Offer storage offer = offers[_nftAddress][_tokenId][_msgSender()];
        require(offer.pricePerItem.mul(offer.quantity) > 0, "Offer does not exist");
        if (address(offer.payToken) == address(0x1010)) {
            _safeTransfer(address(offer.payToken), offer.pricePerItem.mul(offer.quantity), _msgSender());
        }
        delete (offers[_nftAddress][_tokenId][_msgSender()]);
        emit OfferCanceled(_msgSender(), _nftAddress, _tokenId);
    }

    function acceptOffer(
        address _nftAddress,
        uint256 _tokenId,
        address _creator
    ) external nonReentrant offerExists(_nftAddress, _tokenId, _creator) {
        Offer memory offer = offers[_nftAddress][_tokenId][_creator];

        _validOwner(_nftAddress, _tokenId, _msgSender(), offer.quantity);

        uint256 price = offer.pricePerItem.mul(offer.quantity);
        uint256 feeAmount = price.mul(platformFee).div(1e3);

        _safeTransferFrom(address(offer.payToken), feeAmount, _creator, feeReceipient);

        (address minter, uint256 royaltyFee) = AlivelandERC721(_nftAddress).royaltyInfo(_tokenId, price.sub(feeAmount));

        if (royaltyFee > 0) {
            _safeTransferFrom(address(offer.payToken), royaltyFee, _creator, minter);
            feeAmount = feeAmount.add(royaltyFee);
        }

        _safeTransferFrom(address(offer.payToken), price.sub(feeAmount), _creator, _msgSender());

        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721(_nftAddress).safeTransferFrom(
                _msgSender(),
                _creator,
                _tokenId
            );
        } else {
            IERC1155(_nftAddress).safeTransferFrom(
                _msgSender(),
                _creator,
                _tokenId,
                offer.quantity,
                bytes("")
            );
        }

        emit ItemSold(
            _msgSender(),
            _creator,
            _nftAddress,
            _tokenId,
            offer.quantity,
            address(offer.payToken),
            offer.pricePerItem
        );

        emit OfferCanceled(_creator, _nftAddress, _tokenId);

        delete (listings[_nftAddress][_tokenId][_msgSender()]);
        delete (offers[_nftAddress][_tokenId][_creator]);
    }

    function getPrice(address _tokenAddr) public view returns (uint256) {     
        if (_tokenAddr == address(0))
            return 0;
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_tokenAddr);
        (,int price,,,) = priceFeed.latestRoundData();

        return uint256(price);

    }

    function updatePlatformFee(uint16 _platformFee) external onlyOwner {
        platformFee = _platformFee;
        emit UpdatePlatformFee(_platformFee);
    }

    function updatePlatformFeeRecipient(address payable _platformFeeRecipient) external onlyOwner {
        feeReceipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }

    function updateAddressRegistry(address _registry) external onlyOwner {
        addressRegistry = IAlivelandAddressRegistry(_registry);
    }

    function _isAlivelandNFT(address _nftAddress) internal view returns (bool) {
        return
            IAlivelandERC721Factory(addressRegistry.erc721Factory()).exists(_nftAddress) ||
            IAlivelandERC721Factory(addressRegistry.erc1155Factory()).exists(_nftAddress);
    }

    function _getNow() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    function _validPayToken(address _payToken) internal view {
        require(
            addressRegistry.tokenRegistry() != address(0) &&
                IAlivelandTokenRegistry(addressRegistry.tokenRegistry())
                    .enabled(_payToken),
            "invalid pay token"
        );
    }

    function _validOwner(
        address _nftAddress,
        uint256 _tokenId,
        address _owner,
        uint256 quantity
    ) internal view {
        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftAddress);
            require(nft.ownerOf(_tokenId) == _owner, "not owning item");
        } else if (
            IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)
        ) {
            IERC1155 nft = IERC1155(_nftAddress);
            require(
                nft.balanceOf(_owner, _tokenId) >= quantity,
                "not owning item"
            );
        } else {
            revert("invalid nft address");
        }
    }

    function _safeTransfer(address _payToken, uint256 _amount, address _to) internal {
        if (_amount == 0 || _to == address(0)) return;
        if (_payToken == address(0x1010)) {
            (bool success, ) = payable(_to).call{ value: _amount }("");
            require(success, "ether transfer failed");
        } else {
            IERC20 payToken = IERC20(_payToken);
            payToken.safeTransfer(_to, _amount);
        }
    }

    function _safeTransferFrom(address _payToken, uint256 _amount, address _from, address _to) internal {
        if (_amount == 0 || _to == address(0)) return;
        if (_payToken == address(0x1010)) {
            (bool success, ) = payable(_to).call{ value: _amount }("");
            require(success, "ether transfer failed");
        } else {
            IERC20 payToken = IERC20(_payToken);
            payToken.safeTransferFrom(_from, _to, _amount);
        }
    }

    function _cancelListing(
        address _nftAddress,
        uint256 _tokenId,
        address _owner
    ) private {
        Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];

        _validOwner(_nftAddress, _tokenId, _owner, listedItem.quantity);

        delete (listings[_nftAddress][_tokenId][_owner]);
        emit ItemCanceled(_owner, _nftAddress, _tokenId);
    }
}
