// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "./NFTMarket.sol";

contract AirdopMerkleNFTMarket is MulticallUpgradeable, NFTMarket {
    bytes32 public merkleRoot;
    mapping(address => bool) public claimed;

    event Claimed(address indexed claimer, uint256 indexed tokenId);
    event MerkleRootUpdated(bytes32 indexed newRoot);

    function initialize(address _nftContract, address _marketToken) public override initializer {
        NFTMarket.initialize(_nftContract, _marketToken);
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(address(marketToken)).permit(owner, spender, value, deadline, v, r, s);
    }

    function claimNFT(
        uint256 tokenId,
        bytes32[] calldata proof,
        uint256 amount
    ) external {
        require(!claimed[msg.sender], "Already claimed");
        
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid Merkle proof");

        Listing storage listing = listings[tokenId];
        require(listing.listed, "NFT not listed");
        require(nftContract.ownerOf(tokenId) == listing.seller, "NFT owner changed");

        uint256 discountedPrice = listing.price / 2;
        require(amount >= discountedPrice, "Insufficient payment");

        marketToken.transferFrom(msg.sender, listing.seller, discountedPrice);

        if (amount > discountedPrice) {
            marketToken.transferFrom(msg.sender, msg.sender, amount - discountedPrice);
        }

        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);

        listings[tokenId].listed = false;
        claimed[msg.sender] = true;

        emit NFTSold(listing.seller, msg.sender, tokenId, discountedPrice);
        emit Claimed(msg.sender, tokenId);
    }

    function isWhitelisted(address account, bytes32[] calldata proof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    function _authorizeUpgrade(address newImplementation) internal view override(NFTMarket) onlyOwner {}
}