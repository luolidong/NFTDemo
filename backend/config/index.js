const path = require('path');

module.exports = {
  // 服务器配置
  port: 3001,
  
  // 前端 URL（用于 CORS）
  frontendUrl: 'http://localhost:5173',
  
  // RPC 配置
  rpcUrl: 'http://127.0.0.1:8545',
  
  // MyToken 合约地址（需要部署后填写）
  myTokenAddress: '0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e',
  
  // Session 配置
  session: {
    secret: 'tokenbank-secret-key-2024',
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
  },
  
  // 数据库配置
  database: {
    path: path.join(__dirname, '../transfers.db'),
  },
  
  // 索引导配置
  indexer: {
    batchSize: 1000, // 每次处理的区块数量
  }
};