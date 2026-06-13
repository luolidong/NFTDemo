# TokenBank Frontend

一个基于 Web3 的代币银行 DApp 前端，使用 React、Vite、Tailwind CSS 和 Reown AppKit 构建。

## 项目介绍

TokenBank 是一个去中心化代币存储应用，允许用户：
- 查看钱包余额和存款信息
- 授权并存款代币到银行合约
- 合约所有者提取所有代币

### 主要功能

- 🔐 **安全连接**：通过 Reown AppKit 支持多种钱包（MetaMask、WalletConnect、Coinbase Wallet 等）
- 💰 **代币存款**：用户授权后可将 MTK 代币存入银行合约
- 📊 **实时数据**：显示用户余额、存款余额、银行总余额和授权额度
- 👑 **所有者权限**：合约所有者可提取全部代币
- 🌐 **多链支持**：支持 Ethereum Mainnet 和 Sepolia 测试网

## 技术栈

- **框架**: React 19 + Vite 6
- **样式**: Tailwind CSS 3
- **Web3**: 
  - Reown AppKit 1.8.20
  - wagmi 3.6.16
  - viem 2.52.2
  - ethers 6.16.0
- **钱包连接**: WalletConnect、MetaMask、Coinbase Wallet
- **状态管理**: @tanstack/react-query 5.101.0

## 前置要求

- Node.js >= 18
- pnpm >= 8（推荐）或 npm/yarn
- 已部署的 MyToken 和 TokenBank 合约
- WalletConnect Project ID（从 [WalletConnect Cloud](https://cloud.walletconnect.com/) 获取）

## 安装

```bash
# 克隆项目后，进入目录
cd tokenbank-frontend

# 安装依赖
pnpm install
```

## 配置

### 1. 编辑配置文件

编辑 `src/config/index.js`，填入配置：

```javascript
export default {
  walletConnectProjectId: 'your_walletconnect_project_id',
  tokenBankAddress: 'your_token_bank_address',
  myTokenAddress: 'your_my_token_address',
  appName: 'TokenBank',
  appUrl: 'https://example.com',
};
```

- **walletConnectProjectId**: 从 [WalletConnect Cloud](https://cloud.walletconnect.com/) 注册获取免费项目 ID
- **tokenBankAddress**: TokenBank 合约部署地址
- **myTokenAddress**: MyToken 合约部署地址

### 2. 配置网络（可选）

默认支持 Anvil 本地网络、Sepolia 测试网和 Ethereum 主网。如需修改，编辑 `src/config/wagmi.js`：

```javascript
chains: [anvil, sepolia, mainnet],
```

## 开发

### 启动开发服务器

```bash
pnpm dev
```

访问 http://localhost:5173 查看应用。

### 构建生产版本

```bash
pnpm build
```

构建产物将输出到 `dist/` 目录。

### 预览生产构建

```bash
pnpm preview
```

## 测试

### 使用 Anvil 本地测试（推荐）

Anvil 是 Foundry 框架提供的本地以太坊开发节点，适合快速开发和测试。

#### 1. 启动 Anvil

```bash
# 在 Foundry 项目根目录
cd /Users/luolidong/github/NFTDemo
anvil
```

Anvil 启动后会显示：
```
Listening on 127.0.0.1:8545
```

#### 2. 部署合约到 Anvil

打开另一个终端：

```bash
# 部署 TokenBank 和 MyToken 合约
forge script script/DeployTokenBank.s.sol:DeployTokenBank \
  --rpc-url http://localhost:8545 \
  --broadcast
```

成功后会显示合约地址：
```
MyToken deployed at: 0x5FbDB2315678afecb367f032d93F642f64180aa3
TokenBank deployed at: 0xe7f1725E7734CE288F8367e1Bb2E38QQcEFd2C3F
```

#### 3. 配置前端

编辑 `src/config/index.js`，填入合约地址：

```javascript
tokenBankAddress: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
myTokenAddress: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
```

#### 4. 启动前端

```bash
cd tokenbank-frontend
pnpm dev
```

#### 5. 连接钱包到 Anvil

1. 打开浏览器访问 http://localhost:5173
2. 点击 "Connect Wallet"
3. 如果使用 MetaMask：
   - 手动添加 Anvil 网络：
     - 网络名称：Anvil Local
     - RPC URL：http://localhost:8545
     - 链 ID：31337
     - 货币符号：ETH
   - 导入测试账户私钥：
     ```
     0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
     ```
     （这是 Anvil 的默认部署者账户，拥有 10000 ETH）

#### 6. 测试流程

1. **连接钱包**：点击 "Connect Wallet" 并选择 MetaMask
2. **切换网络**：确保连接到 "Anvil Local" 网络（链 ID: 31337）
3. **存款测试**：
   - 输入存款金额（如：100）
   - 点击 "Approve" 授权 TokenBank 合约
   - 点击 "Deposit" 存款
   - 观察余额变化

#### 7. 常用 Anvil 命令

```bash
# 查看可用账户
anvil --accounts

# 自定义初始 ETH 数量
anvil --balance 1000

# 保留历史状态
anvil --slots-after-pruning 10000

# 锁定账户（只读模式）
anvil --load-state state.json
```

### 使用 Sepolia 测试网测试

#### 1. 部署合约

```bash
forge script script/DeployTokenBank.s.sol:DeployTokenBank \
  --rpc-url sepolia \
  --private-key YOUR_PRIVATE_KEY \
  --broadcast
```

#### 2. 配置前端

编辑 `src/App.jsx`，使用 Sepolia 上的合约地址。

#### 3. 连接钱包

1. 确保 MetaMask 连接到 Sepolia 测试网
2. 获取测试 ETH：
   - https://www.alchemy.com/faucet
   - https://www.infura.io/faucet

#### 4. 测试流程

与 Anvil 测试相同。

### 重要提示

- ⚠️ **Anvil 账户私钥是公开的**，不要在主网或测试网使用这些私钥
- ⚠️ **Anvil 重启后会重置所有状态**，确保及时保存重要测试数据
- ⚠️ 如果前端无法连接 Anvil，检查：
  - Anvil 是否正在运行（默认端口 8545）
  - MetaMask 是否配置了正确的网络
  - CORS 设置（Anvil 默认允许所有来源）


## 部署

### Vercel

```bash
# 安装 Vercel CLI
npm i -g vercel

# 部署
vercel
```

### Netlify

```bash
# 安装 Netlify CLI
npm i -g netlify-cli

# 部署
netlify deploy --prod
```

### 手动部署

将 `dist/` 目录内容上传到任何静态托管服务（GitHub Pages、Cloudflare Pages 等）。

## 项目结构

```
tokenbank-frontend/
├── src/
│   ├── abi/
│   │   ├── TokenBank.js     # TokenBank 合约 ABI
│   │   └── MyToken.js        # MyToken 合约 ABI
│   ├── config/
│   │   └── wagmi.js          # Wagmi/AppKit 配置
│   ├── App.jsx               # 主应用组件
│   ├── main.jsx              # 应用入口
│   └── index.css             # Tailwind 样式
├── public/
├── tailwind.config.js        # Tailwind 配置
├── postcss.config.js         # PostCSS 配置
├── vite.config.js            # Vite 配置
└── package.json
```

## 使用说明

### 连接钱包
1. 点击右上角 "Connect Wallet" 按钮
2. 选择钱包（MetaMask、WalletConnect、Coinbase Wallet）
3. 授权连接

### 存款代币
1. 输入存款金额
2. 点击 "Approve" 授权 TokenBank 合约使用你的代币
3. 点击 "Deposit" 存款

### 提取代币（仅所有者）
1. 连接部署合约的钱包
2. 点击 "Withdraw All" 提取所有代币

## 注意事项

- ⚠️ 确保连接到 Sepolia 测试网或 Anvil 本地网络（主网功能需实际部署）
- ⚠️ 合约地址必须替换为实际部署地址
- ⚠️ 使用测试网时获取足够的测试 ETH

## 已知问题

### 未完全测试的功能

以下功能需要在完整环境中进一步测试：

1. **WalletConnect 钱包连接**
   - 状态：由于网络限制（VPN），WebSocket 连接 WalletConnect Relay 服务器可能超时
   - 临时解决方案：使用 "MetaMask" 按钮直接通过浏览器扩展连接
   - 后续计划：需要稳定网络环境进行完整测试

2. **多钱包支持**
   - 当前仅测试了 MetaMask 浏览器扩展
   - Coinbase Wallet、Trust Wallet 等其他钱包尚未测试

3. **跨链功能**
   - 当前仅支持 EVM 链（Anvil、Sepolia、Mainnet）
   - 其他链（Solana、Bitcoin 等）未测试

4. **智能合约交互**
   - Approve 功能：✅ 已测试
   - Deposit 功能：✅ 已测试
   - Withdraw 功能：✅ 已测试（仅所有者）
   - 错误处理：需要更多边界情况测试

5. **网络切换**
   - 从 AppKit 弹窗切换网络未测试
   - MetaMask 手动切换网络已测试

## License

MIT
