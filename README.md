# NFT Market Project

一个基于 OpenZeppelin 的完整 NFT 市场项目，支持 ERC721 NFT 的创建、上架、购买和交易，使用 ERC1363 扩展代币实现一键购买功能。

## 项目功能

- ✅ **ERC721 NFT 创建** - 铸造数字头像 NFT
- ✅ **NFT 上架** - 持有者可设置价格上架 NFT
- ✅ **NFT 购买** - 支持直接购买和 ERC1363 一键购买
- ✅ **ERC1363 扩展代币** - 支持转账回调的市场代币
- ✅ **退款机制** - 超额支付自动退还
- ✅ **完整测试** - 覆盖所有核心功能

---

## TokenBank DApp

一个带有转账记录索引和 SIWE 登录的 TokenBank 去中心化应用。

### 功能特性

- ✅ **TokenBank 存提款** - 存款和取款 MyToken
- ✅ **Permit Deposit** - EIP-2612 无需 approve 的存款功能
- ✅ **转账记录索引** - 自动索引所有 MyToken 转账事件
- ✅ **SIWE 登录** - Sign-In with Ethereum 身份验证
- ✅ **转账历史查询** - 查看发送/接收的转账记录
- ✅ **实时监听** - 实时捕获新区块转账事件

### 项目结构

```
NFTDemo/
├── backend/                          # 后端服务
│   ├── server.js                     # 主服务器（索引 + API + 监听）
│   ├── database.js                   # 数据库初始化
│   ├── abis/
│   │   └── MyToken.json              # MyToken ABI
│   └── config/
│       └── index.js                  # 配置文件
├── tokenbank-frontend/               # 前端应用
│   ├── src/
│   │   ├── App.jsx                   # 主应用组件
│   │   ├── config/
│   │   │   ├── index.js              # 前端配置
│   │   │   └── wagmi.js             # Wagmi 配置
│   │   ├── components/
│   │   │   ├── SiweLogin.jsx         # SIWE 登录组件
│   │   │   └── TransferList.jsx     # 转账记录组件
│   │   └── api/
│   │       └── index.js              # API 调用
│   └── index.html
└── ...
```

### 技术栈

- **后端**: Express.js, sql.js, viem, siwe
- **前端**: React, wagmi, AppKit, ethers.js
- **区块链**: Anvil (本地开发), viem
- **数据库**: SQLite (sql.js)

---

## 快速开始

### 1. 启动 Anvil

```bash
anvil --port 8545
```

### 2. 部署合约

```bash
forge script script/DeployTokenBank.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

部署后会输出 MyToken 和 TokenBank 地址。

### 3. 配置后端

编辑 `backend/config/index.js`，更新 `myTokenAddress`：

```javascript
myTokenAddress: '0xYourMyTokenAddress',
```

### 4. 启动后端

```bash
cd backend
pnpm install
pnpm run dev
```

后端会自动：
- ✅ 初始化 SQLite 数据库
- ✅ 索引历史转账事件
- ✅ 启动实时区块监听
- ✅ 启动 API 服务器 (端口 3001)

### 5. 启动前端

```bash
cd tokenbank-frontend
pnpm install
pnpm run dev
```

访问 http://localhost:5173

### 6. MetaMask 配置

添加 Anvil 本地网络：
- **Network Name**: Anvil Local
- **RPC URL**: http://127.0.0.1:8545
- **Chain ID**: 31337
- **Currency Symbol**: ETH

导入测试账户：
```
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

### 7. 测试操作

#### SIWE 登录
1. 点击 "MetaMask" 连接钱包
2. 点击 "Sign In with Ethereum" 签名登录

#### 查看转账记录
1. 登录后点击 "Transfer History"
2. 点击 "Refresh" 刷新数据

#### 执行转账测试

```bash
# 转账 100 MTK
cast send 0xYourMyTokenAddress \
  "transfer(address,uint256)" \
  0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  100000000000000000000 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

刷新前端即可看到新转账记录。

#### Permit Deposit (EIP-2612)

Permit Deposit 是一种无需预先 approve 的存款方式，使用 EIP-2612 签名授权：

1. **前端操作**：
   - 输入存款金额
   - 点击 "Permit Deposit"
   - MetaMask 会弹出两次确认：
     - 第一次：EIP-712 签名（授权）
     - 第二次：交易确认（存款）

2. **命令行测试**：

```bash
# 获取 nonce
cast call 0xYourMyTokenAddress "nonces(address)(uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://127.0.0.1:8545

# 签名 permit (需要使用 ethers.js 或其他库)
# 前端会自动处理签名流程

# 或者直接测试 permitDeposit
# 前端已实现完整的 EIP-712 签名流程
```

**技术实现**：
- 使用 wagmi `walletClient.signTypedData()` 进行 EIP-712 签名
- 使用 `walletClient.sendTransaction()` 发送交易
- 使用 ethers.js `Interface` 编码函数调用数据

---

## API 接口

### 认证相关

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/nonce` | GET | 获取 nonce |
| `/api/verify` | POST | 验证 SIWE 签名 |
| `/api/me` | GET | 获取当前用户 |
| `/api/logout` | POST | 登出 |

### 转账记录

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/transfers/:address` | GET | 获取地址的转账记录 |
| `/api/transfers/:address/stats` | GET | 获取转账统计 |

查询参数：
- `type`: `all` \| `sent` \| `received`
- `page`: 页码
- `limit`: 每页数量

---

## 问题与解决方案

### 1. BigInt 序列化错误

**问题**：
```
TypeError: Do not know how to serialize a BigInt
```

**解决**：使用 `Number()` 或 `.toString()` 转换 BigInt 值。

```javascript
// 错误
JSON.stringify(block)

// 正确
Number(block.number)
```

### 2. 区块链 RPC 参数类型错误

**问题**：
```
invalid type: number, expected a string
```

**解决**：viem 要求 `fromBlock` 和 `toBlock` 必须是 BigInt 类型。

```javascript
// 错误
fromBlock: 0

// 正确
fromBlock: BigInt(0)
```

### 3. Session nonce 未保存

**问题**：验证时 nonce 为 undefined，导致 "Invalid nonce" 错误。

**解决**：显式调用 `req.session.save()` 确保 session 保存到存储。

```javascript
req.session.nonce = nonce;
req.session.save((err) => {
  if (err) return res.status(500).json({ error: 'Failed to save session' });
  res.json({ nonce });
});
```

### 4. 地址大小写不匹配

**问题**：数据库保存的地址格式（混合大小写）与查询时的小写地址不匹配，导致查询结果为空。

**解决**：统一使用小写地址保存和查询。

```javascript
// 保存时转换
const from = log.args.from.toLowerCase();
const to = log.args.to.toLowerCase();

// 查询时也转换
const address = req.params.address.toLowerCase();
```

### 5. siwe generateNonce 函数导入错误

**问题**：
```
SiweMessage.generateNonce is not a function
```

**解决**：`generateNonce` 是独立函数，需要单独导入。

```javascript
// 错误
const { SiweMessage } = require('siwe');

// 正确
const { SiweMessage, generateNonce } = require('siwe');

// 使用
const nonce = generateNonce();
```

### 6. 事件区块号与监听区块号不一致

**问题**：使用 `watchBlocks` 监听当前区块，但事件可能发生在中间区块，导致漏记。

**解决**：查询范围从 `lastProcessedBlock + 1` 到 `currentBlock`。

```javascript
const fromBlock = lastProcessedBlock + 1;
const toBlock = blockNumber;

const logs = await publicClient.getContractEvents({
  fromBlock: BigInt(fromBlock),
  toBlock: BigInt(toBlock),
});
```

### 7. MetaMask 连接 WalletConnect 网络

**问题**：前端配置包含 Sepolia/Mainnet 网络，导致 AppKit 尝试连接外部 RPC，请求失败。

**解决**：仅配置本地 Anvil 网络，移除外部网络。

```javascript
export const wagmiConfig = createConfig({
  chains: [anvil],  // 只保留 Anvil
  connectors: [injected({ target: 'metaMask' })],
  transports: {
    [anvil.id]: http('http://127.0.0.1:8545'),
  },
});
```

---

## 项目结构 (完整)

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

## 安全最佳实践

1. **永远不要**在命令行直接输入私钥
2. **使用 keystore 文件**进行部署，避免私钥泄露
3. **备份钱包**：定期导出并安全保存助记词
4. **测试网验证**：在主网部署前，先在测试网验证功能
5. **使用环境变量**：敏感信息使用环境变量而非硬编码
6. **权限控制**：仅授权必要的合约访问权限

## 许可证

MIT License
