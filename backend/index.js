// Viem 2.x 版本事件监听器 - 使用 watchBlocks API
require('dotenv').config();
const { createPublicClient, http, formatEther } = require('viem');
const { localhost } = require('viem/chains');

// NFTMarket 合约地址
const NFT_MARKET_ADDRESS = process.env.NFT_MARKET_ADDRESS || '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0';

// NFTMarket 合约 ABI
const nftMarketAbi = [
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: 'seller', type: 'address' },
      { indexed: true, name: 'tokenId', type: 'uint256' },
      { indexed: false, name: 'price', type: 'uint256' }
    ],
    name: 'NFTListed',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: 'seller', type: 'address' },
      { indexed: true, name: 'buyer', type: 'address' },
      { indexed: true, name: 'tokenId', type: 'uint256' },
      { indexed: false, name: 'price', type: 'uint256' }
    ],
    name: 'NFTSold',
    type: 'event'
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: 'seller', type: 'address' },
      { indexed: true, name: 'tokenId', type: 'uint256' }
    ],
    name: 'NFTDelisted',
    type: 'event'
  }
];

// 创建公共客户端
const publicClient = createPublicClient({
  chain: localhost,
  transport: http(process.env.RPC_URL || 'http://127.0.0.1:8545'),
  pollingInterval: 1000
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

    // 使用 watchBlocks 监听新区块
    const unwatcher = publicClient.watchBlocks({
      onBlock: async (block) => {
        console.log(`\n📦 新区块: ${block.number}`);
        
        // 获取区块中的所有事件
        const listedEvents = await publicClient.getContractEvents({
          address: NFT_MARKET_ADDRESS,
          abi: nftMarketAbi,
          eventName: 'NFTListed',
          fromBlock: block.number,
          toBlock: block.number
        });
        
        const soldEvents = await publicClient.getContractEvents({
          address: NFT_MARKET_ADDRESS,
          abi: nftMarketAbi,
          eventName: 'NFTSold',
          fromBlock: block.number,
          toBlock: block.number
        });
        
        const delistedEvents = await publicClient.getContractEvents({
          address: NFT_MARKET_ADDRESS,
          abi: nftMarketAbi,
          eventName: 'NFTDelisted',
          fromBlock: block.number,
          toBlock: block.number
        });

        // 处理事件
        listedEvents.forEach(handleNFTListed);
        soldEvents.forEach(handleNFTSold);
        delistedEvents.forEach(handleNFTDelisted);
      },
      onError: (error) => {
        console.error('❌ 监听错误:', error.message);
      }
    });

    console.log('\n🚀 监听器已启动，等待新区块...');
    console.log('按 Ctrl+C 停止监听');

    // 处理退出
    process.on('SIGINT', () => {
      console.log('\n\n⏹️ 正在停止监听器...');
      unwatcher();
      console.log('✅ 已停止所有监听器');
      process.exit(0);
    });

  } catch (error) {
    console.error('❌ 启动失败:', error.message);
    process.exit(1);
  }
};

main();
