// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/foundry-upgrades/Upgrades.sol";
import "../src/NFTMarket_V2.sol";

contract UpgradeNFTMarketV2 is Script {
    function run(address proxy) public {
        vm.startBroadcast();
        
        Upgrades.upgradeProxy(proxy, "NFTMarket_V2.sol:NFTMarket_V2", "");
        
        console.log("Upgraded proxy to NFTMarket_V2:", proxy);
        
        vm.stopBroadcast();
    }
}