# DigitalAvatar NFT Project

一个基于 OpenZeppelin 的 ERC721 NFT 项目，用于创建和部署数字头像 NFT。

## 项目结构

```
NFTDemo/
├── src/
│   └── DigitalAvatar.sol    # ERC721 NFT 合约
├── test/
│   └── DigitalAvatar.t.sol  # 合约测试
├── script/
│   ├── DeployDigitalAvatar.s.sol   # 部署脚本
│   └── MintDigitalAvatar.s.sol     # 铸造脚本
├── metadata/
│   ├── avatar.jpg          # NFT 图片资源
│   └── metadata.json       # NFT 元数据
└── lib/
    ├── forge-std/          # Foundry 标准库
    └── openzeppelin-contracts/  # OpenZeppelin 合约库
```

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
```

## 部署到 Sepolia 测试网

### 步骤 1：部署合约

```bash
forge script script/DeployDigitalAvatar.s.sol:DeployDigitalAvatar \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --broadcast \
  --keystore ~/.foundry/keystores/my-sepolia-wallet.json \
  -vvv
```

**复制部署输出中的合约地址**，例如：`0x1234...abcd`

### 步骤 2：更新铸造脚本

替换 `script/MintDigitalAvatar.s.sol` 中的合约地址和 metadata IPFS 地址：

```bash
# 设置变量
export CONTRACT_ADDRESS="0xYourContractAddress"
export METADATA_URI="ipfs://QmYourMetadataHash/metadata.json"

# 更新合约地址
sed -i '' "s/0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496/$CONTRACT_ADDRESS/" script/MintDigitalAvatar.s.sol

# 更新 metadata URI
sed -i '' "s|ipfs://QmYourImageHashHere/metadata.json|$METADATA_URI|" script/MintDigitalAvatar.s.sol
```

### 步骤 3：铸造 NFT

```bash
forge script script/MintDigitalAvatar.s.sol:MintDigitalAvatar \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --broadcast \
  --keystore ~/.foundry/keystores/my-sepolia-wallet.json \
  -vvv
```

## 验证部署

### 在 Etherscan 上查看

访问 Sepolia 区块浏览器：
- https://sepolia.etherscan.io/address/your-contract-address

### 验证合约代码（可选）

```bash
forge verify-contract \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo \
  --etherscan-api-key YOUR_ETHERSCAN_API_KEY \
  $CONTRACT_ADDRESS \
  src/DigitalAvatar.sol:DigitalAvatar
```

### 在 MetaMask 中查看 NFT

1. 打开 MetaMask → 切换到 Sepolia 测试网
2. 点击 "添加资产" → "添加 NFT"
3. 输入合约地址和 Token ID（0）

## 检查 NFT 状态

```bash
# 检查 NFT 余额
cast call $CONTRACT_ADDRESS "balanceOf(address)(uint256)" \
  $(cast wallet address --keystore ~/.foundry/keystores/my-sepolia-wallet.json) \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo

# 查看 tokenURI
cast call $CONTRACT_ADDRESS "tokenURI(uint256)(string)" 0 \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/demo
```

## 安全最佳实践

1. **永远不要**在命令行直接输入私钥
2. **使用 keystore 文件**进行部署，避免私钥泄露
3. **备份钱包**：定期导出并安全保存助记词
4. **测试网验证**：在主网部署前，先在测试网验证功能
5. **使用环境变量**：敏感信息使用环境变量而非硬编码

## 许可证

MIT License
