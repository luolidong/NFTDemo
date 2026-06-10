// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DigitalAvatar.sol";

contract DeployDigitalAvatar is Script {
    function run() public {
        vm.startBroadcast();
        
        DigitalAvatar nft = new DigitalAvatar();
        
        console.log("DigitalAvatar deployed to:", address(nft));
        
        vm.stopBroadcast();
    }
}