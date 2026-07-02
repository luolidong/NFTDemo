// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./NFTMarket.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract NFTMarket_V2 is NFTMarket {
    mapping(address => uint256) public nonces;

    bytes32 public constant PERMIT_LIST_TYPEHASH = keccak256(
        "PermitList(uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)"
    );

    bytes32 public constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    string public constant DOMAIN_NAME = "NFTMarket_V2";
    string public constant DOMAIN_VERSION = "1";

    function permitList(
        address seller,
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(price > 0, "Price must be greater than 0");
        require(block.timestamp <= deadline, "Signature expired");
        
        uint256 currentNonce = nonces[seller];
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_LIST_TYPEHASH,
                tokenId,
                price,
                currentNonce,
                deadline
            )
        );
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes(DOMAIN_VERSION)),
                block.chainid,
                address(this)
            )
        );
        bytes32 hash = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
        
        address recoveredAddress = ECDSA.recover(hash, v, r, s);
        require(recoveredAddress == seller, "Invalid signature");
        
        nonces[seller]++;
        
        require(nftContract.ownerOf(tokenId) == seller, "You don't own this NFT");
        require(nftContract.isApprovedForAll(seller, address(this)), "Market not approved for all");
        
        listings[tokenId] = Listing({
            seller: seller,
            price: price,
            listed: true
        });

        emit NFTListed(seller, tokenId, price);
    }

    function _authorizeUpgrade(address newImplementation) internal view override(NFTMarket) onlyOwner {}
}