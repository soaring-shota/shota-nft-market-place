// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
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

contract AlivelandMarketplace is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    IERC721Receiver,
    IERC1155Receiver
{
    using SafeMath for uint256;
    using AddressUpgradeable for address payable;
    using SafeERC20 for IERC20;

    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    uint16 public platformFee;
    address payable public feeReceipient;

    uint256 public minBidIncrement;
    uint256 public bidWithdrawalLockTime;

    // nft => tokenId => list struct
    mapping(address => mapping(uint256 => Listing))
        public listings;

    // nft => tokenId => offerer address => offer struct
    mapping(address => mapping(uint256 => mapping(address => Offer)))
        public offers;

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
        address offerer;
        IERC20 payToken;
        uint256 pricePerItem;
        uint256 deadline;
        bool accepted;
    }

    struct Auction {
        address creator;
        address payToken;
        uint256 minBid;
        uint256 reservePrice;
        uint256 startTime;
        uint256 endTime;
        bool minBidReserve;
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
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listing = listings[_nftAddress][_tokenId];
        require(listing.quantity > 0, "not listed item");
        _;
    }

    modifier notListed(
        address _nftAddress,
        uint256 _tokenId,
        address _owner
    ) {
        Listing memory listing = listings[_nftAddress][_tokenId];
        require(listing.quantity == 0, "already listed");
        _;
    }

    modifier validListing(
        address _nftAddress,
        uint256 _tokenId,
        address _owner
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
            offer.pricePerItem > 0 && offer.offerer != address(0),
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
            offer.pricePerItem == 0 || offer.offerer == address(0),
            "offer already created"
        );
        _;
    }

    modifier notAuctioned(address _nftAddress, uint256 _tokenId) {
        Auction memory auction = auctions[_nftAddress][_tokenId];
        require(auction.creator == address(0), "auction already created");
        _;
    }

    modifier isAuction(address _nftAddress, uint256 _tokenId) {
        Auction memory auction = auctions[_nftAddress][_tokenId];
        require(
            auction.creator != address(0) && !auction.resulted,
            "auction not created"
        );
        _;
    }

    function initialize(
        address payable _feeRecipient,
        uint16 _platformFee
    ) public initializer {
        require(
            _feeRecipient != address(0),
            "AlivelandAuction: Invalid Platform Fee Recipient"
        );

        platformFee = _platformFee;
        feeReceipient = _feeRecipient;

        minBidIncrement = 1;
        bidWithdrawalLockTime = 20 minutes;

        __Ownable_init();
        __ReentrancyGuard_init();
    }

    function getOwnerOfNft(address _nftAddress, uint256 _tokenId) public view returns(address) {
        address _owner = address(0);
        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftAddress);
            address owner = nft.ownerOf(_tokenId);
            
            _owner = owner;

            if(owner == address(this)) {
                _owner = listings[_nftAddress][_tokenId].seller;
                if(_owner == address(0)) {
                    _owner = auctions[_nftAddress][_tokenId].creator;
                }
            }

        } 
        
        return _owner;
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

            nft.safeTransferFrom(_msgSender(), address(this), _tokenId);
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

    function cancelListing(
        address _nftAddress,
        uint256 _tokenId
    ) external nonReentrant isListed(_nftAddress, _tokenId, _msgSender()) {
        _cancelListing(_nftAddress, _tokenId, _msgSender());
    }

    function updateListing(
        address _nftAddress,
        uint256 _tokenId,
        address _payToken,
        uint256 _newPrice
    ) external nonReentrant isListed(_nftAddress, _tokenId, _msgSender()) {
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
        address _payToken,
        address _seller
    )
        external
        payable
        nonReentrant
        isListed(_nftAddress, _tokenId, _seller)
        validListing(_nftAddress, _tokenId, _seller)
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

        (address minter, uint256 royaltyFee) = AlivelandERC721(_nftAddress)
            .royaltyInfo(_tokenId, price.sub(feeAmount));
        if (royaltyFee > 0) {
            _safeTransferFrom(_payToken, royaltyFee, _msgSender(), minter);
            feeAmount = feeAmount.add(royaltyFee);
        }

        _safeTransferFrom(
            _payToken,
            price.sub(feeAmount),
            _msgSender(),
            listedItem.seller
        );

        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721(_nftAddress).safeTransferFrom(
                address(this),
                _msgSender(),
                _tokenId
            );
        } else {
            revert("invalid nft address");
        }

        // Cancel offer if there is an offer created by msgSender()
        Offer storage offer = offers[_nftAddress][_tokenId][_msgSender()];
        if (offer.offerer == _msgSender() && !offer.accepted) {
            _safeTransferFrom(
                address(offer.payToken),
                offer.pricePerItem,
                address(this),
                _msgSender()
            );

            delete (offers[_nftAddress][_tokenId][_msgSender()]);
            emit AlivelandMarketEvents.OfferCanceled(
                _msgSender(),
                _nftAddress,
                _tokenId
            );
        }
        ///////////////////////////////////////////////////////////
        
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
        uint256 _tokenId,
        IERC20 _payToken,
        uint256 _pricePerItem,
        uint256 _deadline
    )
        external
        payable
        offerNotExists(_nftAddress, _tokenId, _msgSender())
        notAuctioned(_nftAddress, _tokenId)
    {
        require(_pricePerItem > 0, "price can not be 0");
        require(
            IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721),
            "invalid nft address"
        );

        require(_deadline > _getNow(), "invalid expiration");

        _validPayToken(address(_payToken));

        if (address(_payToken) == address(0x1010)) {
            require(msg.sender.balance >= msg.value, "insufficient balance");
            require(msg.value >= _pricePerItem, "please send the exact amount");
        }

        _safeTransferFrom(
            address(_payToken),
            _pricePerItem,
            _msgSender(),
            address(this)
        );

        offers[_nftAddress][_tokenId][_msgSender()] = Offer(
            _msgSender(),
            _payToken,
            _pricePerItem,
            _deadline,
            false
        );

        address _nftOwner = getOwnerOfNft(_nftAddress, _tokenId);

        emit AlivelandMarketEvents.OfferCreated(
            _msgSender(),
            _nftAddress,
            _nftOwner,
            _tokenId,
            address(_payToken),
            _pricePerItem,
            _deadline
        );
    }

    function cancelOffer(address _nftAddress, uint256 _tokenId) external {
        Offer storage offer = offers[_nftAddress][_tokenId][_msgSender()];
        require(offer.offerer == _msgSender(), "not offerer");
        require(!offer.accepted, "offer already accepted");

        _safeTransferFrom(
            address(offer.payToken),
            offer.pricePerItem,
            address(this),
            _msgSender()
        );

        delete (offers[_nftAddress][_tokenId][_msgSender()]);
        emit AlivelandMarketEvents.OfferCanceled(
            _msgSender(),
            _nftAddress,
            _tokenId
        );
    }

    function acceptOffer(
        address _nftAddress,
        uint256 _tokenId,
        address _creator
    ) external nonReentrant offerExists(_nftAddress, _tokenId, _creator) {
        Auction memory auction = auctions[_nftAddress][_tokenId];
        require(auction.creator == address(0), "nft is in auction");

        Offer storage offer = offers[_nftAddress][_tokenId][_creator];

        _validOwner(_nftAddress, _tokenId, _msgSender(), 1);

        require(!offer.accepted, "offer already accepted");

        require(
            IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721),
            "not valid nft address"
        );

        uint256 price = offer.pricePerItem;
        uint256 feeAmount = price.mul(platformFee).div(1e3);

        _safeTransferFrom(
            address(offer.payToken),
            feeAmount,
            address(this),
            feeReceipient
        );

        (address minter, uint256 royaltyFee) = AlivelandERC721(_nftAddress)
            .royaltyInfo(_tokenId, price.sub(feeAmount));

        if (royaltyFee > 0) {
            _safeTransferFrom(
                address(offer.payToken),
                royaltyFee,
                address(this),
                minter
            );
            feeAmount = feeAmount.add(royaltyFee);
        }

        _safeTransferFrom(
            address(offer.payToken),
            price.sub(feeAmount),
            address(this),
            _msgSender()
        );

        Listing memory listing = listings[_nftAddress][_tokenId];
        if (listing.seller != address(0)) {
            IERC721(_nftAddress).safeTransferFrom(address(this), _creator, _tokenId);
        } else {
            IERC721(_nftAddress).safeTransferFrom(_msgSender(), _creator, _tokenId);
        }

        offer.accepted = true;

        emit AlivelandMarketEvents.ItemSold(
            _msgSender(),
            _creator,
            _nftAddress,
            _tokenId,
            1,
            address(offer.payToken),
            offer.pricePerItem
        );

        emit AlivelandMarketEvents.OfferCanceled(
            _creator,
            _nftAddress,
            _tokenId
        );

        delete (listings[_nftAddress][_tokenId]);
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

        IERC721(_nftAddress).safeTransferFrom(
            _msgSender(),
            address(this),
            _tokenId
        );

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

        emit AlivelandMarketEvents.AuctionCreated(
            _nftAddress,
            _tokenId,
            _mediaType,
            _startTimestamp,
            _endTimestamp,
            _payToken,
            _reservePrice,
            _msgSender(),
            bidWithdrawalLockTime
        );
    }

    function cancelAuction(
        address _nftAddress,
        uint256 _tokenId
    ) external nonReentrant {
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

        IERC721(_nftAddress).safeTransferFrom(
            address(this),
            _msgSender(),
            _tokenId
        );

        delete auctions[_nftAddress][_tokenId];

        emit AlivelandMarketEvents.AuctionCancelled(_nftAddress, _tokenId);
    }

    function resultAuction(
        address _nftAddress,
        uint256 _tokenId
    ) external nonReentrant {
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

            _safeTransfer(
                auction.payToken,
                platformFeeAboveReserve,
                feeReceipient
            );

            payAmount = payAmount.sub(platformFeeAboveReserve);
        }

        (address minter, uint256 royaltyFee) = AlivelandERC721(_nftAddress)
            .royaltyInfo(_tokenId, payAmount);
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

        require(
            _bidAmount >= minBidRequired,
            "failed to outbid highest bidder"
        );

        if (auction.payToken != address(0)) {
            _safeTransferFrom(
                auction.payToken,
                _bidAmount,
                _msgSender(),
                address(this)
            );
        }

        if (auction.lastBidder != address(0)) {
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

        emit AlivelandMarketEvents.BidPlaced(
            _nftAddress,
            _tokenId,
            _msgSender(),
            auction.creator,
            auction.payToken,
            _bidAmount
        );
    }

    function withdrawBid(
        address _nftAddress,
        uint256 _tokenId
    ) external nonReentrant isAuction(_nftAddress, _tokenId) {
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

        _refundHighestBidder(
            _nftAddress,
            _tokenId,
            payable(_msgSender()),
            previousBid
        );

        auction.lastBidder = payable(address(0));
        auction.highestBid = 0;
        if (auction.minBidReserve) {
            auction.highestBid = auction.reservePrice;
        }

        emit AlivelandMarketEvents.BidWithdrawn(
            _nftAddress,
            _tokenId,
            _msgSender(),
            previousBid
        );
    }

    function updateAuctionReservePrice(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _reservePrice
    ) external {
        Auction storage auction = auctions[_nftAddress][_tokenId];

        require(_msgSender() == auction.creator, "sender must be item owner");
        require(auction.endTime > 0, "no auction exists");
        require(!auction.resulted, "auction already resulted");

        auction.reservePrice = _reservePrice;

        emit AlivelandMarketEvents.UpdateAuctionReservePrice(
            _nftAddress,
            _tokenId,
            auction.payToken,
            _reservePrice
        );
    }

    function updateAuctionStartTime(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _startTime
    ) external {
        Auction storage auction = auctions[_nftAddress][_tokenId];

        require(auction.endTime > 0, "no auction exists");
        require(_msgSender() == auction.creator, "sender must be owner");
        require(_startTime > 0, "invalid start time");
        require(auction.startTime + 60 > _getNow(), "auction already started");
        require(
            _startTime + 300 < auction.endTime,
            "start time should be less than end time (by 5 minutes)"
        );
        require(!auction.resulted, "auction already resulted");

        auction.startTime = _startTime;
        emit AlivelandMarketEvents.UpdateAuctionStartTime(
            _nftAddress,
            _tokenId,
            _startTime
        );
    }

    function updateAuctionEndTime(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _endTimestamp
    ) external {
        Auction storage auction = auctions[_nftAddress][_tokenId];

        require(auction.endTime > 0, "no auction exists");
        require(_msgSender() == auction.creator, "sender must be owner");
        require(_getNow() < auction.endTime, "auction already ended");
        require(
            auction.startTime < _endTimestamp,
            "end time must be greater than start"
        );
        require(
            _endTimestamp > _getNow() + 300,
            "auction should end after 5 minutes"
        );

        auction.endTime = _endTimestamp;
        emit AlivelandMarketEvents.UpdateAuctionEndTime(
            _nftAddress,
            _tokenId,
            _endTimestamp
        );
    }

    function getAuction(
        address _nftAddress,
        uint256 _tokenId
    )
        external
        view
        returns (
            address _owner,
            address _payToken,
            uint256 _reservePrice,
            uint256 _startTime,
            uint256 _endTime,
            bool _resulted,
            uint256 minBid
        )
    {
        Auction storage auction = auctions[_nftAddress][_tokenId];
        return (
            auction.creator,
            auction.payToken,
            auction.reservePrice,
            auction.startTime,
            auction.endTime,
            auction.resulted,
            auction.minBid
        );
    }

    function getHighestBidder(
        address _nftAddress,
        uint256 _tokenId
    ) external view returns (address payable _bidder, uint256 _bid) {
        Auction storage auction = auctions[_nftAddress][_tokenId];
        return (auction.lastBidder, auction.highestBid);
    }

    function getPrice(address _tokenAddr) public view returns (uint256) {
        if (_tokenAddr == address(0)) return 0;
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_tokenAddr);
        (, int price, , , ) = priceFeed.latestRoundData();

        return uint256(price);
    }

    function updatePlatformFee(uint16 _platformFee) external onlyOwner {
        platformFee = _platformFee;
        emit AlivelandMarketEvents.UpdatePlatformFee(_platformFee);
    }

    function updatePlatformFeeRecipient(
        address payable _platformFeeRecipient
    ) external onlyOwner {
        feeReceipient = _platformFeeRecipient;
        emit AlivelandMarketEvents.UpdatePlatformFeeRecipient(
            _platformFeeRecipient
        );
    }

    function updateAddressRegistry(address _registry) external onlyOwner {
        addressRegistry = IAlivelandAddressRegistry(_registry);
    }

    function _isAlivelandNFT(address _nftAddress) internal view returns (bool) {
        return
            IAlivelandERC721Factory(addressRegistry.erc721Factory()).exists(
                _nftAddress
            );
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
            require(getOwnerOfNft(_nftAddress, _tokenId) == _owner, "not owning item");
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

        _safeTransfer(
            auction.payToken,
            _currentHighestBid,
            _currentHighestBidder
        );

        emit AlivelandMarketEvents.BidRefunded(
            _nftAddress,
            _tokenId,
            _currentHighestBidder,
            _currentHighestBid
        );
    }

    function _safeTransfer(
        address _payToken,
        uint256 _amount,
        address _to
    ) internal {
        if (_amount == 0 || _to == address(0)) return;
        if (_payToken == address(0x1010)) {
            (bool success, ) = payable(_to).call{value: _amount}("");
            require(success, "ether transfer failed");
        } else {
            IERC20 payToken = IERC20(_payToken);
            payToken.safeTransfer(_to, _amount);
        }
    }

    function _safeTransferFrom(
        address _payToken,
        uint256 _amount,
        address _from,
        address _to
    ) internal {
        if (_amount == 0 || _to == address(0)) return;
        if (_payToken == address(0x1010)) {
            (bool success, ) = payable(_to).call{value: _amount}("");
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
        Listing memory listedItem = listings[_nftAddress][_tokenId];

        _validSeller(_nftAddress, _tokenId, _owner);

        if (IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
            IERC721 nft = IERC721(_nftAddress);
            nft.safeTransferFrom(address(this), _msgSender(), _tokenId);
        } else {
            revert("invalid nft address");
        }

        delete (listings[_nftAddress][_tokenId]);
        emit AlivelandMarketEvents.ItemCanceled(
            _msgSender(),
            _nftAddress,
            _tokenId
        );
    }

    function reclaimERC20(address _tokenContract) external onlyOwner {
        require(_tokenContract != address(0), "Invalid address");
        IERC20 token = IERC20(_tokenContract);
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(_msgSender(), balance), "Transfer failed");
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external view override returns (bool) {
        return false;
    }

    receive() external payable {}
}
