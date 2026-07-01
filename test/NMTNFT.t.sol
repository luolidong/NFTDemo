// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "../src/NMTNFT.sol";

contract NMTNFTV2 is NMTNFT {
    function version() public pure returns (string memory) {
        return "v2";
    }
}

contract NMTNFTTest is Test {
    NMTNFT public nft;
    ERC1967Proxy public proxy;
    address public owner = address(0x1234);
    address public user = address(0x5678);
    address public other = address(0x9ABC);

    function setUp() public {
        NMTNFT implementation = new NMTNFT();

        vm.prank(owner);
        bytes memory initData = abi.encodeCall(NMTNFT.initialize, ());
        proxy = new ERC1967Proxy(address(implementation), initData);

        nft = NMTNFT(address(proxy));
    }

    function testName() public view {
        assertEq(nft.name(), "NMTNFT");
    }

    function testSymbol() public view {
        assertEq(nft.symbol(), "NMT");
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
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        nft.mint(user, "ipfs://Qm...");
    }

    function testTokenURI() public {
        vm.prank(owner);
        nft.mint(user, "https://example.com/token/1");

        assertEq(nft.tokenURI(0), "https://example.com/token/1");
    }

    function testSupportsInterface() public view {
        assert(nft.supportsInterface(type(IERC721).interfaceId));
        assert(nft.supportsInterface(type(IERC721Metadata).interfaceId));
    }

    function testOwner() public view {
        assertEq(nft.owner(), owner);
    }

    function testTransferOwnership() public {
        vm.prank(owner);
        nft.transferOwnership(other);

        assertEq(nft.owner(), other);
    }

    function testCannotTransferOwnershipByNonOwner() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        nft.transferOwnership(other);
    }

    function testMultipleMints() public {
        vm.startPrank(owner);
        nft.mint(user, "ipfs://token/1");
        nft.mint(user, "ipfs://token/2");
        nft.mint(other, "ipfs://token/3");
        vm.stopPrank();

        assertEq(nft.balanceOf(user), 2);
        assertEq(nft.balanceOf(other), 1);
        assertEq(nft.ownerOf(0), user);
        assertEq(nft.ownerOf(1), user);
        assertEq(nft.ownerOf(2), other);
    }

    function testCannotReinitialize() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        nft.initialize();
    }

    function testUpgradeToV2() public {
        vm.prank(owner);
        nft.mint(user, "ipfs://token/1");

        NMTNFTV2 v2Implementation = new NMTNFTV2();

        vm.prank(owner);
        nft.upgradeToAndCall(address(v2Implementation), "");

        NMTNFTV2 v2 = NMTNFTV2(address(proxy));

        assertEq(v2.version(), "v2");
        assertEq(v2.balanceOf(user), 1);
        assertEq(v2.ownerOf(0), user);
    }

    function testOnlyOwnerCanUpgrade() public {
        NMTNFTV2 v2Implementation = new NMTNFTV2();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        nft.upgradeToAndCall(address(v2Implementation), "");
    }
}