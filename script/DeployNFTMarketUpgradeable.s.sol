// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/foundry-upgrades/Upgrades.sol";
import "../src/NFTMarket.sol";

contract DeployNFTMarketUpgradeable is Script {
    function run(
        address _nftContract,
        address _marketToken
    ) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address proxy = Upgrades.deployUUPSProxy(
            "NFTMarket.sol:NFTMarket",
            abi.encodeCall(NFTMarket.initialize, (_nftContract, _marketToken))
        );

        console.log("NFTMarket Proxy deployed at:", proxy);
        console.log("NFTMarket Implementation at:", Upgrades.getImplementationAddress(proxy));
        console.log("Using NMTNFT address:", _nftContract);
        console.log("Using MyPermitToken address:", _marketToken);

        vm.stopBroadcast();
    }
}