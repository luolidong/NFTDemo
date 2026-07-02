// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/foundry-upgrades/Upgrades.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/NFTMarket_V2.sol";
import "../src/MyPermitToken.sol";
import "../src/NMTNFT.sol";

contract NFTMarket_V2Test is Test {
    NFTMarket_V2 public market;
    MyPermitToken public token;
    NMTNFT public nft;
    uint256 public sellerPrivateKey = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    address public seller = vm.addr(sellerPrivateKey);
    address public buyer = address(0x5678);

    function setUp() public {
        token = new MyPermitToken();
        
        NMTNFT nftImpl = new NMTNFT();
        bytes memory nftInitData = abi.encodeCall(NMTNFT.initialize, ());
        address nftProxy = address(new ERC1967Proxy(address(nftImpl), nftInitData));
        nft = NMTNFT(nftProxy);
        
        NFTMarket_V2 impl = new NFTMarket_V2();
        bytes memory initData = abi.encodeCall(NFTMarket.initialize, (address(nft), address(token)));
        address proxy = address(new ERC1967Proxy(address(impl), initData));
        market = NFTMarket_V2(proxy);
        
        vm.deal(seller, 100 ether);
        nft.mint(seller, "https://example.com/1");
        
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);
    }

    function getDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("NFTMarket_V2")),
                keccak256(bytes("1")),
                block.chainid,
                address(market)
            )
        );
    }

    function testPermitList() public {
        uint256 tokenId = 0;
        uint256 price = 100 * 10**18;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = market.nonces(seller);
        
        bytes32 domainSeparator = getDomainSeparator();
        bytes32 typeHash = market.PERMIT_LIST_TYPEHASH();
        
        bytes32 structHash = keccak256(
            abi.encode(
                typeHash,
                tokenId,
                price,
                nonce,
                deadline
            )
        );
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, hash);
        
        vm.prank(buyer);
        market.permitList(seller, tokenId, price, deadline, v, r, s);
        
        (address listingSeller, uint256 listingPrice, bool listed) = market.getListing(tokenId);
        assertEq(listingSeller, seller);
        assertEq(listingPrice, price);
        assertTrue(listed);
        assertEq(market.nonces(seller), nonce + 1);
    }

    function testPermitListExpiredSignature() public {
        uint256 tokenId = 0;
        uint256 price = 100 * 10**18;
        uint256 deadline = block.timestamp - 1;
        uint256 nonce = market.nonces(seller);
        
        bytes32 domainSeparator = getDomainSeparator();
        bytes32 typeHash = market.PERMIT_LIST_TYPEHASH();
        
        bytes32 structHash = keccak256(
            abi.encode(
                typeHash,
                tokenId,
                price,
                nonce,
                deadline
            )
        );
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, hash);
        
        vm.prank(buyer);
        vm.expectRevert("Signature expired");
        market.permitList(seller, tokenId, price, deadline, v, r, s);
    }

    function testPermitListInvalidSignature() public {
        uint256 tokenId = 0;
        uint256 price = 100 * 10**18;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = market.nonces(seller);
        
        bytes32 domainSeparator = getDomainSeparator();
        bytes32 typeHash = market.PERMIT_LIST_TYPEHASH();
        
        bytes32 structHash = keccak256(
            abi.encode(
                typeHash,
                tokenId,
                price,
                nonce,
                deadline
            )
        );
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        uint256 wrongKey = 0xdeadbeef;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, hash);
        
        vm.prank(buyer);
        vm.expectRevert("Invalid signature");
        market.permitList(seller, tokenId, price, deadline, v, r, s);
    }

    function testPermitListNotApprovedForAll() public {
        vm.prank(seller);
        nft.setApprovalForAll(address(market), false);
        
        uint256 tokenId = 0;
        uint256 price = 100 * 10**18;
        uint256 deadline = block.timestamp + 1 days;
        uint256 nonce = market.nonces(seller);
        
        bytes32 domainSeparator = getDomainSeparator();
        bytes32 typeHash = market.PERMIT_LIST_TYPEHASH();
        
        bytes32 structHash = keccak256(
            abi.encode(
                typeHash,
                tokenId,
                price,
                nonce,
                deadline
            )
        );
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, hash);
        
        vm.prank(buyer);
        vm.expectRevert("Market not approved for all");
        market.permitList(seller, tokenId, price, deadline, v, r, s);
    }
}