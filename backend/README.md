# TokenBank Backend - 合并版本

## 功能特性

- ✅ **MyToken 转账索引** - 自动索引历史转账事件并存储到 SQLite
- ✅ **实时监听** - 监听新的转账事件并实时更新数据库
- ✅ **RESTful API** - 提供转账记录查询接口
- ✅ **SIWE 认证** - 使用 Ethereum 签名进行身份验证
- ✅ **统计信息** - 提供发送/接收统计

## 快速启动

### 1. 启动 Anvil（本地测试链）

在终端运行：
```bash
anvil --port 8545
```

### 2. 部署合约

```bash
forge script script/DeployTokenBank.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

记录 MyToken 地址，更新 `config/index.js` 中的 `myTokenAddress`。

### 3. 启动后端服务器

```bash
cd backend
pnpm install
pnpm run dev
```

服务器会自动：
- 初始化数据库
- 索引历史转账事件
- 启动实时监听
- 启动 API 服务器

### 4. 启动前端

```bash
cd tokenbank-frontend
pnpm run dev
```

## API 接口

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/api/nonce` | 获取 SIWE nonce |
| POST | `/api/verify` | 验证 SIWE 签名 |
| GET | `/api/me` | 获取当前用户信息 |
| POST | `/api/logout` | 登出 |
| GET | `/api/transfers/:address` | 获取转账记录（需认证） |
| GET | `/api/transfers/:address/stats` | 获取转账统计（需认证） |
| POST | `/api/admin/index` | 手动触发索引 |

## 配置

配置文件：`config/index.js`

```javascript
{
  port: 3001,                    // 服务器端口
  frontendUrl: 'http://localhost:5173',  // CORS 前端 URL
  rpcUrl: 'http://127.0.0.1:8545',     // RPC 节点地址
  myTokenAddress: '0x...',              // MyToken 合约地址
  session: { secret: '...', maxAge: 24h },
  database: { path: './transfers.db' },
  indexer: { batchSize: 1000 }
}
```

## 测试转账

使用 cast 命令转账：

```bash
# 转账 100 MTK
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 \
  "transfer(address,uint256)" \
  0x70997970C51812dc3A010C7d01b50e0d17dc79C8 \
  100000000000000000000 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

转账后，后端会自动监听并记录到数据库。

## 数据库

- 文件：`transfers.db`（SQLite）
- 表：`transfers` - 转账记录
- 表：`indexer_state` - 索引状态（记录最后处理的区块）

## 注意事项

1. 确保 Anvil 正在运行
2. 部署合约后更新配置文件中的合约地址
3. 查询转账记录需要先进行 SIWE 登录
4. 只能查询自己的转账记录
5. BigInt 错误已修复：所有区块号和数值都转换为普通数字或字符串