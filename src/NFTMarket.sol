// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarket is IERC1363Receiver, Ownable {
    // NFT 合约
    IERC721 public nftContract;
    // 市场代币合约
    IERC20 public marketToken;

    // NFT 上架信息
    struct Listing {
        address seller;
        uint256 price;
        bool listed;
    }

    // tokenId -> Listing
    mapping(uint256 => Listing) public listings;

    // 事件
    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event NFTDelisted(address indexed seller, uint256 indexed tokenId);

    constructor(address _nftContract, address _marketToken) Ownable(msg.sender) {
        nftContract = IERC721(_nftContract);
        marketToken = IERC20(_marketToken);
    }

    // 上架 NFT
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

    // 下架 NFT
    function delist(uint256 tokenId) external {
        require(listings[tokenId].listed, "NFT not listed");
        require(listings[tokenId].seller == msg.sender, "You are not the seller");
        
        listings[tokenId].listed = false;
        
        emit NFTDelisted(msg.sender, tokenId);
    }

    // 购买 NFT
    function buyNFT(uint256 tokenId, uint256 amount) external {
        Listing storage listing = listings[tokenId];
        require(listing.listed, "NFT not listed");
        require(amount >= listing.price, "Insufficient payment");
        require(nftContract.ownerOf(tokenId) == listing.seller, "NFT owner changed");

        // 转移代币给卖家
        marketToken.transferFrom(msg.sender, listing.seller, listing.price);

        // 如果支付金额超过价格，退还多余部分
        if (amount > listing.price) {
            marketToken.transferFrom(msg.sender, msg.sender, amount - listing.price);
        }

        // 转移 NFT 给买家
        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);

        // 移除上架信息
        listings[tokenId].listed = false;

        emit NFTSold(listing.seller, msg.sender, tokenId, listing.price);
    }

    // ERC1363 接收者回调
    function onTransferReceived(
        address operator,
        address from,
        uint256 amount,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(marketToken), "Invalid token");

        // 解析 data 获取 tokenId
        require(data.length >= 32, "Invalid data");
        uint256 tokenId = abi.decode(data, (uint256));

        // 检查 NFT 是否上架
        Listing storage listing = listings[tokenId];
        require(listing.listed, "NFT not listed");
        require(amount >= listing.price, "Insufficient payment");
        require(nftContract.ownerOf(tokenId) == listing.seller, "NFT owner changed");

        // 转移代币给卖家
        marketToken.transfer(listing.seller, listing.price);

        // 如果支付金额超过价格，退还多余部分
        if (amount > listing.price) {
            marketToken.transfer(from, amount - listing.price);
        }

        // 转移 NFT 给买家
        nftContract.safeTransferFrom(listing.seller, from, tokenId);

        // 移除上架信息
        listings[tokenId].listed = false;

        emit NFTSold(listing.seller, from, tokenId, listing.price);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    // 获取 NFT 上架信息
    function getListing(uint256 tokenId) external view returns (address seller, uint256 price, bool listed) {
        Listing memory listing = listings[tokenId];
        return (listing.seller, listing.price, listing.listed);
    }

    // 更新 NFT 合约地址
    function setNFTContract(address _nftContract) external onlyOwner {
        nftContract = IERC721(_nftContract);
    }

    // 更新市场代币合约地址
    function setMarketToken(address _marketToken) external onlyOwner {
        marketToken = IERC20(_marketToken);
    }
}