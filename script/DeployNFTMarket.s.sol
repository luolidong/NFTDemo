// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DigitalAvatar.sol";
import "../src/MarketToken.sol";
import "../src/NFTMarket.sol";

contract DeployNFTMarket is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署 NFT 合约
        DigitalAvatar nft = new DigitalAvatar();
        console.log("DigitalAvatar deployed at:", address(nft));
        
        // 部署市场代币合约
        MarketToken token = new MarketToken();
        console.log("MarketToken deployed at:", address(token));
        
        // 部署 NFT 市场合约
        NFTMarket market = new NFTMarket(address(nft), address(token));
        console.log("NFTMarket deployed at:", address(market));
        
        // 铸造一些测试代币给部署者
        token.mint(msg.sender, 1000000 * 10**18);
        console.log("Minted 1,000,000 tokens to:", msg.sender);
        
        // 铸造一个测试 NFT 给部署者
        nft.safeMint(msg.sender, "ipfs://test");
        console.log("Minted test NFT to:", msg.sender);
        
        vm.stopBroadcast();
    }
}