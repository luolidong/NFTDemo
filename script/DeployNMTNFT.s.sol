// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/NMTNFT.sol";

contract DeployNMTNFT is Script {
    function run() public {
        vm.startBroadcast();

        NMTNFT implementation = new NMTNFT();

        bytes memory initData = abi.encodeCall(NMTNFT.initialize, ());
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        console.log("NMTNFT Implementation deployed to:", address(implementation));
        console.log("NMTNFT Proxy deployed to:", address(proxy));

        vm.stopBroadcast();
    }
}