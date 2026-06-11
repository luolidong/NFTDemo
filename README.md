# NFT Market Project

一个基于 OpenZeppelin 的完整 NFT 市场项目，支持 ERC721 NFT 的创建、上架、购买和交易，使用 ERC1363 扩展代币实现一键购买功能。

## 项目功能

- ✅ **ERC721 NFT 创建** - 铸造数字头像 NFT
- ✅ **NFT 上架** - 持有者可设置价格上架 NFT
- ✅ **NFT 购买** - 支持直接购买和 ERC1363 一键购买
- ✅ **ERC1363 扩展代币** - 支持转账回调的市场代币
- ✅ **退款机制** - 超额支付自动退还
- ✅ **完整测试** - 覆盖所有核心功能

## 项目结构

```
NFTDemo/
├── src/
│   ├── DigitalAvatar.sol    # ERC721 NFT 合约
│   ├── MarketToken.sol      # ERC1363 市场代币合约
│   └── NFTMarket.sol        # NFT 市场合约
├── test/
│   ├── DigitalAvatar.t.sol  # NFT 合约测试
│   └── NFTMarket.t.sol      # NFT 市场测试
├── script/
│   ├── DeployDigitalAvatar.s.sol   # 部署 NFT 合约
│   ├── MintDigitalAvatar.s.sol     # 铸造 NFT
│   └── DeployNFTMarket.s.sol       # 部署完整市场
├── metadata/
│   ├── avatar.jpg          # NFT 图片资源
│   └── metadata.json       # NFT 元数据
└── lib/
    ├── forge-std/          # Foundry 标准库
    └── openzeppelin-contracts/  # OpenZeppelin 合约库
```

## 合约说明

### 1. DigitalAvatar (ERC721)

标准 ERC721 NFT 合约，支持安全铸造和元数据管理。

```solidity
function safeMint(address to, string memory uri) public onlyOwner
function mint(address to, string memory uri) public onlyOwner
function tokenURI(uint256 tokenId) public view returns (string memory)
```

### 2. MarketToken (ERC20 + ERC1363)

扩展的市场代币，支持转账回调功能：

| 方法 | 说明 |
|------|------|
| `transferAndCall()` | 转账后触发接收者回调 |
| `transferFromAndCall()` | 授权转账后触发回调 |
| `mint()` | 铸造代币（仅拥有者） |
| `burn()` | 销毁代币（仅拥有者） |

### 3. NFTMarket (IERC1363Receiver)

NFT 市场合约，实现 ERC1363 接收者接口：

| 方法 | 说明 |
|------|------|
| `list(tokenId, price)` | 上架 NFT |
| `delist(tokenId)` | 下架 NFT |
| `buyNFT(tokenId, amount)` | 直接购买 NFT |
| `onTransferReceived()` | ERC1363 回调购买 |

## 前置准备

### 1. 安装 Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. 安装依赖

```bash
forge install openzeppelin/openzeppelin-contracts
```

### 3. 创建钱包（安全方式）

```bash
# 创建 keystore 目录
mkdir -p ~/.foundry/keystores

# 创建新钱包（会提示设置密码）
cast wallet new ~/.foundry/keystores my-sepolia-wallet.json

# 查看钱包地址
cast wallet address --keystore ~/.foundry/keystores/my-sepolia-wallet.json
```

### 4. 获取 Sepolia 测试币

访问以下水龙头领取测试 ETH：
- https://sepoliafaucet.com/
- https://faucet.sepolia.dev/
- https://cloud.google.com/application/web3/faucet/ethereum/sepolia

## 修改 Metadata

### 1. 上传图片到 IPFS

使用 Pinata 或其他 IPFS 服务上传 `metadata/avatar.jpg`：

```bash
# 使用 ipfs 命令行上传
ipfs add metadata/avatar.jpg
# 输出示例：QmYourImageHash avatar.jpg
```

### 2. 更新 metadata.json

编辑 `metadata/metadata.json`，替换图片的 IPFS 哈希：

```json
{
  "name": "DigitalAvatar #1",
  "description": "A unique digital avatar NFT representing personal identity on the blockchain",
  "image": "ipfs://QmYourImageHash/avatar.jpg",
  "attributes": [
    {
      "trait_type": "Type",
      "value": "Avatar"
    },
    {
      "trait_type": "Edition",
      "value": "1 of 1"
    },
    {
      "trait_type": "Format",
      "value": "JPEG"
    }
  ]
}
```

### 3. 上传 metadata.json 到 IPFS

```bash
ipfs add metadata/metadata.json
# 输出示例：QmYourMetadataHash metadata.json
```

## 编译与测试

```bash
# 编译合约
forge build

# 运行测试
forge test -v

# 运行特定测试
forge test -v --match-test testBuyNFT
```

## 部署到 Sepolia 测试网

### 方式一：部署完整市场

```bash
forge script script/DeployNFTMarket.s.sol:DeployNFTMarket \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --broadcast \
  --keystore ~/.foundry/keystores/my-sepolia-wallet.json \
  -vvv
```

部署后会输出三个合约地址：
- DigitalAvatar 地址
- MarketToken 地址  
- NFTMarket 地址

### 方式二：分步部署

#### 步骤 1：部署 NFT 合约

```bash
forge script script/DeployDigitalAvatar.s.sol:DeployDigitalAvatar \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --broadcast \
  --keystore ~/.foundry/keystores/my-sepolia-wallet.json \
  -vvv
```

#### 步骤 2：部署市场代币

```bash
# 复制以下代码创建部署脚本
cat > script/DeployMarketToken.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/MarketToken.sol";

contract DeployMarketToken is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        MarketToken token = new MarketToken();
        console.log("MarketToken deployed at:", address(token));
        vm.stopBroadcast();
    }
}
EOF

# 部署
forge script script/DeployMarketToken.s.sol:DeployMarketToken \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --broadcast \
  --keystore ~/.foundry/keystores/my-sepolia-wallet.json \
  -vvv
```

#### 步骤 3：部署 NFT 市场

```bash
# 设置环境变量
export NFT_ADDRESS="0xYourNFTContractAddress"
export TOKEN_ADDRESS="0xYourMarketTokenAddress"

# 创建部署脚本
cat > script/DeployNFTMarketManual.s.sol << EOF
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/NFTMarket.sol";

contract DeployNFTMarketManual is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        NFTMarket market = new NFTMarket($NFT_ADDRESS, $TOKEN_ADDRESS);
        console.log("NFTMarket deployed at:", address(market));
        vm.stopBroadcast();
    }
}
EOF

# 部署
forge script script/DeployNFTMarketManual.s.sol:DeployNFTMarketManual \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --broadcast \
  --keystore ~/.foundry/keystores/my-sepolia-wallet.json \
  -vvv
```

### 步骤 4：铸造测试代币

```bash
# 铸造代币给测试账户
cast send $TOKEN_ADDRESS \
  "mint(address,uint256)" \
  "$(cast wallet address --keystore ~/.foundry/keystores/my-sepolia-wallet.json)" \
  "1000000000000000000000" \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --keystore ~/.foundry/keystores/my-sepolia-wallet.json
```

## 使用 NFT 市场

### 1. 上架 NFT

```bash
# 需要先授权市场合约转移 NFT
cast send $NFT_ADDRESS \
  "setApprovalForAll(address,bool)" \
  $MARKET_ADDRESS \
  true \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --keystore ~/.foundry/keystores/my-sepolia-wallet.json

# 上架 NFT（价格 100 MTK）
cast send $MARKET_ADDRESS \
  "list(uint256,uint256)" \
  0 \
  100000000000000000000 \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --keystore ~/.foundry/keystores/my-sepolia-wallet.json
```

### 2. 购买 NFT（方法一：直接调用）

```bash
# 授权市场合约花费代币
cast send $TOKEN_ADDRESS \
  "approve(address,uint256)" \
  $MARKET_ADDRESS \
  100000000000000000000 \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --keystore ~/.foundry/keystores/my-sepolia-wallet.json

# 购买 NFT
cast send $MARKET_ADDRESS \
  "buyNFT(uint256,uint256)" \
  0 \
  100000000000000000000 \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --keystore ~/.foundry/keystores/my-sepolia-wallet.json
```

### 3. 购买 NFT（方法二：ERC1363 一键购买）

```bash
# 一步完成：转账代币 + 自动购买 NFT
# data = abi.encode(tokenId)
cast send $TOKEN_ADDRESS \
  "transferAndCall(address,uint256,bytes)" \
  $MARKET_ADDRESS \
  100000000000000000000 \
  "0x0000000000000000000000000000000000000000000000000000000000000000" \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --keystore ~/.foundry/keystores/my-sepolia-wallet.json
```

### 4. 下架 NFT

```bash
cast send $MARKET_ADDRESS \
  "delist(uint256)" \
  0 \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --keystore ~/.foundry/keystores/my-sepolia-wallet.json
```

## 验证部署

### 在 Etherscan 上查看

访问 Sepolia 区块浏览器：
- https://sepolia.etherscan.io/address/your-contract-address

### 验证合约代码

```bash
forge verify-contract \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --etherscan-api-key YOUR_ETHERSCAN_API_KEY \
  $CONTRACT_ADDRESS \
  src/NFTMarket.sol:NFTMarket
```

### 在 MetaMask 中查看 NFT

1. 打开 MetaMask → 切换到 Sepolia 测试网
2. 点击 "添加资产" → "添加 NFT"
3. 输入合约地址和 Token ID

## 检查合约状态

```bash
# 检查 NFT 上架信息
cast call $MARKET_ADDRESS "getListing(uint256)(address,uint256,bool)" 0 \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo

# 检查代币余额
cast call $TOKEN_ADDRESS "balanceOf(address)(uint256)" \
  $(cast wallet address --keystore ~/.foundry/keystores/my-sepolia-wallet.json) \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo

# 检查 NFT 所有者
cast call $NFT_ADDRESS "ownerOf(uint256)(address)" 0 \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo
```

## 后端事件监听服务

使用 Viem.sh 监听 NFTMarket 的上架、买卖和下架事件。

### 安装依赖

```bash
cd backend
npm install
```

### 启动步骤

#### 步骤 1：启动 Anvil 本地节点

```bash
# 在终端1中启动 Anvil
anvil
```

Anvil 启动后会显示默认账户信息，包括私钥和地址。

#### 步骤 2：部署合约到 Anvil

```bash
# 设置 Anvil 默认私钥（第一个账户）
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff948b4df6117301330871fc23bc35948d

# 部署合约
forge script script/DeployToAnvil.s.sol:DeployToAnvil \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  -vvv
```

部署成功后会输出三个合约地址，复制 NFTMarket 地址。

#### 步骤 3：更新环境变量

编辑 `backend/.env` 文件，更新 NFTMarket 合约地址：

```bash
NFT_MARKET_ADDRESS=0xYourNFTMarketAddress
```

#### 步骤 4：启动事件监听器

```bash
cd backend
npm start
```

### 测试事件监听

在另一个终端中执行以下命令测试事件：

```bash
# 设置环境变量
export NFT_ADDRESS="0xYourNFTAddress"
export TOKEN_ADDRESS="0xYourTokenAddress"
export MARKET_ADDRESS="0xYourMarketAddress"
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff948b4df6117301330871fc23bc35948d

# 授权市场合约转移 NFT
cast send $NFT_ADDRESS \
  "setApprovalForAll(address,bool)" \
  $MARKET_ADDRESS \
  true \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $PRIVATE_KEY

# 上架 NFT（价格 100 MTK）
cast send $MARKET_ADDRESS \
  "list(uint256,uint256)" \
  0 \
  100000000000000000000 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $PRIVATE_KEY

# 授权市场合约花费代币
cast send $TOKEN_ADDRESS \
  "approve(address,uint256)" \
  $MARKET_ADDRESS \
  100000000000000000000 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $PRIVATE_KEY

# 购买 NFT
cast send $MARKET_ADDRESS \
  "buyNFT(uint256,uint256)" \
  0 \
  100000000000000000000 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $PRIVATE_KEY
```

### 监听日志示例

```
==============================================
      NFT Market Event Listener
==============================================
📡 连接到: http://127.0.0.1:8545
📄 监听合约: 0x5FbDB2315678afecb367f032d93F642f64180aa3
==============================================
✅ 已连接到链 ID: 31337

🔔 开始监听 NFT 上架事件...

🔔 开始监听 NFT 买卖事件...

🔔 开始监听 NFT 下架事件...

🚀 所有监听器已启动，等待事件...
按 Ctrl+C 停止监听

═══════════════════════════════════════════════════
📅 2024/1/15 14:30:00
📦 [上架事件] NFT Listed
├─ 区块号: 123
├─ 交易哈希: 0xabc123...
├─ 卖家: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
├─ Token ID: 0
└─ 价格: 100.0 MTK
═══════════════════════════════════════════════════

═══════════════════════════════════════════════════
📅 2024/1/15 14:30:10
💰 [买卖事件] NFT Sold
├─ 区块号: 124
├─ 交易哈希: 0xdef456...
├─ 卖家: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
├─ 买家: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
├─ Token ID: 0
└─ 成交价格: 100.0 MTK
═══════════════════════════════════════════════════
```

### 后端项目结构

```
backend/
├── index.js          # 事件监听器主文件
├── package.json      # 项目依赖配置
└── .env              # 环境变量配置
```

## 安全最佳实践

1. **永远不要**在命令行直接输入私钥
2. **使用 keystore 文件**进行部署，避免私钥泄露
3. **备份钱包**：定期导出并安全保存助记词
4. **测试网验证**：在主网部署前，先在测试网验证功能
5. **使用环境变量**：敏感信息使用环境变量而非硬编码
6. **权限控制**：仅授权必要的合约访问权限

## 许可证

MIT License