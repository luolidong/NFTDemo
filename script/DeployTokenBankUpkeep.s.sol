// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/MyPermitToken.sol";
import "../src/TokenBank.sol";
import "../src/TokenBankUpkeep.sol";

contract DeployTokenBankUpkeep is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        MyPermitToken myToken = new MyPermitToken();
        console.log("MyPermitToken deployed at:", address(myToken));

        address permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        TokenBank tokenBank = new TokenBank(address(myToken), permit2Address);
        console.log("TokenBank deployed at:", address(tokenBank));

        TokenBankUpkeep tokenBankUpkeep = new TokenBankUpkeep(address(tokenBank));
        console.log("TokenBankUpkeep deployed at:", address(tokenBankUpkeep));

        tokenBank.setCollector(address(tokenBankUpkeep));
        console.log("Set TokenBankUpkeep as collector of TokenBank");

        address testUser = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        uint256 transferAmount = 200 * 10**18;
        myToken.transfer(testUser, transferAmount);
        console.log("Transferred", transferAmount / 10**18, "MPT2 to test user:", testUser);

        vm.stopBroadcast();

        console.log("");
        console.log("========== Deployment Summary ==========");
        console.log("Network:", block.chainid == 11155111 ? "Sepolia" : "Unknown");
        console.log("");
        console.log("CONTRACTS:");
        console.log("- MyPermitToken:", address(myToken));
        console.log("- TokenBank:", address(tokenBank));
        console.log("- TokenBankUpkeep:", address(tokenBankUpkeep));
        console.log("");
        console.log("ACCOUNTS:");
        console.log("- Deployer:", vm.addr(deployerPrivateKey));
        console.log("- Test User:", testUser);
        console.log("========================================");
    }
}