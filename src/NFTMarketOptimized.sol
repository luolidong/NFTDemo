// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketOptimized is IERC1363Receiver, Ownable {
    IERC721 public immutable nftContract;
    IERC20 public immutable marketToken;

    struct Listing {
        uint96 price;
        address seller;
    }

    mapping(uint256 => Listing) public listings;

    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event NFTDelisted(address indexed seller, uint256 indexed tokenId);

    constructor(address _nftContract, address _marketToken) Ownable(msg.sender) {
        nftContract = IERC721(_nftContract);
        marketToken = IERC20(_marketToken);
    }

    function list(uint256 tokenId, uint96 price) external {
        require(price > 0, "Price must be greater than 0");
        require(nftContract.ownerOf(tokenId) == msg.sender, "You don't own this NFT");
        require(nftContract.getApproved(tokenId) == address(this) || nftContract.isApprovedForAll(msg.sender, address(this)), "Market not approved");
        
        listings[tokenId] = Listing({
            price: price,
            seller: msg.sender
        });

        emit NFTListed(msg.sender, tokenId, price);
    }

    function delist(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        require(listing.price > 0, "NFT not listed");
        require(listing.seller == msg.sender, "You are not the seller");
        
        listing.price = 0;
        
        emit NFTDelisted(msg.sender, tokenId);
    }

    function buyNFT(uint256 tokenId, uint256 amount) external {
        Listing storage listing = listings[tokenId];
        require(listing.price > 0, "NFT not listed");
        require(amount >= listing.price, "Insufficient payment");

        _buyFromCaller(listing, msg.sender, tokenId, amount);
    }

    function onTransferReceived(
        address,
        address from,
        uint256 amount,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(marketToken), "Invalid token");
        require(data.length >= 32, "Invalid data");
        
        uint256 tokenId = abi.decode(data, (uint256));
        Listing storage listing = listings[tokenId];
        
        require(listing.price > 0, "NFT not listed");
        require(amount >= listing.price, "Insufficient payment");

        _buyFromContract(listing, from, tokenId, amount);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    function getListing(uint256 tokenId) external view returns (address seller, uint256 price, bool listed) {
        Listing memory listing = listings[tokenId];
        return (listing.seller, listing.price, listing.price > 0);
    }

    function _buyFromCaller(Listing storage listing, address buyer, uint256 tokenId, uint256 amount) private {
        uint256 price = listing.price;
        
        marketToken.transferFrom(buyer, listing.seller, price);

        if (amount > price) {
            unchecked {
                marketToken.transferFrom(buyer, buyer, amount - price);
            }
        }

        _completeTransfer(listing, buyer, tokenId, price);
    }

    function _buyFromContract(Listing storage listing, address buyer, uint256 tokenId, uint256 amount) private {
        uint256 price = listing.price;
        
        marketToken.transfer(listing.seller, price);

        if (amount > price) {
            unchecked {
                marketToken.transfer(buyer, amount - price);
            }
        }

        _completeTransfer(listing, buyer, tokenId, price);
    }

    function _completeTransfer(Listing storage listing, address buyer, uint256 tokenId, uint256 price) private {
        nftContract.safeTransferFrom(listing.seller, buyer, tokenId);
        listing.price = 0;
        emit NFTSold(listing.seller, buyer, tokenId, price);
    }
}