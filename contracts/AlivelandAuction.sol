// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./AlivelandERC721.sol";

interface IAlivelandAddressRegistry {
    function auction() external view returns (address);

    function tokenRegistry() external view returns (address);
}

interface IAlivelandTokenRegistry {
    function enabled(address) external returns (bool);
}

contract AlivelandAuction is Ownable, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;
    using AddressUpgradeable for address payable;
    using SafeERC20 for IERC20;

    uint256 public minBidIncrement = 1;
    uint256 public bidWithdrawalLockTime = 20 minutes;
    uint256 public platformFee = 25;
    address payable public platformFeeRecipient;
    IAlivelandAddressRegistry public addressRegistry;
    bool public isPaused;

    mapping(address => mapping(uint256 => Auction)) public auctions;
    mapping(address => mapping(uint256 => HighestBid)) public highestBids;

    struct Auction {
        address owner;
        address payToken;
        uint256 minBid;
        uint256 reservePrice;
        uint256 startTime;
        uint256 endTime;
        bool resulted;
    }

    struct HighestBid {
        address payable bidder;
        uint256 bid;
        uint256 lastBidTime;
    }

    event AlivelandAuctionContractDeployed();

    event PauseToggled(bool isPaused);

    event AuctionCreated(
        address indexed nftAddress,
        uint256 indexed tokenId,
        string  mediaType,
        uint256 startTime,
        uint256 endTime,
        address payToken,
        uint256 reservePrice,
        address indexed owner,
        uint256 lockTime
    );

    event UpdateAuctionEndTime(
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 endTime
    );

    event UpdateAuctionStartTime(
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 startTime
    );

    event UpdateAuctionReservePrice(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address payToken,
        uint256 reservePrice
    );

    event UpdatePlatformFee(uint256 platformFee);

    event UpdatePlatformFeeRecipient(address payable platformFeeRecipient);

    event UpdateMinBidIncrement(uint256 minBidIncrement);

    event UpdateBidWithdrawalLockTime(uint256 bidWithdrawalLockTime);

    event BidPlaced(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed bidder,
        address owner,
        address payToken,
        uint256 bid
    );

    event BidWithdrawn(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 bid
    );

    event BidRefunded(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed bidder,
        uint256 bid
    );

    event AuctionResulted(
        address oldOwner,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address indexed winner,
        address payToken,
        uint256 winningBid
    );

    event AuctionCancelled(address indexed nftAddress, uint256 indexed tokenId); 

    modifier whenNotPaused() {
        require(!isPaused, "contract paused");
        _;
    }

    function initialize(address payable _platformFeeRecipient)
        public
        initializer
    {
        require(
            _platformFeeRecipient != address(0),
            "AlivelandAuction: Invalid Platform Fee Recipient"
        );

        platformFeeRecipient = _platformFeeRecipient;
        emit AlivelandAuctionContractDeployed();

        __ReentrancyGuard_init();
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
    ) external whenNotPaused {
        require(
            IERC721(_nftAddress).ownerOf(_tokenId) == _msgSender() &&
                IERC721(_nftAddress).isApprovedForAll(
                    _msgSender(),
                    address(this)
                ),
            "not owner or contract not approved"
        );

        require(
            (addressRegistry.tokenRegistry() != address(0) &&
                IAlivelandTokenRegistry(addressRegistry.tokenRegistry())
                    .enabled(_payToken)),
            "invalid pay token"
        );

        _createAuction(
            _nftAddress,
            _tokenId,
            _mediaType,
            _payToken,
            _reservePrice,
            _startTimestamp,
            minBidReserve,
            _endTimestamp
        );
    }
    
    function placeBid(
        address _nftAddress,
        uint256 _tokenId,
        address _owner,
        uint256 _bidAmount
    ) external payable nonReentrant whenNotPaused {
        require(tx.origin == _msgSender(), "no contracts permitted");

        Auction memory auction = auctions[_nftAddress][_tokenId];

        require(
            _getNow() >= auction.startTime && _getNow() <= auction.endTime,
            "bidding outside of the auction duration"
        );
        require(
            auction.payToken != address(0),
            "ERC20 method used for Aliveland auction"
        );

        _placeBid(_nftAddress, _tokenId, _owner, _bidAmount);
    }

    function _placeBid(
        address _nftAddress,
        uint256 _tokenId,
        address _owner,
        uint256 _bidAmount
    ) internal whenNotPaused {
        Auction storage auction = auctions[_nftAddress][_tokenId];

        if (auction.minBid == auction.reservePrice) {
            require(
                _bidAmount >= auction.reservePrice,
                "bid cannot be lower than reserve price"
            );
        }

        HighestBid storage highestBid = highestBids[_nftAddress][_tokenId];
        uint256 minBidRequired = highestBid.bid.add(minBidIncrement);

        require(_bidAmount >= minBidRequired, "failed to outbid highest bidder");

        if (auction.payToken != address(0)) {
            _safeTransferFrom(auction.payToken, _bidAmount, _msgSender(), address(this));
        }

        if (highestBid.bidder != address(0)) {
            _refundHighestBidder(
                _nftAddress,
                _tokenId,
                highestBid.bidder,
                highestBid.bid
            );
        }

        highestBid.bidder = payable(_msgSender());
        highestBid.bid = _bidAmount;
        highestBid.lastBidTime = _getNow();

        emit BidPlaced(_nftAddress, _tokenId, _msgSender(), _owner, auction.payToken, _bidAmount);
    }

    function withdrawBid(address _nftAddress, uint256 _tokenId)
        external
        nonReentrant
        whenNotPaused
    {
        HighestBid storage highestBid = highestBids[_nftAddress][_tokenId];

        require(
            highestBid.bidder == _msgSender(),
            "you are not the highest bidder"
        );

        uint256 _endTime = auctions[_nftAddress][_tokenId].endTime;

        require(
            _getNow() > _endTime && (_getNow() - _endTime >= 43200),
            "can withdraw only after 12 hours (after auction ended)"
        );

        uint256 previousBid = highestBid.bid;

        _refundHighestBidder(_nftAddress, _tokenId, payable(_msgSender()), previousBid);

        delete highestBids[_nftAddress][_tokenId];

        emit BidWithdrawn(_nftAddress, _tokenId, _msgSender(), previousBid);
    }

    function resultAuction(address _nftAddress, uint256 _tokenId)
        external
        nonReentrant
    {
        Auction memory auction = auctions[_nftAddress][_tokenId];

        require(
            IERC721(_nftAddress).ownerOf(_tokenId) == _msgSender() &&
                _msgSender() == auction.owner,
            "sender must be item owner"
        );

        require(auction.endTime > 0, "no auction exists");
        require(_getNow() > auction.endTime, "auction not ended");
        require(!auction.resulted, "auction already resulted");

        HighestBid memory highestBid = highestBids[_nftAddress][_tokenId];
        address winner = highestBid.bidder;
        uint256 winningBid = highestBid.bid;

        require(winner != address(0), "no open bids");
        require(
            winningBid >= auction.reservePrice,
            "highest bid is below reservePrice"
        );
        
        require(
            IERC721(_nftAddress).isApprovedForAll(_msgSender(), address(this)),
            "auction not approved"
        );

        uint256 payAmount = winningBid;

        if (payAmount > auction.reservePrice && platformFeeRecipient != address(0)) {
            uint256 aboveReservePrice = payAmount.sub(auction.reservePrice);

            uint256 platformFeeAboveReserve = aboveReservePrice
                .mul(platformFee)
                .div(1000);

            _safeTransfer(auction.payToken, platformFeeAboveReserve, platformFeeRecipient);

            payAmount = payAmount.sub(platformFeeAboveReserve);
        }

        (address minter, uint256 royaltyFee) = AlivelandERC721(_nftAddress).royaltyInfo(_tokenId, payAmount);
        if (royaltyFee > 0) {
            _safeTransfer(auction.payToken, royaltyFee, minter);
            payAmount = payAmount.sub(royaltyFee);
        }
        if (payAmount > 0) {
            _safeTransfer(auction.payToken, payAmount, auction.owner);
        }
        
        IERC721(_nftAddress).safeTransferFrom(
            IERC721(_nftAddress).ownerOf(_tokenId),
            winner,
            _tokenId
        );

        emit AuctionResulted(
            _msgSender(),
            _nftAddress,
            _tokenId,
            winner,
            auction.payToken,
            winningBid
        );

        delete auctions[_nftAddress][_tokenId];
        delete highestBids[_nftAddress][_tokenId];
    }

    function cancelAuction(address _nftAddress, uint256 _tokenId)
        external
        nonReentrant
    {
        Auction memory auction = auctions[_nftAddress][_tokenId];

        require(
            IERC721(_nftAddress).ownerOf(_tokenId) == _msgSender() &&
                _msgSender() == auction.owner,
            "sender must be owner"
        );
        require(auction.endTime > 0, "no auction exists");
        require(!auction.resulted, "auction already resulted");

        _cancelAuction(_nftAddress, _tokenId);
    }

    function toggleIsPaused() external onlyOwner {
        isPaused = !isPaused;
        emit PauseToggled(isPaused);
    }

    function updateMinBidIncrement(uint256 _minBidIncrement)
        external
        onlyOwner
    {
        minBidIncrement = _minBidIncrement;
        emit UpdateMinBidIncrement(_minBidIncrement);
    }

    function updateBidWithdrawalLockTime(uint256 _bidWithdrawalLockTime)
        external
        onlyOwner
    {
        bidWithdrawalLockTime = _bidWithdrawalLockTime;
        emit UpdateBidWithdrawalLockTime(_bidWithdrawalLockTime);
    }

    function updateAuctionReservePrice(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _reservePrice
    ) external {
        Auction storage auction = auctions[_nftAddress][_tokenId];

        require(_msgSender() == auction.owner, "sender must be item owner");
        require(!auction.resulted, "auction already resulted");
        require(auction.endTime > 0, "no auction exists");

        auction.reservePrice = _reservePrice;

        emit UpdateAuctionReservePrice(
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

        require(_msgSender() == auction.owner, "sender must be owner");
        require(_startTime > 0, "invalid start time");
        require(auction.startTime + 60 > _getNow(), "auction already started");
        require(
            _startTime + 300 < auction.endTime,
            "start time should be less than end time (by 5 minutes)"
        );
        require(!auction.resulted, "auction already resulted");
        require(auction.endTime > 0, "no auction exists");

        auction.startTime = _startTime;
        emit UpdateAuctionStartTime(_nftAddress, _tokenId, _startTime);
    }

    function updateAuctionEndTime(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _endTimestamp
    ) external {
        Auction storage auction = auctions[_nftAddress][_tokenId];

        require(_msgSender() == auction.owner, "sender must be owner");
        require(_getNow() < auction.endTime, "auction already ended");
        require(auction.endTime > 0, "no auction exists");
        require(
            auction.startTime < _endTimestamp,
            "end time must be greater than start"
        );
        require(
            _endTimestamp > _getNow() + 300,
            "auction should end after 5 minutes"
        );

        auction.endTime = _endTimestamp;
        emit UpdateAuctionEndTime(_nftAddress, _tokenId, _endTimestamp);
    }

    function updatePlatformFee(uint256 _platformFee) external onlyOwner {
        platformFee = _platformFee;
        emit UpdatePlatformFee(_platformFee);
    }

    function updatePlatformFeeRecipient(address payable _platformFeeRecipient)
        external
        onlyOwner
    {
        require(_platformFeeRecipient != address(0), "zero address");

        platformFeeRecipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }

    function updateAddressRegistry(address _registry) external onlyOwner {
        addressRegistry = IAlivelandAddressRegistry(_registry);
    }

    function getAuction(address _nftAddress, uint256 _tokenId)
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
            auction.owner,
            auction.payToken,
            auction.reservePrice,
            auction.startTime,
            auction.endTime,
            auction.resulted,
            auction.minBid
        );
    }

    function getHighestBidder(address _nftAddress, uint256 _tokenId)
        external
        view
        returns (
            address payable _bidder,
            uint256 _bid,
            uint256 _lastBidTime
        )
    {
        HighestBid storage highestBid = highestBids[_nftAddress][_tokenId];
        return (highestBid.bidder, highestBid.bid, highestBid.lastBidTime);
    }

    function _getNow() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    function _createAuction(
        address _nftAddress,
        uint256 _tokenId,
        string memory _mediaType,
        address _payToken,
        uint256 _reservePrice,
        uint256 _startTimestamp,
        bool minBidReserve,
        uint256 _endTimestamp
    ) private {
        require(
            auctions[_nftAddress][_tokenId].endTime == 0,
            "auction already started"
        );

        require(
            _endTimestamp >= _startTimestamp + 300,
            "end time must be greater than start (by 5 minutes)"
        );
        require(_startTimestamp > _getNow(), "invalid start time");

        uint256 minimumBid = 0;

        if (minBidReserve) {
            minimumBid = _reservePrice;
        }

        auctions[_nftAddress][_tokenId] = Auction({
            owner: _msgSender(),
            payToken: _payToken,
            minBid: minimumBid,
            reservePrice: _reservePrice,
            startTime: _startTimestamp,
            endTime: _endTimestamp,
            resulted: false
        });

        emit AuctionCreated(_nftAddress, _tokenId, _mediaType,  _startTimestamp, _endTimestamp, _payToken, _reservePrice, _msgSender(), bidWithdrawalLockTime);
    }

    function _cancelAuction(address _nftAddress, uint256 _tokenId) private {
        HighestBid storage highestBid = highestBids[_nftAddress][_tokenId];
        if (highestBid.bidder != address(0)) {
            _refundHighestBidder(
                _nftAddress,
                _tokenId,
                highestBid.bidder,
                highestBid.bid
            );

            delete highestBids[_nftAddress][_tokenId];
        }

        delete auctions[_nftAddress][_tokenId];

        emit AuctionCancelled(_nftAddress, _tokenId);
    }

    function _refundHighestBidder(
        address _nftAddress,
        uint256 _tokenId,
        address payable _currentHighestBidder,
        uint256 _currentHighestBid
    ) private {
        Auction memory auction = auctions[_nftAddress][_tokenId];

        _safeTransfer(auction.payToken, _currentHighestBid, _currentHighestBidder);

        emit BidRefunded(
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
            if (_to != address(this)) {
                (bool success, ) = payable(_to).call{ value: _amount }("");
                require(success, "ether transfer failed");
            }
        } else {
            IERC20 payToken = IERC20(_payToken);
            payToken.safeTransferFrom(_from, _to, _amount);
        }
    }

    function reclaimERC20(address _tokenContract) external onlyOwner {
        require(_tokenContract != address(0), "Invalid address");
        IERC20 token = IERC20(_tokenContract);
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(_msgSender(), balance), "Transfer failed");
    }
}
