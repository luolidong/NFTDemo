// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DigitalAvatar.sol";
import "../src/MarketToken.sol";
import "../src/NFTMarket2.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract NFTMarket2Test is Test {
    DigitalAvatar public nft;
    MarketToken public token;
    NFTMarket2 public market;

    address public owner;
    address public seller;
    address public buyer;
    address public signer;
    uint256 public tokenId = 0;
    uint256 public price = 100 * 10**18;

    // 签名者私钥（用于测试签名）
    uint256 public signerPrivateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    // 买家私钥（用于 EIP-2612 permit 签名）
    uint256 public buyerPrivateKey = 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890;

    function setUp() public {
        owner = address(this);
        seller = address(0x1);
        buyer = vm.addr(buyerPrivateKey);
        signer = vm.addr(signerPrivateKey);

        // 部署合约
        nft = new DigitalAvatar();
        token = new MarketToken();
        market = new NFTMarket2(address(nft), address(token), signer);

        // 铸造 NFT 给卖家
        nft.safeMint(seller, "ipfs://test");

        // 铸造代币给买家
        token.mint(buyer, 1000 * 10**18);

        // 授权市场合约
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        // 注意：不再需要提前 approve！
    }

    // 生成白名单签名
    function _generateWhitelistSignature(
        address buyerAddr,
        uint256 _tokenId,
        uint256 _price,
        uint256 deadline
    ) internal view returns (bytes memory) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("NFTMarket2"),
                keccak256("1"),
                block.chainid,
                address(market)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("PermitBuy(address buyer,uint256 tokenId,uint256 price,uint256 deadline)"),
                buyerAddr,
                _tokenId,
                _price,
                deadline
            )
        );

        bytes32 messageHash = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, messageHash);
        
        return abi.encodePacked(r, s, v);
    }

    // 生成无效的白名单签名
    function _generateInvalidWhitelistSignature(
        uint256 _tokenId,
        uint256 _price,
        uint256 deadline
    ) internal view returns (bytes memory) {
        uint256 wrongPrivateKey = 0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef;
        
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("NFTMarket2"),
                keccak256("1"),
                block.chainid,
                address(market)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("PermitBuy(address buyer,uint256 tokenId,uint256 price,uint256 deadline)"),
                buyer,
                _tokenId,
                _price,
                deadline
            )
        );

        bytes32 messageHash = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, messageHash);
        return abi.encodePacked(r, s, v);
    }

    // 生成 EIP-2612 permit 签名
    function _generatePermitSignature(
        uint256 value,
        uint256 deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                buyer,
                address(market),
                value,
                token.nonces(buyer),
                deadline
            )
        );

        bytes32 messageHash = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
        return vm.sign(buyerPrivateKey, messageHash);
    }

    function testListNFT() public {
        vm.prank(seller);
        market.list(tokenId, price);

        (address listedSeller, uint256 listedPrice, bool listed) = market.getListing(tokenId);
        
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
        assertTrue(listed);
    }

    function testPermitBuyWithValidSignature() public {
        vm.prank(seller);
        market.list(tokenId, price);

        // 生成白名单签名
        bytes memory whitelistSignature = _generateWhitelistSignature(buyer, tokenId, price, block.timestamp + 1 days);

        // 生成 permit 签名
        (uint8 permitV, bytes32 permitR, bytes32 permitS) = _generatePermitSignature(price, block.timestamp + 1 days);

        // 使用签名购买 NFT
        vm.prank(buyer);
        market.permitBuy(tokenId, price, block.timestamp + 1 days, whitelistSignature, block.timestamp + 1 days, permitV, permitR, permitS);

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);
        assertEq(token.balanceOf(buyer), 1000 * 10**18 - price);

        (, , bool listed) = market.getListing(tokenId);
        assertFalse(listed);
    }

    function testPermitBuyWithInvalidWhitelistSignature() public {
        vm.prank(seller);
        market.list(tokenId, price);

        // 生成无效白名单签名
        bytes memory invalidSignature = _generateInvalidWhitelistSignature(tokenId, price, block.timestamp + 1 days);

        // 生成 permit 签名
        (uint8 permitV, bytes32 permitR, bytes32 permitS) = _generatePermitSignature(price, block.timestamp + 1 days);

        vm.prank(buyer);
        vm.expectRevert("Invalid whitelist signature");
        market.permitBuy(tokenId, price, block.timestamp + 1 days, invalidSignature, block.timestamp + 1 days, permitV, permitR, permitS);
    }

    function testPermitBuyWithExpiredWhitelistSignature() public {
        vm.prank(seller);
        market.list(tokenId, price);

        vm.warp(1000 hours);
        
        // 生成已过期的白名单签名
        bytes memory whitelistSignature = _generateWhitelistSignature(buyer, tokenId, price, 500 hours);
        
        // 生成 permit 签名
        (uint8 permitV, bytes32 permitR, bytes32 permitS) = _generatePermitSignature(price, block.timestamp + 1 days);

        vm.prank(buyer);
        vm.expectRevert("Signature expired");
        market.permitBuy(tokenId, price, 500 hours, whitelistSignature, block.timestamp + 1 days, permitV, permitR, permitS);
    }

    function testPermitBuyWithWrongPrice() public {
        vm.prank(seller);
        market.list(tokenId, price);

        // 生成正确价格的白名单签名
        bytes memory whitelistSignature = _generateWhitelistSignature(buyer, tokenId, price, block.timestamp + 1 days);

        // 生成 permit 签名（使用正确价格）
        (uint8 permitV, bytes32 permitR, bytes32 permitS) = _generatePermitSignature(price, block.timestamp + 1 days);

        // 尝试用错误价格购买
        uint256 wrongPrice = price + 10 * 10**18;
        vm.prank(buyer);
        vm.expectRevert("Price mismatch");
        market.permitBuy(tokenId, wrongPrice, block.timestamp + 1 days, whitelistSignature, block.timestamp + 1 days, permitV, permitR, permitS);
    }

    function testPermitBuyWithWrongBuyer() public {
        vm.prank(seller);
        market.list(tokenId, price);

        // 为 wrongBuyer 签名
        address wrongBuyer = address(0x3);
        bytes memory whitelistSignature = _generateWhitelistSignature(wrongBuyer, tokenId, price, block.timestamp + 1 days);

        // 生成 permit 签名
        (uint8 permitV, bytes32 permitR, bytes32 permitS) = _generatePermitSignature(price, block.timestamp + 1 days);

        vm.prank(buyer);
        vm.expectRevert("Invalid whitelist signature");
        market.permitBuy(tokenId, price, block.timestamp + 1 days, whitelistSignature, block.timestamp + 1 days, permitV, permitR, permitS);
    }

    function testDelistNFT() public {
        vm.prank(seller);
        market.list(tokenId, price);

        vm.prank(seller);
        market.delist(tokenId);

        (, , bool listed) = market.getListing(tokenId);
        assertFalse(listed);
    }

    function testOnlySellerCanDelist() public {
        vm.prank(seller);
        market.list(tokenId, price);

        vm.prank(buyer);
        vm.expectRevert("You are not the seller");
        market.delist(tokenId);
    }

    function testCannotListZeroPrice() public {
        vm.prank(seller);
        vm.expectRevert("Price must be greater than 0");
        market.list(tokenId, 0);
    }

    function testCannotBuyUnlistedNFT() public {
        bytes memory whitelistSignature = _generateWhitelistSignature(buyer, tokenId, price, block.timestamp + 1 days);
        (uint8 permitV, bytes32 permitR, bytes32 permitS) = _generatePermitSignature(price, block.timestamp + 1 days);
        
        vm.prank(buyer);
        vm.expectRevert("NFT not listed");
        market.permitBuy(tokenId, price, block.timestamp + 1 days, whitelistSignature, block.timestamp + 1 days, permitV, permitR, permitS);
    }

    function testOnlyOwnerCanUpdateSigner() public {
        address newSigner = address(0x3);

        vm.prank(seller);
        vm.expectRevert();
        market.setSigner(newSigner);

        market.setSigner(newSigner);
        assertEq(market.signer(), newSigner);
    }

    function testOnlyOwnerCanUpdateContracts() public {
        address newNFT = address(0x3);
        address newToken = address(0x4);

        vm.prank(seller);
        vm.expectRevert();
        market.setNFTContract(newNFT);

        market.setNFTContract(newNFT);
        market.setMarketToken(newToken);
    }

    function testPermitBuyWithExpiredPermit() public {
        vm.prank(seller);
        market.list(tokenId, price);

        bytes memory whitelistSignature = _generateWhitelistSignature(buyer, tokenId, price, block.timestamp + 2 days);

        vm.warp(1000 hours);
        
        // 生成已过期的 permit
        (uint8 permitV, bytes32 permitR, bytes32 permitS) = _generatePermitSignature(price, 500 hours);

        vm.prank(buyer);
        vm.expectRevert();
        market.permitBuy(tokenId, price, block.timestamp + 2 days, whitelistSignature, 500 hours, permitV, permitR, permitS);
    }

    function testPermitBuyWithoutPreApproval() public {
        vm.prank(seller);
        market.list(tokenId, price);

        // 确认没有提前 approve
        assertEq(token.allowance(buyer, address(market)), 0);

        bytes memory whitelistSignature = _generateWhitelistSignature(buyer, tokenId, price, block.timestamp + 1 days);
        (uint8 permitV, bytes32 permitR, bytes32 permitS) = _generatePermitSignature(price, block.timestamp + 1 days);

        vm.prank(buyer);
        market.permitBuy(tokenId, price, block.timestamp + 1 days, whitelistSignature, block.timestamp + 1 days, permitV, permitR, permitS);

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);
        assertEq(token.balanceOf(buyer), 1000 * 10**18 - price);
    }
}