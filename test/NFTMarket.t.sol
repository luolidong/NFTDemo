// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/foundry-upgrades/Upgrades.sol";
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

        nft = new DigitalAvatar();
        token = new MarketToken();
        
        address proxy = Upgrades.deployUUPSProxy(
            "NFTMarket.sol:NFTMarket",
            abi.encodeCall(NFTMarket.initialize, (address(nft), address(token)))
        );
        market = NFTMarket(proxy);

        nft.safeMint(seller, "ipfs://test");

        token.mint(buyer, 1000 * 10**18);

        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

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
        vm.prank(seller);
        market.list(tokenId, price);

        vm.prank(buyer);
        market.buyNFT(tokenId, price);

        assertEq(nft.ownerOf(tokenId), buyer);

        assertEq(token.balanceOf(seller), price);
        assertEq(token.balanceOf(buyer), 1000 * 10**18 - price);

        (, , bool listed) = market.getListing(tokenId);
        assertFalse(listed);
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
        vm.prank(buyer);
        vm.expectRevert("NFT not listed");
        market.buyNFT(tokenId, price);
    }

    function testCannotBuyWithInsufficientPayment() public {
        vm.prank(seller);
        market.list(tokenId, price);

        vm.prank(buyer);
        vm.expectRevert("Insufficient payment");
        market.buyNFT(tokenId, price - 1);
    }

    function testBuyWithOverpayment() public {
        vm.prank(seller);
        market.list(tokenId, price);

        uint256 overpayment = price + 10 * 10**18;
        vm.prank(buyer);
        market.buyNFT(tokenId, overpayment);

        assertEq(nft.ownerOf(tokenId), buyer);

        assertEq(token.balanceOf(seller), price);
        assertEq(token.balanceOf(buyer), 1000 * 10**18 - price);
    }

    function testTransferAndCall() public {
        vm.prank(seller);
        market.list(tokenId, price);

        bytes memory data = abi.encode(tokenId);
        vm.prank(buyer);
        token.transferAndCall(address(market), price, data);

        assertEq(nft.ownerOf(tokenId), buyer);

        assertEq(token.balanceOf(seller), price);
        assertEq(token.balanceOf(buyer), 1000 * 10**18 - price);

        (, , bool listed) = market.getListing(tokenId);
        assertFalse(listed);
    }

    function testTransferAndCallWithOverpayment() public {
        vm.prank(seller);
        market.list(tokenId, price);

        uint256 overpayment = price + 10 * 10**18;
        bytes memory data = abi.encode(tokenId);
        vm.prank(buyer);
        token.transferAndCall(address(market), overpayment, data);

        assertEq(nft.ownerOf(tokenId), buyer);

        assertEq(token.balanceOf(seller), price);
        assertEq(token.balanceOf(buyer), 1000 * 10**18 - price);
    }

    function testCannotListWithoutApproval() public {
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
        vm.prank(seller);
        market.list(tokenId, price);

        bytes memory data = "";
        vm.prank(buyer);
        vm.expectRevert("Invalid data");
        token.transferAndCall(address(market), price, data);
    }
}