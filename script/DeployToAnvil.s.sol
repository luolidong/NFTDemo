// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/foundry-upgrades/Upgrades.sol";
import "../src/DigitalAvatar.sol";
import "../src/MarketToken.sol";
import "../src/NFTMarket.sol";

contract DeployToAnvil is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        DigitalAvatar nft = new DigitalAvatar();
        console.log("DigitalAvatar deployed at:", address(nft));

        MarketToken token = new MarketToken();
        console.log("MarketToken deployed at:", address(token));

        address proxy = Upgrades.deployUUPSProxy(
            "NFTMarket.sol:NFTMarket",
            abi.encodeCall(NFTMarket.initialize, (address(nft), address(token)))
        );
        console.log("NFTMarket Proxy deployed at:", proxy);
        console.log("NFTMarket Implementation at:", Upgrades.getImplementationAddress(proxy));

        token.mint(msg.sender, 10000 * 10**18);
        console.log("Minted 10000 MTK to deployer");

        nft.safeMint(msg.sender, "ipfs://test-metadata");
        console.log("Minted test NFT to deployer");

        vm.stopBroadcast();
    }
}