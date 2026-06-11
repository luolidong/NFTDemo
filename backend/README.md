# NFT Market 事件监听器

基于 Viem 2.x 的 NFT 市场事件监听器，用于实时监听 NFT 上架、买卖和下架事件。

## 功能特性

- ✅ 实时监听 NFT 上架事件 (NFTListed)
- ✅ 实时监听 NFT 买卖事件 (NFTSold)
- ✅ 实时监听 NFT 下架事件 (NFTDelisted)
- ✅ 支持自定义合约地址和 RPC URL
- ✅ 美观的终端输出格式

## 安装依赖

```bash
cd backend
npm install
```

或使用 pnpm：

```bash
cd backend
pnpm install
```

## 配置

创建 `.env` 文件（可选）：

```env
RPC_URL=http://127.0.0.1:8545
NFT_MARKET_ADDRESS=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
```

## 使用方法

### 启动监听器

```bash
npm run start:viem
```

或直接运行：

```bash
node index.js
```

监听器启动后会显示：

```
==============================================
      NFT Market Event Listener (Viem)
==============================================
📡 连接到: http://127.0.0.1:8545
📄 监听合约: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
==============================================
✅ 已连接到链 ID: 31337
📊 当前区块号: 11

🔔 开始监听所有事件...

🚀 监听器已启动，等待新区块...
按 Ctrl+C 停止监听
```

## 测试步骤

### 1. 启动 Anvil 本地节点

```bash
anvil -p 8545
```

### 2. 部署合约

```bash
forge script script/DeployToAnvil.s.sol:DeployToAnvil \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### 3. 设置环境变量

```bash
export SENDER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"        # 发送者地址（Anvil 账户 0）
export NFT_ADDRESS="0x5FbDB2315678afecb367f032d93F642f64180aa3"           # DigitalAvatar 地址
export MARKET_TOKEN="0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"          # MarketToken 地址  
export MARKET_ADDRESS="0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"        # NFTMarket 地址
export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
```

### 4. 铸造测试 NFT

```bash
cast send $NFT_ADDRESS "safeMint(address,string)" $SENDER_ADDRESS "https://example.com/nft/0" \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $PRIVATE_KEY
```

### 5. 铸造测试代币

```bash
cast send $MARKET_TOKEN "mint(address,uint256)" $SENDER_ADDRESS 1000000000000000000000 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $PRIVATE_KEY
```

### 6. 授权市场合约操作 NFT

```bash
cast send $NFT_ADDRESS "setApprovalForAll(address,bool)" $MARKET_ADDRESS true \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $PRIVATE_KEY
```

### 7. 上架 NFT（触发事件）

```bash
cast send "$MARKET_ADDRESS" "list(uint256,uint256)" 0 100000000000000000000 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key "$PRIVATE_KEY"
```

### 8. 查看监听器输出

监听器会实时显示事件信息：

```
📦 新区块: 12

═══════════════════════════════════════════════════
📅 2026/6/11 17:30:36
📦 [上架事件] NFT Listed
├─ 区块号: 12
├─ 交易哈希: 0x70b48c6155f54922befebf106aea72d4bc7f98c6bed95343fec8f10b29d5aa30
├─ 卖家: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
├─ Token ID: 0
└─ 价格: 100 MTK
═══════════════════════════════════════════════════
```

## Anvil 测试账户

Anvil 默认提供 10 个测试账户，每个账户有 10000 ETH：

| 账户 | 地址 | 私钥 |
|------|------|------|
| 0 | 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 | 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 |
| 1 | 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 | 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d |
| 2 | 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC | 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a |
| ... | ... | ... |

## 技术栈

- **Node.js** - 运行环境
- **Viem 2.x** - 以太坊交互库
- **Anvil** - 本地开发节点
- **Foundry** - 智能合约开发框架

## 停止监听器

按 `Ctrl+C` 停止监听器。

## 注意事项

1. 确保 Anvil 节点正在运行
2. 确保合约已正确部署
3. 确保环境变量中的合约地址正确
4. 监听器使用轮询机制，默认间隔为 1000ms

## 许可证

MIT