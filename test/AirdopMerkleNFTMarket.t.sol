// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/foundry-upgrades/Upgrades.sol";
import "../src/DigitalAvatar.sol";
import "../src/MyPermitToken.sol";
import "../src/AirdopMerkleNFTMarket.sol";

contract AirdopMerkleNFTMarketTest is Test {
    DigitalAvatar public nft;
    MyPermitToken public token;
    AirdopMerkleNFTMarket public market;

    address[8] public whitelistAddresses;
    uint256[8] public privateKeys;
    uint256 public price = 100 * 10**18;
    uint256 public discountedPrice = 50 * 10**18;

    bytes32 public merkleRoot;

    function setUp() public {
        for (uint256 i = 0; i < 8; i++) {
            privateKeys[i] = 0x1000000000000000000000000000000000000000000000000000000000000001 + i;
            whitelistAddresses[i] = vm.addr(privateKeys[i]);
        }

        nft = new DigitalAvatar();
        token = new MyPermitToken();
        
        address proxy = Upgrades.deployUUPSProxy(
            "AirdopMerkleNFTMarket.sol:AirdopMerkleNFTMarket",
            abi.encodeCall(AirdopMerkleNFTMarket.initialize, (address(nft), address(token)))
        );
        market = AirdopMerkleNFTMarket(proxy);

        nft.safeMint(address(0x1), "ipfs://test");

        for (uint256 i = 0; i < 8; i++) {
            token.transfer(whitelistAddresses[i], 1000 * 10**18);
        }

        vm.prank(address(0x1));
        nft.setApprovalForAll(address(market), true);

        bytes32[] memory leaves = new bytes32[](8);
        for (uint256 i = 0; i < 8; i++) {
            leaves[i] = keccak256(abi.encodePacked(whitelistAddresses[i]));
        }
        merkleRoot = getMerkleRoot(leaves);
        market.setMerkleRoot(merkleRoot);

        vm.prank(address(0x1));
        market.list(0, price);
    }

    function getMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        if (leaves.length == 0) return bytes32(0);
        if (leaves.length == 1) return leaves[0];
        
        bytes32[] memory nodes = leaves;
        while (nodes.length > 1) {
            uint256 len = nodes.length;
            uint256 newLen = (len + 1) / 2;
            bytes32[] memory newNodes = new bytes32[](newLen);
            
            for (uint256 i = 0; i < len; i += 2) {
                bytes32 left = nodes[i];
                bytes32 right = (i + 1 < len) ? nodes[i + 1] : nodes[i];
                if (left > right) (left, right) = (right, left);
                newNodes[i / 2] = keccak256(abi.encode(left, right));
            }
            
            nodes = newNodes;
        }
        
        return nodes[0];
    }

    function getProof(bytes32[] memory leaves, uint256 index) internal pure returns (bytes32[] memory) {
        if (leaves.length == 1) return new bytes32[](0);
        
        bytes32[] memory nodes = leaves;
        bytes32[] memory proof;
        uint256 proofIdx = 0;
        
        while (nodes.length > 1) {
            uint256 len = nodes.length;
            uint256 newLen = (len + 1) / 2;
            bytes32[] memory newNodes = new bytes32[](newLen);
            
            for (uint256 i = 0; i < len; i += 2) {
                bytes32 left = nodes[i];
                bytes32 right = (i + 1 < len) ? nodes[i + 1] : nodes[i];
                
                bytes32 originalLeft = left;
                bytes32 originalRight = right;
                
                if (left > right) (left, right) = (right, left);
                newNodes[i / 2] = keccak256(abi.encode(left, right));
                
                if (i <= index && index < i + 2) {
                    bytes32 sibling = (index == i) ? originalRight : originalLeft;
                    proof = append(proof, sibling, proofIdx++);
                }
            }
            
            nodes = newNodes;
            index = index / 2;
        }
        
        return proof;
    }

    function append(bytes32[] memory arr, bytes32 value, uint256 idx) internal pure returns (bytes32[] memory) {
        bytes32[] memory newArr = new bytes32[](idx + 1);
        for (uint256 i = 0; i < idx; i++) {
            newArr[i] = arr[i];
        }
        newArr[idx] = value;
        return newArr;
    }

    function testIsWhitelisted() public {
        bytes32[] memory leaves = new bytes32[](8);
        for (uint256 i = 0; i < 8; i++) {
            leaves[i] = keccak256(abi.encodePacked(whitelistAddresses[i]));
        }

        for (uint256 i = 0; i < 8; i++) {
            bytes32[] memory proof = getProof(leaves, i);
            assertTrue(market.isWhitelisted(whitelistAddresses[i], proof));
        }

        assertFalse(market.isWhitelisted(address(0x99), new bytes32[](0)));
    }

    function testClaimNFTWithMulticall() public {
        bytes32[] memory leaves = new bytes32[](8);
        for (uint256 i = 0; i < 8; i++) {
            leaves[i] = keccak256(abi.encodePacked(whitelistAddresses[i]));
        }
        bytes32[] memory proof = getProof(leaves, 0);

        (bytes memory permitCall, bytes memory claimCall) = buildCalls(0, proof, discountedPrice);

        bytes[] memory calls = new bytes[](2);
        calls[0] = permitCall;
        calls[1] = claimCall;

        vm.prank(whitelistAddresses[0]);
        market.multicall(calls);

        assertEq(nft.ownerOf(0), whitelistAddresses[0]);
        assertEq(token.balanceOf(address(0x1)), discountedPrice);
        assertEq(token.balanceOf(whitelistAddresses[0]), 1000 * 10**18 - discountedPrice);
        assertTrue(market.claimed(whitelistAddresses[0]));
    }

    function buildCalls(
        uint256 index,
        bytes32[] memory proof,
        uint256 value
    ) internal view returns (bytes memory, bytes memory) {
        address buyer = whitelistAddresses[index];
        uint256 pk = privateKeys[index];
        uint256 deadline = block.timestamp + 3600;
        
        bytes32 permitHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            buyer, address(market), value, token.nonces(buyer), deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), permitHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);

        bytes memory permitCall = abi.encodeWithSelector(
            AirdopMerkleNFTMarket.permitPrePay.selector, buyer, address(market), value, deadline, v, r, s
        );

        bytes memory claimCall = abi.encodeWithSelector(
            AirdopMerkleNFTMarket.claimNFT.selector, 0, proof, value
        );

        return (permitCall, claimCall);
    }

    function testCannotClaimIfNotWhitelisted() public {
        vm.prank(address(0x99));
        vm.expectRevert("Invalid Merkle proof");
        market.claimNFT(0, new bytes32[](0), discountedPrice);
    }

    function testCannotClaimTwice() public {
        bytes32[] memory leaves = new bytes32[](8);
        for (uint256 i = 0; i < 8; i++) {
            leaves[i] = keccak256(abi.encodePacked(whitelistAddresses[i]));
        }
        bytes32[] memory proof = getProof(leaves, 0);

        (bytes memory permitCall,) = buildCalls(0, proof, discountedPrice);

        vm.prank(whitelistAddresses[0]);
        (bool success,) = address(market).call(permitCall);
        require(success);

        vm.prank(whitelistAddresses[0]);
        market.claimNFT(0, proof, discountedPrice);

        vm.prank(whitelistAddresses[0]);
        vm.expectRevert("Already claimed");
        market.claimNFT(0, proof, discountedPrice);
    }

    function testClaimWithOverpayment() public {
        bytes32[] memory leaves = new bytes32[](8);
        for (uint256 i = 0; i < 8; i++) {
            leaves[i] = keccak256(abi.encodePacked(whitelistAddresses[i]));
        }
        bytes32[] memory proof = getProof(leaves, 1);

        uint256 overpayment = discountedPrice + 10 * 10**18;
        (bytes memory permitCall, bytes memory claimCall) = buildCalls(1, proof, overpayment);

        bytes[] memory calls = new bytes[](2);
        calls[0] = permitCall;
        calls[1] = claimCall;

        vm.prank(whitelistAddresses[1]);
        market.multicall(calls);

        assertEq(nft.ownerOf(0), whitelistAddresses[1]);
        assertEq(token.balanceOf(address(0x1)), discountedPrice);
        assertEq(token.balanceOf(whitelistAddresses[1]), 1000 * 10**18 - discountedPrice);
    }

    function testAllWhitelistAddressesCanClaim() public {
        bytes32[] memory leaves = new bytes32[](8);
        for (uint256 i = 0; i < 8; i++) {
            leaves[i] = keccak256(abi.encodePacked(whitelistAddresses[i]));
        }

        for (uint256 i = 0; i < 8; i++) {
            if (i > 0) {
                nft.safeMint(address(0x1), "ipfs://test");
                vm.prank(address(0x1));
                market.list(i, price);
            }

            bytes32[] memory proof = getProof(leaves, i);
            (bytes memory permitCall,) = buildCalls(i, proof, discountedPrice);
            
            vm.prank(whitelistAddresses[i]);
            (bool success,) = address(market).call(permitCall);
            require(success);

            vm.prank(whitelistAddresses[i]);
            market.claimNFT(i, proof, discountedPrice);

            assertEq(nft.ownerOf(i), whitelistAddresses[i]);
            assertTrue(market.claimed(whitelistAddresses[i]));
        }
    }
}