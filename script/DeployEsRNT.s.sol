// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/esRNT.sol";

contract DeployEsRNT is Script {
    function run() external {
        vm.startBroadcast();
        esRNT token = new esRNT();
        vm.stopBroadcast();
        console.log("esRNT deployed at:", address(token));
    }
}
