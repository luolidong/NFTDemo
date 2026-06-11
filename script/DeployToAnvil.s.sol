// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DigitalAvatar.sol";
import "../src/MarketToken.sol";
import "../src/NFTMarket.sol";

contract DeployToAnvil is Script {
    function run() public {
        // 使用 Anvil 默认账户（私钥来自 Anvil 测试节点）
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
        token.mint(msg.sender, 10000 * 10**18);
        console.log("Minted 10000 MTK to deployer");

        // 铸造一个测试 NFT
        nft.safeMint(msg.sender, "ipfs://test-metadata");
        console.log("Minted test NFT to deployer");

        vm.stopBroadcast();
    }
}