const express = require('express');
const cors = require('cors');
const session = require('express-session');
const { SiweMessage, generateNonce } = require('siwe');
const { createPublicClient, http, formatUnits } = require('viem');
const { localhost } = require('viem/chains');
const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');
const config = require('./config');

const app = express();

// 中间件
app.use(cors({
  origin: config.frontendUrl,
  credentials: true,
}));
app.use(express.json());
app.use(
  session({
    secret: config.session.secret,
    resave: false,
    saveUninitialized: true, // 改为 true，确保 session 被创建
    cookie: {
      secure: false, // 开发环境使用 false
      maxAge: config.session.maxAge,
      sameSite: 'lax', // 允许跨端口 cookie
    },
  })
);

// 创建 viem 客户端（增加 pollingInterval）
const publicClient = createPublicClient({
  chain: localhost,
  transport: http(config.rpcUrl),
  pollingInterval: 1000, // 每1秒轮询一次
});

// MyToken ABI
const myTokenAbi = JSON.parse(fs.readFileSync(path.join(__dirname, 'abis/MyToken.json'), 'utf8'));

// 数据库相关
let db = null;
let dbPath = config.database.path;

// 初始化数据库
const initDatabase = async () => {
  const SQL = await initSqlJs();
  
  // 如果数据库文件存在，加载它
  if (fs.existsSync(dbPath)) {
    const fileBuffer = fs.readFileSync(dbPath);
    db = new SQL.Database(fileBuffer);
  } else {
    db = new SQL.Database();
  }
  
  // 创建表
  db.run(`
    CREATE TABLE IF NOT EXISTS transfers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tx_hash TEXT UNIQUE NOT NULL,
      block_number INTEGER NOT NULL,
      from_address TEXT NOT NULL,
      to_address TEXT NOT NULL,
      value TEXT NOT NULL,
      timestamp INTEGER
    )
  `);
  
  // 创建索引表（记录最后处理的区块）
  db.run(`
    CREATE TABLE IF NOT EXISTS indexer_state (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      contract_address TEXT NOT NULL,
      last_block INTEGER NOT NULL,
      updated_at INTEGER
    )
  `);
  
  saveDatabase();
  console.log('✅ Connected to SQLite database');
  console.log('📊 Transfers table created or already exists');
};

// 保存数据库
const saveDatabase = () => {
  if (db) {
    const data = db.export();
    const buffer = Buffer.from(data);
    fs.writeFileSync(dbPath, buffer);
  }
};

// 关闭数据库
const closeDatabase = () => {
  if (db) {
    saveDatabase();
    db.close();
    db = null;
  }
};

// 获取最后处理的区块号
const getLastProcessedBlock = (contractAddress) => {
  const result = db.exec(`SELECT last_block FROM indexer_state WHERE contract_address = ?`, [contractAddress]);
  if (result.length > 0 && result[0].values.length > 0) {
    return Number(result[0].values[0][0]); // 转换为普通数字
  }
  return 0;
};

// 更新最后处理的区块号
const updateLastProcessedBlock = (contractAddress, blockNumber) => {
  const blockNum = Number(blockNumber); // 确保是普通数字
  const timestamp = Date.now();
  
  db.run(`
    INSERT OR REPLACE INTO indexer_state (contract_address, last_block, updated_at)
    VALUES (?, ?, ?)
  `, [contractAddress, blockNum, timestamp]);
  
  saveDatabase();
};

// 索引转账事件
const indexTransferEvents = async () => {
  try {
    console.log('==============================================');
    console.log('      MyToken Transfer Indexer');
    console.log('==============================================');
    console.log(`📡 RPC URL: ${config.rpcUrl}`);
    console.log(`📄 MyToken 地址: ${config.myTokenAddress}`);
    console.log('==============================================');
    
    // 获取链ID
    const chainId = await publicClient.getChainId();
    console.log(`✅ 已连接到链 ID: ${chainId}`);
    
    // 获取当前区块号
    const currentBlock = await publicClient.getBlockNumber();
    const currentBlockNum = Number(currentBlock); // 转换为普通数字
    console.log(`📊 当前区块号: ${currentBlockNum}`);
    
    // 获取最后处理的区块号
    const lastProcessedBlock = getLastProcessedBlock(config.myTokenAddress);
    console.log(`📊 最后处理的区块号: ${lastProcessedBlock}`);
    
    // 如果已经处理到最新区块，跳过
    if (lastProcessedBlock >= currentBlockNum) {
      console.log('✅ 已经索引到最新区块，无需继续');
      return;
    }
    
    // 开始索引
    const startBlock = lastProcessedBlock > 0 ? lastProcessedBlock + 1 : 0;
    const batchSize = Number(config.indexer.batchSize); // 确保是普通数字
    
    console.log(`\n开始索引区块 ${startBlock} 到 ${currentBlockNum}...`);
    
    let totalInserted = 0;
    let processedBlock = startBlock;
    
    // 分批处理
    while (processedBlock <= currentBlockNum) {
      const endBlock = Math.min(processedBlock + batchSize - 1, currentBlockNum);
      
      console.log(`处理区块 ${processedBlock} - ${endBlock}...`);
      
      // 获取Transfer事件
      const logs = await publicClient.getContractEvents({
        address: config.myTokenAddress,
        abi: myTokenAbi,
        eventName: 'Transfer',
        fromBlock: BigInt(processedBlock),
        toBlock: BigInt(endBlock),
      });
      
      // 插入数据库
      for (const log of logs) {
        try {
          const txHash = log.transactionHash;
          const blockNumber = Number(log.blockNumber);
          const from = log.args.from.toLowerCase();
          const to = log.args.to.toLowerCase();
          const value = log.args.value.toString(); // 转换为字符串
          
          // 检查是否已存在
          const existing = db.exec(`SELECT id FROM transfers WHERE tx_hash = ?`, [txHash]);
          if (existing.length > 0 && existing[0].values.length > 0) {
            continue; // 已存在，跳过
          }
          
          // 插入新记录
          db.run(`
            INSERT INTO transfers (tx_hash, block_number, from_address, to_address, value, timestamp)
            VALUES (?, ?, ?, ?, ?, ?)
          `, [txHash, blockNumber, from, to, value, Date.now()]);
          
          totalInserted++;
        } catch (error) {
          console.error(`插入转账记录失败:`, error.message);
        }
      }
      
      // 更新最后处理的区块
      updateLastProcessedBlock(config.myTokenAddress, endBlock);
      
      processedBlock = endBlock + 1;
    }
    
    saveDatabase();
    console.log(`\n✅ 索引完成！共插入 ${totalInserted} 条转账记录`);
    
  } catch (error) {
    console.error('❌ 索引失败:', error.message);
    throw error;
  }
};

// 启动实时监听（使用 watchBlocks）
const startRealtimeListener = () => {
  console.log('\n🔔 启动实时转账监听...');
  
  // 使用 watchBlocks 监听新区块
  const unwatch = publicClient.watchBlocks({
    onBlock: async (block) => {
      console.log('\n🔔 watchBlocks 触发');
      
      const blockNumber = Number(block.number);
      const lastProcessedBlock = getLastProcessedBlock(config.myTokenAddress);
      
      console.log(`当前区块: ${blockNumber}, 最后处理: ${lastProcessedBlock}`);
      
      // 只处理新区块
      if (blockNumber > lastProcessedBlock) {
        console.log(`\n📦 新区块: ${blockNumber}`);
        
        try {
          // 获取从 lastProcessedBlock+1 到当前区块的所有 Transfer 事件
          const fromBlock = lastProcessedBlock + 1;
          const toBlock = blockNumber;
          
          console.log(`   查询合约: ${config.myTokenAddress}`);
          console.log(`   查询区块范围: ${fromBlock} - ${toBlock}`);
          
          const logs = await publicClient.getContractEvents({
            address: config.myTokenAddress,
            abi: myTokenAbi,
            eventName: 'Transfer',
            fromBlock: BigInt(fromBlock),
            toBlock: BigInt(toBlock),
          });
          
          console.log(`   查询结果: ${logs.length} 个事件`);
          
          if (logs.length > 0) {
            console.log(`   发现 ${logs.length} 个转账事件`);
            
            for (const log of logs) {
              try {
                console.log(`   Event args: from=${log.args.from}, to=${log.args.to}, value=${log.args.value.toString()}`);
                
                const txHash = log.transactionHash;
                const from = log.args.from.toLowerCase(); // 转换为小写
                const to = log.args.to.toLowerCase(); // 转换为小写
                const value = log.args.value.toString();
                const eventBlockNumber = Number(log.blockNumber);
                
                // 检查是否已存在
                const existing = db.exec(`SELECT id FROM transfers WHERE tx_hash = ?`, [txHash]);
                if (existing.length > 0 && existing[0].values.length > 0) {
                  console.log(`   ⚠️  转账已存在，跳过: ${txHash}`);
                  continue;
                }
                
                // 插入新记录
                db.run(`
                  INSERT INTO transfers (tx_hash, block_number, from_address, to_address, value, timestamp)
                  VALUES (?, ?, ?, ?, ?, ?)
                `, [txHash, eventBlockNumber, from, to, value, Date.now()]);
                
                console.log(`   ✅ 已保存到数据库`);
                
                console.log(`\n📝 新转账事件:`);
                console.log(`   From: ${from}`);
                console.log(`   To: ${to}`);
                console.log(`   Value: ${formatUnits(value, 18)} MTK`);
                console.log(`   Block: ${eventBlockNumber}`);
                console.log(`   TxHash: ${txHash}`);
                
              } catch (error) {
                console.error('处理转账事件失败:', error.message);
              }
            }
            
            saveDatabase();
          }
          
          // 更新最后处理的区块
          updateLastProcessedBlock(config.myTokenAddress, blockNumber);
          
        } catch (error) {
          console.error('获取区块事件失败:', error.message);
        }
      }
    },
    onError: (error) => {
      console.error('监听区块错误:', error.message);
    },
  });
  
  console.log('✅ 实时监听已启动（watchBlocks 方式）');
  
  return unwatch;
};

// API 路由

// 获取 nonce
app.get('/api/nonce', async (req, res) => {
  try {
    const nonce = generateNonce();
    req.session.nonce = nonce;
    
    // 显式保存 session
    req.session.save((err) => {
      if (err) {
        console.error('保存 session 失败:', err);
        return res.status(500).json({ error: 'Failed to save session' });
      }
      
      console.log('\n🔑 生成 nonce:', nonce);
      console.log('Session ID:', req.session.id);
      console.log('Session data:', req.session);
      console.log('✅ Session 已保存');
      
      res.json({ nonce });
    });
  } catch (error) {
    console.error('生成 nonce 失败:', error);
    res.status(500).json({ error: 'Failed to generate nonce' });
  }
});

// 验证 SIWE 签名
app.post('/api/verify', async (req, res) => {
  try {
    console.log('\n🔐 验证签名...');
    console.log('Session ID:', req.session.id);
    console.log('Session nonce:', req.session.nonce);
    console.log('Session data:', req.session);
    
    const { message, signature } = req.body;
    
    console.log('Message nonce:', message.nonce);
    
    if (!message || !signature) {
      return res.status(400).json({ error: 'Missing message or signature' });
    }
    
    const siweMessage = new SiweMessage(message);
    
    // 验证 nonce
    if (siweMessage.nonce !== req.session.nonce) {
      console.log('❌ Nonce 不匹配!');
      console.log('Expected:', req.session.nonce);
      console.log('Received:', siweMessage.nonce);
      return res.status(422).json({ error: 'Invalid nonce' });
    }
    
    // 验证签名
    const fields = await siweMessage.verify({
      signature,
      nonce: req.session.nonce,
    });
    
    if (!fields.success) {
      return res.status(422).json({ error: 'Invalid signature' });
    }
    
    // 保存用户信息到 session
    req.session.siwe = siweMessage;
    req.session.address = siweMessage.address;
    
    res.json({ success: true, address: siweMessage.address });
  } catch (error) {
    console.error('SIWE verification error:', error);
    res.status(500).json({ error: 'Verification failed' });
  }
});

// 获取当前用户信息
app.get('/api/me', (req, res) => {
  if (!req.session.siwe) {
    return res.status(401).json({ error: 'Not authenticated' });
  }
  
  res.json({
    address: req.session.address,
    chainId: req.session.siwe.chainId,
  });
});

// 登出
app.post('/api/logout', (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      return res.status(500).json({ error: 'Logout failed' });
    }
    res.json({ success: true });
  });
});

// 获取转账记录
app.get('/api/transfers/:address', (req, res) => {
  try {
    // 检查认证
    if (!req.session.siwe) {
      return res.status(401).json({ error: 'Not authenticated' });
    }
    
    // 只能查询自己的转账记录
    const address = req.params.address.toLowerCase();
    const sessionAddress = req.session.address.toLowerCase();
    
    if (address !== sessionAddress) {
      return res.status(403).json({ error: 'Can only query your own transfers' });
    }
    
    const { page = 1, limit = 10, type = 'all' } = req.query;
    const offset = (Number(page) - 1) * Number(limit);
    
    let query = '';
    let params = [];
    
    if (type === 'sent') {
      query = `SELECT * FROM transfers WHERE from_address = ? ORDER BY block_number DESC LIMIT ? OFFSET ?`;
      params = [address, Number(limit), offset];
    } else if (type === 'received') {
      query = `SELECT * FROM transfers WHERE to_address = ? ORDER BY block_number DESC LIMIT ? OFFSET ?`;
      params = [address, Number(limit), offset];
    } else {
      query = `SELECT * FROM transfers WHERE from_address = ? OR to_address = ? ORDER BY block_number DESC LIMIT ? OFFSET ?`;
      params = [address, address, Number(limit), offset];
    }
    
    const result = db.exec(query, params);
    
    let transfers = [];
    if (result.length > 0 && result[0].values.length > 0) {
      transfers = result[0].values.map(row => ({
        id: row[0],
        txHash: row[1],
        blockNumber: Number(row[2]),
        from: row[3],
        to: row[4],
        value: row[5],
        valueFormatted: formatUnits(row[5], 18),
        timestamp: Number(row[6]),
        type: row[3].toLowerCase() === address ? 'sent' : 'received',
      }));
    }
    
    // 获取总数
    let countQuery = '';
    let countParams = [];
    
    if (type === 'sent') {
      countQuery = `SELECT COUNT(*) as total FROM transfers WHERE from_address = ?`;
      countParams = [address];
    } else if (type === 'received') {
      countQuery = `SELECT COUNT(*) as total FROM transfers WHERE to_address = ?`;
      countParams = [address];
    } else {
      countQuery = `SELECT COUNT(*) as total FROM transfers WHERE from_address = ? OR to_address = ?`;
      countParams = [address, address];
    }
    
    const countResult = db.exec(countQuery, countParams);
    const total = countResult.length > 0 ? Number(countResult[0].values[0][0]) : 0;
    
    res.json({
      transfers,
      total,
      page: Number(page),
      limit: Number(limit),
      totalPages: Math.ceil(total / Number(limit)),
    });
    
  } catch (error) {
    console.error('Get transfers error:', error);
    res.status(500).json({ error: 'Failed to get transfers' });
  }
});

// 获取转账统计
app.get('/api/transfers/:address/stats', (req, res) => {
  try {
    // 检查认证
    if (!req.session.siwe) {
      return res.status(401).json({ error: 'Not authenticated' });
    }
    
    const address = req.params.address.toLowerCase();
    const sessionAddress = req.session.address.toLowerCase();
    
    if (address !== sessionAddress) {
      return res.status(403).json({ error: 'Can only query your own stats' });
    }
    
    // 发送统计
    const sentResult = db.exec(`SELECT COUNT(*) as count, SUM(value) as total FROM transfers WHERE from_address = ?`, [address]);
    const sentCount = sentResult.length > 0 ? Number(sentResult[0].values[0][0]) : 0;
    const sentTotal = sentResult.length > 0 && sentResult[0].values[0][1] ? sentResult[0].values[0][1].toString() : '0';
    
    // 接收统计
    const receivedResult = db.exec(`SELECT COUNT(*) as count, SUM(value) as total FROM transfers WHERE to_address = ?`, [address]);
    const receivedCount = receivedResult.length > 0 ? Number(receivedResult[0].values[0][0]) : 0;
    const receivedTotal = receivedResult.length > 0 && receivedResult[0].values[0][1] ? receivedResult[0].values[0][1].toString() : '0';
    
    res.json({
      sent: {
        count: sentCount,
        total: sentTotal,
        totalFormatted: formatUnits(sentTotal, 18),
      },
      received: {
        count: receivedCount,
        total: receivedTotal,
        totalFormatted: formatUnits(receivedTotal, 18),
      },
    });
    
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({ error: 'Failed to get stats' });
  }
});

// 手动触发索引
app.post('/api/admin/index', async (req, res) => {
  try {
    await indexTransferEvents();
    res.json({ success: true, message: 'Indexing completed' });
  } catch (error) {
    res.status(500).json({ error: 'Indexing failed', details: error.message });
  }
});

// 启动服务器
const startServer = async () => {
  try {
    // 初始化数据库
    await initDatabase();
    
    // 索引历史转账事件
    await indexTransferEvents();
    
    // 启动实时监听
    const unwatch = startRealtimeListener();
    
    // 启动 Express 服务器
    app.listen(config.port, () => {
      console.log('==============================================');
      console.log('      TokenBank Backend Server');
      console.log('==============================================');
      console.log(`🚀 Server running on http://localhost:${config.port}`);
      console.log(`📡 RPC URL: ${config.rpcUrl}`);
      console.log(`🌐 Frontend URL: ${config.frontendUrl}`);
      console.log(`📄 MyToken: ${config.myTokenAddress}`);
      console.log('==============================================');
      console.log('\nAPI Endpoints:');
      console.log('  GET  /api/nonce          - Get SIWE nonce');
      console.log('  POST /api/verify         - Verify SIWE signature');
      console.log('  GET  /api/me             - Get current user');
      console.log('  POST /api/logout         - Logout');
      console.log('  GET  /api/transfers/:addr - Get transfer history');
      console.log('  GET  /api/transfers/:addr/stats - Get transfer stats');
      console.log('  POST /api/admin/index    - Trigger manual indexing');
      console.log('==============================================\n');
    });
    
    // 处理退出
    process.on('SIGINT', () => {
      console.log('\n\n⏹️ 正在停止服务器...');
      unwatch();
      closeDatabase();
      console.log('✅ 已停止所有服务');
      process.exit(0);
    });
    
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();