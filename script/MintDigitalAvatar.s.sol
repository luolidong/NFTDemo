// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DigitalAvatar.sol";

contract MintDigitalAvatar is Script {
    function run() public {
        // 部署后替换为实际的合约地址
        address nftAddress = 0xREPLACE_WITH_YOUR_CONTRACT_ADDRESS;
        DigitalAvatar nft = DigitalAvatar(nftAddress);
        
        vm.startBroadcast();
        
        // 替换为你上传到 IPFS 的 metadata.json 地址
        string memory tokenURI = "ipfs://REPLACE_WITH_YOUR_METADATA_IPFS_HASH/metadata.json";
        
        nft.safeMint(msg.sender, tokenURI);
        
        console.log("NFT minted successfully!");
        console.log("Token ID:", nft.balanceOf(msg.sender) - 1);
        console.log("Token URI:", tokenURI);
        
        vm.stopBroadcast();
    }
}