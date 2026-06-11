// Viem 2.x 版本事件监听器 - 使用 watchContractEvent API（推荐方式）
require('dotenv').config();
const { createPublicClient, http, formatEther } = require('viem');
const { localhost, mainnet, polygon, optimism, arbitrum, sepolia } = require('viem/chains');
const fs = require('fs');
const path = require('path');

// 链配置映射 - 支持多种区块链网络
const chainMap = {
  localhost,
  mainnet,
  polygon,
  optimism,
  arbitrum,
  sepolia
};

// 获取链配置
const CHAIN_NAME = process.env.CHAIN_NAME || 'localhost';
const selectedChain = chainMap[CHAIN_NAME];

if (!selectedChain) {
  console.error(`❌ 不支持的链: ${CHAIN_NAME}`);
  console.error(`   支持的链: ${Object.keys(chainMap).join(', ')}`);
  process.exit(1);
}

// NFTMarket 合约地址
const NFT_MARKET_ADDRESS = process.env.NFT_MARKET_ADDRESS || '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0';

// 从本地 ABI 文件加载（生产环境配置）
const abiPath = path.join(__dirname, 'abis/NFTMarket.json');
const nftMarketAbi = JSON.parse(fs.readFileSync(abiPath, 'utf8')).abi;

// 创建公共客户端
const publicClient = createPublicClient({
  chain: selectedChain,
  transport: http(process.env.RPC_URL || 'http://127.0.0.1:8545'),
  pollingInterval: process.env.POLLING_INTERVAL ? parseInt(process.env.POLLING_INTERVAL) : 1000
});

// 格式化地址
const formatAddr = (addr) => {
  return addr.toString();
};

// 处理 NFTListed 事件
const handleNFTListed = (log) => {
  const { args, blockNumber, transactionHash } = log;
  const timestamp = new Date().toLocaleString('zh-CN');
  
  console.log('\n═══════════════════════════════════════════════════');
  console.log(`📅 ${timestamp}`);
  console.log(`📦 [上架事件] NFT Listed`);
  console.log(`├─ 区块号: ${blockNumber}`);
  console.log(`├─ 交易哈希: ${transactionHash}`);
  console.log(`├─ 卖家: ${formatAddr(args.seller)}`);
  console.log(`├─ Token ID: ${args.tokenId.toString()}`);
  console.log(`└─ 价格: ${formatEther(args.price)} MTK`);
  console.log('═══════════════════════════════════════════════════');
};

// 处理 NFTSold 事件
const handleNFTSold = (log) => {
  const { args, blockNumber, transactionHash } = log;
  const timestamp = new Date().toLocaleString('zh-CN');
  
  console.log('\n═══════════════════════════════════════════════════');
  console.log(`📅 ${timestamp}`);
  console.log(`💰 [买卖事件] NFT Sold`);
  console.log(`├─ 区块号: ${blockNumber}`);
  console.log(`├─ 交易哈希: ${transactionHash}`);
  console.log(`├─ 卖家: ${formatAddr(args.seller)}`);
  console.log(`├─ 买家: ${formatAddr(args.buyer)}`);
  console.log(`├─ Token ID: ${args.tokenId.toString()}`);
  console.log(`└─ 成交价格: ${formatEther(args.price)} MTK`);
  console.log('═══════════════════════════════════════════════════');
};

// 处理 NFTDelisted 事件
const handleNFTDelisted = (log) => {
  const { args, blockNumber, transactionHash } = log;
  const timestamp = new Date().toLocaleString('zh-CN');
  
  console.log('\n═══════════════════════════════════════════════════');
  console.log(`📅 ${timestamp}`);
  console.log(`❌ [下架事件] NFT Delisted`);
  console.log(`├─ 区块号: ${blockNumber}`);
  console.log(`├─ 交易哈希: ${transactionHash}`);
  console.log(`├─ 卖家: ${formatAddr(args.seller)}`);
  console.log(`└─ Token ID: ${args.tokenId.toString()}`);
  console.log('═══════════════════════════════════════════════════');
};

// 主函数
const main = async () => {
  console.log('==============================================');
  console.log('      NFT Market Event Listener (Viem)');
  console.log('         使用 watchContractEvent API');
  console.log('==============================================');
  console.log(`📡 连接到: ${process.env.RPC_URL || 'http://127.0.0.1:8545'}`);
  console.log(`📄 监听合约: ${NFT_MARKET_ADDRESS}`);
  console.log('==============================================');

  try {
    // 测试连接
    const chainId = await publicClient.getChainId();
    console.log(`✅ 已连接到链 ID: ${chainId}`);

    // 获取当前区块号
    const currentBlock = await publicClient.getBlockNumber();
    console.log(`📊 当前区块号: ${currentBlock}`);

    console.log('\n🔔 开始监听所有事件...');

    // 使用 watchContractEvent 监听 NFTListed 事件
    const unwatchListed = publicClient.watchContractEvent({
      address: NFT_MARKET_ADDRESS,
      abi: nftMarketAbi,
      eventName: 'NFTListed',
      onLogs: (logs) => {
        logs.forEach(handleNFTListed);
      },
      onError: (error) => {
        console.error('❌ NFTListed 监听错误:', error.message);
      }
    });

    // 使用 watchContractEvent 监听 NFTSold 事件
    const unwatchSold = publicClient.watchContractEvent({
      address: NFT_MARKET_ADDRESS,
      abi: nftMarketAbi,
      eventName: 'NFTSold',
      onLogs: (logs) => {
        logs.forEach(handleNFTSold);
      },
      onError: (error) => {
        console.error('❌ NFTSold 监听错误:', error.message);
      }
    });

    // 使用 watchContractEvent 监听 NFTDelisted 事件
    const unwatchDelisted = publicClient.watchContractEvent({
      address: NFT_MARKET_ADDRESS,
      abi: nftMarketAbi,
      eventName: 'NFTDelisted',
      onLogs: (logs) => {
        logs.forEach(handleNFTDelisted);
      },
      onError: (error) => {
        console.error('❌ NFTDelisted 监听错误:', error.message);
      }
    });

    console.log('\n🚀 监听器已启动，等待事件...');
    console.log('按 Ctrl+C 停止监听');

    // 处理退出
    process.on('SIGINT', () => {
      console.log('\n\n⏹️ 正在停止监听器...');
      unwatchListed();
      unwatchSold();
      unwatchDelisted();
      console.log('✅ 已停止所有监听器');
      process.exit(0);
    });

  } catch (error) {
    console.error('❌ 启动失败:', error.message);
    process.exit(1);
  }
};

main();