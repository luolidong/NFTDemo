// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract NFTMarket2 is Ownable {
    // NFT 合约
    IERC721 public nftContract;
    // 市场代币合约（支持 EIP-2612 permit）
    IERC20Permit public marketToken;
    // 签名者地址（项目方后端）
    address public signer;

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
    event SignerChanged(address indexed oldSigner, address indexed newSigner);

    constructor(address _nftContract, address _marketToken, address _signer) Ownable(msg.sender) {
        require(_nftContract != address(0), "NFT contract cannot be zero");
        require(_marketToken != address(0), "Market token cannot be zero");
        require(_signer != address(0), "Signer cannot be zero");
        
        nftContract = IERC721(_nftContract);
        marketToken = IERC20Permit(_marketToken);
        signer = _signer;
    }

    // 获取 EIP-712 域名分隔符
    function getDomainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("NFTMarket2")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    // 获取签名消息哈希
    function getMessageHash(
        address buyer,
        uint256 tokenId,
        uint256 price,
        uint256 deadline
    ) public view returns (bytes32) {
        bytes32 domainSeparator = getDomainSeparator();
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("PermitBuy(address buyer,uint256 tokenId,uint256 price,uint256 deadline)"),
                buyer,
                tokenId,
                price,
                deadline
            )
        );
        
        return MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
    }

    // 验证白名单签名
    function verifySignature(
        address buyer,
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        bytes memory signature
    ) public view returns (bool) {
        require(block.timestamp <= deadline, "Signature expired");
        
        bytes32 messageHash = getMessageHash(buyer, tokenId, price, deadline);
        address recoveredSigner = ECDSA.recover(messageHash, signature);
        
        return recoveredSigner == signer;
    }

    // 上架 NFT（同NFTMarket）
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

    // 下架 NFT（同NFTMarket）
    function delist(uint256 tokenId) external {
        require(listings[tokenId].listed, "NFT not listed");
        require(listings[tokenId].seller == msg.sender, "You are not the seller");
        
        listings[tokenId].listed = false;
        
        emit NFTDelisted(msg.sender, tokenId);
    }

    // 使用白名单签名 + EIP-2612 permit 购买 NFT（无需提前 approve）
    function permitBuy(
        uint256 tokenId,
        uint256 price,
        uint256 whitelistDeadline,
        bytes memory whitelistSignature,
        // EIP-2612 permit 参数
        uint256 permitDeadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external {
        Listing storage listing = listings[tokenId];
        require(listing.listed, "NFT not listed");
        require(listing.price == price, "Price mismatch");
        require(nftContract.ownerOf(tokenId) == listing.seller, "NFT owner changed");
        
        // 验证白名单签名
        require(verifySignature(msg.sender, tokenId, price, whitelistDeadline, whitelistSignature), "Invalid whitelist signature");

        // 使用 EIP-2612 permit 授权（无需提前 approve）
        marketToken.permit(msg.sender, address(this), listing.price, permitDeadline, permitV, permitR, permitS);

        // 转移代币给卖家
        IERC20(address(marketToken)).transferFrom(msg.sender, listing.seller, listing.price);

        // 转移 NFT 给买家
        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);

        // 移除上架信息
        listings[tokenId].listed = false;

        emit NFTSold(listing.seller, msg.sender, tokenId, listing.price);
    }

    // 更新签名者地址
    function setSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Signer cannot be zero");
        emit SignerChanged(signer, _signer);
        signer = _signer;
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
        marketToken = IERC20Permit(_marketToken);
    }
}