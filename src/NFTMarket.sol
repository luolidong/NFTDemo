// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NFTMarket is Initializable, UUPSUpgradeable, IERC1363Receiver, OwnableUpgradeable {
    IERC721 public nftContract;
    IERC20 public marketToken;

    struct Listing {
        address seller;
        uint256 price;
        bool listed;
    }

    mapping(uint256 => Listing) public listings;

    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event NFTDelisted(address indexed seller, uint256 indexed tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _nftContract, address _marketToken) public virtual initializer {
        __Ownable_init(msg.sender);
        nftContract = IERC721(_nftContract);
        marketToken = IERC20(_marketToken);
    }

    function list(uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than 0");
        require(nftContract.ownerOf(tokenId) == msg.sender, "You don't own this NFT");
        require(nftContract.getApproved(tokenId) == address(this) || nftContract.isApprovedForAll(msg.sender, address(this)), "Market not approved");
        
        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            listed: true
        });

        emit NFTListed(msg.sender, tokenId, price);
    }

    function delist(uint256 tokenId) external {
        require(listings[tokenId].listed, "NFT not listed");
        require(listings[tokenId].seller == msg.sender, "You are not the seller");
        
        listings[tokenId].listed = false;
        
        emit NFTDelisted(msg.sender, tokenId);
    }

    function buyNFT(uint256 tokenId, uint256 amount) external {
        Listing storage listing = listings[tokenId];
        require(listing.listed, "NFT not listed");
        require(amount >= listing.price, "Insufficient payment");
        require(nftContract.ownerOf(tokenId) == listing.seller, "NFT owner changed");

        marketToken.transferFrom(msg.sender, listing.seller, listing.price);

        if (amount > listing.price) {
            marketToken.transferFrom(msg.sender, msg.sender, amount - listing.price);
        }

        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);

        listings[tokenId].listed = false;

        emit NFTSold(listing.seller, msg.sender, tokenId, listing.price);
    }

    function onTransferReceived(
        address operator,
        address from,
        uint256 amount,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(marketToken), "Invalid token");

        require(data.length >= 32, "Invalid data");
        uint256 tokenId = abi.decode(data, (uint256));

        Listing storage listing = listings[tokenId];
        require(listing.listed, "NFT not listed");
        require(amount >= listing.price, "Insufficient payment");
        require(nftContract.ownerOf(tokenId) == listing.seller, "NFT owner changed");

        marketToken.transfer(listing.seller, listing.price);

        if (amount > listing.price) {
            marketToken.transfer(from, amount - listing.price);
        }

        nftContract.safeTransferFrom(listing.seller, from, tokenId);

        listings[tokenId].listed = false;

        emit NFTSold(listing.seller, from, tokenId, listing.price);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    function getListing(uint256 tokenId) external view returns (address seller, uint256 price, bool listed) {
        Listing memory listing = listings[tokenId];
        return (listing.seller, listing.price, listing.listed);
    }

    function setNFTContract(address _nftContract) external onlyOwner {
        nftContract = IERC721(_nftContract);
    }

    function setMarketToken(address _marketToken) external onlyOwner {
        marketToken = IERC20(_marketToken);
    }

    function _authorizeUpgrade(address newImplementation) internal view virtual override onlyOwner {}
}