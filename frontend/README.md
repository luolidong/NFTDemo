# Counter DApp Frontend

基于 React + Vite + Viem 的 Counter 智能合约前端应用。

## 功能

- 读取合约当前数值
- 设置新数值
- 递增操作 (+1)
- 实时显示交易状态

## 技术栈

- **React** - 前端框架
- **Vite** - 构建工具
- **Viem** - 以太坊交互库
- **Tailwind CSS** - 样式框架

## 前置要求

- Node.js >= 18
- pnpm >= 8
- 本地以太坊节点 (如 Anvil)
- 已部署的 Counter 合约

## 安装

```bash
pnpm install
```

## 开发

```bash
pnpm dev
```

访问 http://localhost:5173

## 构建

```bash
pnpm build
```

## 配置

合约地址和 ABI 配置在 `src/App.jsx` 中：

```javascript
const COUNTER_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3'
```

如需修改，请更新 `COUNTER_ADDRESS` 和 `counterABI`。

## 注意事项

1. 确保本地节点运行在 `http://127.0.0.1:8545`
2. 确保合约已部署到对应地址
3. 默认使用 Anvil 的默认账户私钥
