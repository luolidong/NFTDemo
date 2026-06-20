// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/MyPermitToken.sol";  // 使用支持 EIP-2612 的代币
import "../src/TokenBank.sol";

contract DeployTokenBank is Script {
    function run() external {
        // 使用 Anvil 默认账户
        // Anvil 默认账户 0 私钥: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 MyPermitToken 合约（支持 EIP-2612）
        MyPermitToken myToken = new MyPermitToken();
        console.log("MyPermitToken deployed at:", address(myToken));
        console.log("MyPermitToken Name:", myToken.name());
        console.log("MyPermitToken Symbol:", myToken.symbol());
        console.log("MyPermitToken Total Supply:", myToken.totalSupply());

        // 2. 部署 TokenBank 合约（传入 MyToken 地址）
        TokenBank tokenBank = new TokenBank(address(myToken));
        console.log("TokenBank deployed at:", address(tokenBank));

        // 3. 将一些代币转给测试用户（方便测试）
        address testUser = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Anvil 账户 1
        uint256 transferAmount = 1000 * 10**18; // 1000 MTK
        
        myToken.transfer(testUser, transferAmount);
        console.log("Transferred", transferAmount / 10**18, "MTK to test user:", testUser);

        // 4. 铸造额外代币给部署者
        // 注意：MyToken 构造函数已经铸造了 totalSupply 给部署者
        // 这里可以添加额外的铸造功能如果需要的话

        vm.stopBroadcast();

        // 打印部署摘要
        console.log("");
        console.log("========== Deployment Summary ==========");
        console.log("Network: Anvil (Local)");
        console.log("RPC URL: http://localhost:8545");
        console.log("");
        console.log("CONTRACTS:");
        console.log("- MyToken:", address(myToken));
        console.log("- TokenBank:", address(tokenBank));
        console.log("");
        console.log("ACCOUNTS:");
        console.log("- Deployer:", 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        console.log("- Test User:", testUser);
        console.log("========================================");
    }
}
