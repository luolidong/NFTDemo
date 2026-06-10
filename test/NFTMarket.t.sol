// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DigitalAvatar.sol";
import "../src/MarketToken.sol";
import "../src/NFTMarket.sol";

contract NFTMarketTest is Test {
    DigitalAvatar public nft;
    MarketToken public token;
    NFTMarket public market;

    address public owner;
    address public seller;
    address public buyer;
    uint256 public tokenId = 0;
    uint256 public price = 100 * 10**18;

    function setUp() public {
        owner = address(this);
        seller = address(0x1);
        buyer = address(0x2);

        // 部署合约
        nft = new DigitalAvatar();
        token = new MarketToken();
        market = new NFTMarket(address(nft), address(token));

        // 铸造 NFT 给卖家
        nft.safeMint(seller, "ipfs://test");

        // 铸造代币给买家
        token.mint(buyer, 1000 * 10**18);

        // 授权市场合约
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        // 授权代币
        vm.prank(buyer);
        token.approve(address(market), type(uint256).max);
    }

    function testListNFT() public {
        vm.prank(seller);
        market.list(tokenId, price);

        (address listedSeller, uint256 listedPrice, bool listed) = market.getListing(tokenId);
        
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
        assertTrue(listed);
    }

    function testBuyNFT() public {
        // 上架 NFT
        vm.prank(seller);
        market.list(tokenId, price);

        // 购买 NFT
        vm.prank(buyer);
        market.buyNFT(tokenId, price);

        // 验证 NFT 所有权转移
        assertEq(nft.ownerOf(tokenId), buyer);

        // 验证代币转移
        assertEq(token.balanceOf(seller), price);
        assertEq(token.balanceOf(buyer), 1000 * 10**18 - price);

        // 验证上架信息移除
        (, , bool listed) = market.getListing(tokenId);
        assertFalse(listed);
    }

    function testDelistNFT() public {
        // 上架 NFT
        vm.prank(seller);
        market.list(tokenId, price);

        // 下架 NFT
        vm.prank(seller);
        market.delist(tokenId);

        // 验证下架
        (, , bool listed) = market.getListing(tokenId);
        assertFalse(listed);
    }

    function testOnlySellerCanDelist() public {
        // 上架 NFT
        vm.prank(seller);
        market.list(tokenId, price);

        // 尝试下架（非卖家）
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
        vm.prank(buyer);
        vm.expectRevert("NFT not listed");
        market.buyNFT(tokenId, price);
    }

    function testCannotBuyWithInsufficientPayment() public {
        // 上架 NFT
        vm.prank(seller);
        market.list(tokenId, price);

        // 尝试用不足的金额购买
        vm.prank(buyer);
        vm.expectRevert("Insufficient payment");
        market.buyNFT(tokenId, price - 1);
    }

    function testBuyWithOverpayment() public {
        // 上架 NFT
        vm.prank(seller);
        market.list(tokenId, price);

        // 用超过价格的金额购买
        uint256 overpayment = price + 10 * 10**18;
        vm.prank(buyer);
        market.buyNFT(tokenId, overpayment);

        // 验证 NFT 所有权转移
        assertEq(nft.ownerOf(tokenId), buyer);

        // 验证代币转移（卖家收到价格，买家收到退款）
        assertEq(token.balanceOf(seller), price);
        assertEq(token.balanceOf(buyer), 1000 * 10**18 - price);
    }

    function testTransferAndCall() public {
        // 上架 NFT
        vm.prank(seller);
        market.list(tokenId, price);

        // 通过 ERC1363 transferAndCall 购买 NFT
        bytes memory data = abi.encode(tokenId);
        vm.prank(buyer);
        token.transferAndCall(address(market), price, data);

        // 验证 NFT 所有权转移
        assertEq(nft.ownerOf(tokenId), buyer);

        // 验证代币转移
        assertEq(token.balanceOf(seller), price);
        assertEq(token.balanceOf(buyer), 1000 * 10**18 - price);

        // 验证上架信息移除
        (, , bool listed) = market.getListing(tokenId);
        assertFalse(listed);
    }

    function testTransferAndCallWithOverpayment() public {
        // 上架 NFT
        vm.prank(seller);
        market.list(tokenId, price);

        // 通过 ERC1363 transferAndCall 用超过价格的金额购买 NFT
        uint256 overpayment = price + 10 * 10**18;
        bytes memory data = abi.encode(tokenId);
        vm.prank(buyer);
        token.transferAndCall(address(market), overpayment, data);

        // 验证 NFT 所有权转移
        assertEq(nft.ownerOf(tokenId), buyer);

        // 验证代币转移（卖家收到价格，买家收到退款）
        assertEq(token.balanceOf(seller), price);
        assertEq(token.balanceOf(buyer), 1000 * 10**18 - price);
    }

    function testCannotListWithoutApproval() public {
        // 撤销授权
        vm.prank(seller);
        nft.setApprovalForAll(address(market), false);

        vm.prank(seller);
        vm.expectRevert("Market not approved");
        market.list(tokenId, price);
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

    function testCannotTransferInvalidData() public {
        // 上架 NFT
        vm.prank(seller);
        market.list(tokenId, price);

        // 尝试用空数据购买
        bytes memory data = "";
        vm.prank(buyer);
        vm.expectRevert("Invalid data");
        token.transferAndCall(address(market), price, data);
    }
}