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
import "./AlivelandMarketplaceEvents.sol";

interface IAlivelandAddressRegistry {
    function erc721Factory() external view returns (address);

    function erc1155Factory() external view returns (address);

    function tokenRegistry() external view returns (address);
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

    uint256 public minBidIncrement = 1;
    uint256 public bidWithdrawalLockTime = 20 minutes;

    // nft => tokenId => list struct
    mapping(address => mapping(uint256 => Listing)) public listings;

    // nft => tokenId => offerer address => offer struct
    mapping(address => mapping(uint256 => mapping(address => Offer))) public offers;

    // nft => tokenId => acuton struct
    mapping(address => mapping(uint256 => Auction)) public auctions;

    // auciton index => bidding counts => bidder address => bid price
    mapping(address => mapping(uint256 => mapping(address => Bid))) public bids;

    struct Listing {
        address seller;
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

    struct Auction {
        address creator;
        address payToken;
        uint256 minBid;
        uint256 reservePrice;
        uint256 startTime;
        uint256 endTime;
        bool    minBidReserve;
        address payable lastBidder;
        uint256 highestBid;
        address winner;
        bool resulted;
    }

    struct Bid {
        address payable bidder;
        uint256 bidPrice;
        uint256 lastBidTime;
    }

    IAlivelandAddressRegistry public addressRegistry;

    modifier isListed(
        address _nftAddress,
        uint256 _tokenId
    ) {
        Listing memory listing = listings[_nftAddress][_tokenId];
        require(listing.quantity > 0, "not listed item");
        _;
    }

    modifier notListed(
        address _nftAddress,
        uint256 _tokenId
    ) {
        Listing memory listing = listings[_nftAddress][_tokenId];
        require(listing.quantity == 0, "already listed");
        _;
    }

    modifier validListing(
        address _nftAddress,
        uint256 _tokenId
    ) {
        Listing memory listedItem = listings[_nftAddress][_tokenId];

        // _validSeller(_nftAddress, _tokenId, _owner);
        // _validOwner(_nftAddress, _tokenId, _owner, listedItem.quantity);

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

    modifier notAuctioned(
        address _nftAddress,
        uint256 _tokenId
    ) {
        Auction memory auction = auctions[_nftAddress][_tokenId];
        require(auction.creator == address(0), "auction already created");
        _;
    }

    modifier isAuction(
        address _nftAddress,
        uint256 _tokenId
    ) {
        Auction memory auction = auctions[_nftAddress][_tokenId];
        require(auction.creator != address(0) && !auction.resulted, "auction not created");
        _;
    }

    function initialize(address payable _feeRecipient, uint16 _platformFee) public initializer {
        require(
            _feeRecipient != address(0),
            "AlivelandAuction: Invalid Platform Fee Recipient"
        );

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
    ) external notListed(_nftAddress, _tokenId) {
        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftAddress);
            require(nft.ownerOf(_tokenId) == _msgSender(), "not owning item");
            require(
                nft.isApprovedForAll(_msgSender(), address(this)),
                "item not approved"
            );

            nft.safeTransferFrom(_msgSender(), address(this), _tokenId);

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

            nft.safeTransferFrom(_msgSender(), address(this), _tokenId, _quantity, "");

        } else {
            revert("invalid nft address");
        }

        _validPayToken(_payToken);

        listings[_nftAddress][_tokenId] = Listing(
            _msgSender(),
            _quantity,
            IERC20(_payToken),
            _pricePerItem,
            _startingTime
        );

        emit AlivelandMarketEvents.ItemListed(
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
        isListed(_nftAddress, _tokenId)
    {
        _cancelListing(_nftAddress, _tokenId);
    }

    function updateListing(
        address _nftAddress,
        uint256 _tokenId,
        address _payToken,
        uint256 _newPrice
    ) external nonReentrant isListed(_nftAddress, _tokenId) {
        Listing storage listedItem = listings[_nftAddress][_tokenId];

        _validSeller(_nftAddress, _tokenId, _msgSender());

        listedItem.payToken = IERC20(_payToken);
        listedItem.pricePerItem = _newPrice;
        emit AlivelandMarketEvents.ItemUpdated(
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
        address _payToken
    )
        external
        payable
        nonReentrant
        isListed(_nftAddress, _tokenId)
        validListing(_nftAddress, _tokenId)
    {
        Listing memory listedItem = listings[_nftAddress][_tokenId];
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

        _safeTransferFrom(_payToken, price.sub(feeAmount), _msgSender(), listedItem.seller);

        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721(_nftAddress).safeTransferFrom(
                address(this),
                _msgSender(),
                _tokenId
            );
        } else {
            IERC1155(_nftAddress).safeTransferFrom(
                address(this),
                _msgSender(),
                _tokenId,
                listedItem.quantity,
                bytes("")
            );
        }

        emit AlivelandMarketEvents.ItemSold(
            listedItem.seller,
            _msgSender(),
            _nftAddress,
            _tokenId,
            listedItem.quantity,
            _payToken,
            price.div(listedItem.quantity)
        );
        delete (listings[_nftAddress][_tokenId]);
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

        require(_owner != address(this), "listed item");

        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftAddress);
            require(nft.ownerOf(_tokenId) == _owner, "not owning item");
        } else if (
            IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)
        ) {
            IERC1155 nft = IERC1155(_nftAddress);
            require(
                nft.balanceOf(_owner, _tokenId) >= _quantity,
                "not owning item"
            );
        } else {
            revert("invalid nft address");
        }

        if (address(_payToken) == address(0x1010)) {
            require(
                msg.value >= _pricePerItem.mul(_quantity),
                "insufficient value"
            );
        }

        // IAlivelandAuction auction = IAlivelandAuction(addressRegistry.auction());

        // if (address(auction) != address(0)) {
        //     (, , , uint256 startTime, , bool resulted) = auction.auctions(
        //         _nftAddress,
        //         _tokenId
        //     );

        //     require(
        //         startTime == 0 || resulted == true,
        //         "cannot place an offer if auction is going on"
        //     );
        // }

        require(_deadline > _getNow(), "invalid expiration");

        _validPayToken(address(_payToken));

        offers[_nftAddress][_tokenId][_msgSender()] = Offer(
            _payToken,
            _quantity,
            _pricePerItem,
            _deadline
        );

        emit AlivelandMarketEvents.OfferCreated(
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
        emit AlivelandMarketEvents.OfferCanceled(_msgSender(), _nftAddress, _tokenId);
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

        emit AlivelandMarketEvents.ItemSold(
            _msgSender(),
            _creator,
            _nftAddress,
            _tokenId,
            offer.quantity,
            address(offer.payToken),
            offer.pricePerItem
        );

        emit AlivelandMarketEvents.OfferCanceled(_creator, _nftAddress, _tokenId);

        // delete (listings[_nftAddress][_tokenId][_msgSender()]);
        delete (offers[_nftAddress][_tokenId][_creator]);
    }

    function createAuction(
        address _nftAddress,
        uint256 _tokenId,
        string memory _mediaType,
        address _payToken,
        uint256 _reservePrice,
        uint256 _startTimestamp,
        bool minBidReserve,
        uint256 _endTimestamp
    ) external notAuctioned(_nftAddress, _tokenId) {
        require(
            IERC721(_nftAddress).ownerOf(_tokenId) == _msgSender() &&
                IERC721(_nftAddress).isApprovedForAll(
                    _msgSender(),
                    address(this)
                ),
            "not owner or contract not approved"
        );

        require(
            _endTimestamp >= _startTimestamp + 300,
            "end time must be greater than start (by 5 minutes)"
        );

        require(_startTimestamp > _getNow(), "invalid start time");

        require(
            (addressRegistry.tokenRegistry() != address(0) &&
                IAlivelandTokenRegistry(addressRegistry.tokenRegistry())
                    .enabled(_payToken)),
            "invalid pay token"
        );

        IERC721(_nftAddress).safeTransferFrom(_msgSender(), address(this), _tokenId);

        uint256 minimumBid = 0;

        if (minBidReserve) {
            minimumBid = _reservePrice;
        }

        auctions[_nftAddress][_tokenId] = Auction({
            creator: _msgSender(),
            payToken: _payToken,
            minBid: minimumBid,
            reservePrice: _reservePrice,
            startTime: _startTimestamp,
            endTime: _endTimestamp,
            minBidReserve: minBidReserve,
            lastBidder: payable(address(0)),
            highestBid: minimumBid,
            winner: address(0),
            resulted: false
        });

        emit AlivelandMarketEvents.AuctionCreated(_nftAddress, _tokenId, _mediaType,  _startTimestamp, _endTimestamp, _payToken, _reservePrice, _msgSender(), bidWithdrawalLockTime);
    }

    function cancelAuction(address _nftAddress, uint256 _tokenId)
        external
        nonReentrant
    {
        Auction memory auction = auctions[_nftAddress][_tokenId];

        require(
            IERC721(_nftAddress).ownerOf(_tokenId) == address(this) &&
                _msgSender() == auction.creator,
            "sender must be owner"
        );
        require(auction.endTime > 0, "no auction exists");
        require(!auction.resulted, "auction already resulted");

        if (auction.lastBidder != address(0)) {
            _refundHighestBidder(
                _nftAddress,
                _tokenId,
                auction.lastBidder,
                auction.highestBid
            );
        }

        delete auctions[_nftAddress][_tokenId];

        emit AlivelandMarketEvents.AuctionCancelled(_nftAddress, _tokenId);
    }

    function resultAuction(address _nftAddress, uint256 _tokenId)
        external
        nonReentrant
    {
        Auction storage auction = auctions[_nftAddress][_tokenId];

        require(
            msg.sender == owner() ||
                msg.sender == auction.creator ||
                msg.sender == auction.lastBidder,
            "not creator, winner, or owner"
        );

        require(auction.endTime > 0, "no auction exists");
        require(_getNow() > auction.endTime, "auction not ended");
        require(!auction.resulted, "auction already resulted");

        address winner = auction.lastBidder;
        uint256 winningBid = auction.highestBid;

        require(winner != address(0), "no open bids");
        require(
            winningBid >= auction.reservePrice,
            "highest bid is below reservePrice"
        );
        
        uint256 payAmount = winningBid;

        if (payAmount > auction.reservePrice && feeReceipient != address(0)) {
            uint256 aboveReservePrice = payAmount.sub(auction.reservePrice);

            uint256 platformFeeAboveReserve = aboveReservePrice
                .mul(platformFee)
                .div(1000);

            _safeTransfer(auction.payToken, platformFeeAboveReserve, feeReceipient);

            payAmount = payAmount.sub(platformFeeAboveReserve);
        }

        (address minter, uint256 royaltyFee) = AlivelandERC721(_nftAddress).royaltyInfo(_tokenId, payAmount);
        if (royaltyFee > 0) {
            _safeTransfer(auction.payToken, royaltyFee, minter);
            payAmount = payAmount.sub(royaltyFee);
        }
        if (payAmount > 0) {
            _safeTransfer(auction.payToken, payAmount, auction.creator);
        }
        
        IERC721(_nftAddress).safeTransferFrom(
            IERC721(_nftAddress).ownerOf(_tokenId),
            winner,
            _tokenId
        );

        auction.resulted = true;
        auction.winner = winner;

        emit AlivelandMarketEvents.AuctionResulted(
            _msgSender(),
            _nftAddress,
            _tokenId,
            winner,
            auction.payToken,
            winningBid
        );

        delete auctions[_nftAddress][_tokenId];
    }

    function placeBid(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _bidAmount
    ) external payable nonReentrant isAuction(_nftAddress, _tokenId) {
        require(tx.origin == _msgSender(), "no contracts permitted");

        Auction storage auction = auctions[_nftAddress][_tokenId];

        require(
            _getNow() >= auction.startTime && _getNow() <= auction.endTime,
            "bidding outside of the auction duration"
        );

        require(
            auction.payToken != address(0),
            "ERC20 method used for Aliveland auction"
        );

        if (auction.minBid == auction.reservePrice) {
            require(
                _bidAmount >= auction.reservePrice,
                "bid cannot be lower than reserve price"
            );
        }

        uint256 minBidRequired = auction.highestBid.add(minBidIncrement);

        require(_bidAmount >= minBidRequired, "failed to outbid highest bidder");

        if (auction.payToken != address(0)) {
            _safeTransferFrom(auction.payToken, _bidAmount, _msgSender(), address(this));
        }

        if(auction.lastBidder != address(0)) {
            address payable lastBidder = auction.lastBidder;
            uint256 lastBidPrice = auction.highestBid;
            _refundHighestBidder(
                _nftAddress,
                _tokenId,
                lastBidder,
                lastBidPrice
            );
        }
        
        auction.lastBidder = payable(_msgSender());
        auction.highestBid = _bidAmount;

        emit AlivelandMarketEvents.BidPlaced(_nftAddress, _tokenId, _msgSender(), auction.creator, auction.payToken, _bidAmount);
    }

    function withdrawBid(address _nftAddress, uint256 _tokenId)
        external
        nonReentrant
        isAuction(_nftAddress, _tokenId)
    {
        Auction storage auction = auctions[_nftAddress][_tokenId];

        require(
            auction.lastBidder == _msgSender(),
            "you are not the highest bidder"
        );

        uint256 _endTime = auction.endTime;

        require(
            _getNow() > _endTime && (_getNow() - _endTime >= 43200),
            "can withdraw only after 12 hours (after auction ended)"
        );

        uint256 previousBid = auction.highestBid;

        _refundHighestBidder(_nftAddress, _tokenId, payable(_msgSender()), previousBid);

        auction.lastBidder = payable(address(0));
        auction.highestBid = 0;
        if (auction.minBidReserve) {
            auction.highestBid = auction.reservePrice;
        }

        emit AlivelandMarketEvents.BidWithdrawn(_nftAddress, _tokenId, _msgSender(), previousBid);
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
        emit AlivelandMarketEvents.UpdatePlatformFee(_platformFee);
    }

    function updatePlatformFeeRecipient(address payable _platformFeeRecipient) external onlyOwner {
        feeReceipient = _platformFeeRecipient;
        emit AlivelandMarketEvents.UpdatePlatformFeeRecipient(_platformFeeRecipient);
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

    function _validSeller(
        address _nftAddress,
        uint256 _tokenId,
        address _seller
    ) internal view {
        Listing memory listedItem = listings[_nftAddress][_tokenId];
        require(listedItem.seller == _seller, "not listed seller");
    }

    function _refundHighestBidder(
        address _nftAddress,
        uint256 _tokenId,
        address payable _currentHighestBidder,
        uint256 _currentHighestBid
    ) private {
        Auction memory auction = auctions[_nftAddress][_tokenId];

        _safeTransfer(auction.payToken, _currentHighestBid, _currentHighestBidder);

        emit AlivelandMarketEvents.BidRefunded(
            _nftAddress,
            _tokenId,
            _currentHighestBidder,
            _currentHighestBid
        );
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
        uint256 _tokenId
    ) private {
        Listing memory listedItem = listings[_nftAddress][_tokenId];

        _validSeller(_nftAddress, _tokenId, _msgSender());

        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftAddress);
            nft.safeTransferFrom(address(this), _msgSender(), _tokenId);

        } else if (
            IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)
        ) {
            IERC1155 nft = IERC1155(_nftAddress);
            nft.safeTransferFrom(_msgSender(), address(this), _tokenId, listedItem.quantity, "");

        } else {
            revert("invalid nft address");
        }

        delete (listings[_nftAddress][_tokenId]);
        emit AlivelandMarketEvents.ItemCanceled(_msgSender(), _nftAddress, _tokenId);
    }

}
