// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DigitalAvatar.sol";

contract DigitalAvatarTest is Test {
    DigitalAvatar public nft;
    address public owner = address(0x1234);
    address public user = address(0x5678);

    function setUp() public {
        vm.prank(owner);
        nft = new DigitalAvatar();
    }

    function testName() public view {
        assertEq(nft.name(), "DigitalAvatar");
    }

    function testSymbol() public view {
        assertEq(nft.symbol(), "DIGI");
    }

    function testMint() public {
        vm.prank(owner);
        nft.mint(user, "ipfs://Qm...");
        
        assertEq(nft.balanceOf(user), 1);
        assertEq(nft.ownerOf(0), user);
        assertEq(nft.tokenURI(0), "ipfs://Qm...");
    }

    function testSafeMint() public {
        vm.prank(owner);
        nft.safeMint(user, "ipfs://Qm...");
        
        assertEq(nft.balanceOf(user), 1);
        assertEq(nft.ownerOf(0), user);
    }

    function testOnlyOwnerCanMint() public {
        vm.prank(user);
        vm.expectRevert();
        nft.mint(user, "ipfs://Qm...");
    }

    function testTokenURI() public {
        vm.prank(owner);
        nft.mint(user, "https://example.com/token/1");
        
        assertEq(nft.tokenURI(0), "https://example.com/token/1");
    }
}