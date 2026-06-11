require('dotenv').config();
const { createPublicClient, http, watchContractEvent, formatEther, Address } = require('viem');
const { localhost } = require('viem/chains');

// NFTMarket 合约地址（部署后需要更新）
const NFT_MARKET_ADDRESS = process.env.NFT_MARKET_ADDRESS || '0x5FbDB2315678afecb367f032d93F642f64180aa3';

// NFTMarket 合约 ABI（仅包含事件定义）
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
  transport: http(process.env.RPC_URL || 'http://127.0.0.1:8545')
});

// 格式化地址
const formatAddress = (addr) => {
  if (Address.validate(addr)) {
    return Address.format(addr);
  }
  return addr;
};

// 监听上架事件
const listenForListings = async () => {
  console.log('\n🔔 开始监听 NFT 上架事件...');
  
  const unwatch = watchContractEvent(
    publicClient,
    {
      address: NFT_MARKET_ADDRESS,
      abi: nftMarketAbi,
      eventName: 'NFTListed'
    },
    (event) => {
      const { args, blockNumber, transactionHash } = event;
      const timestamp = new Date().toLocaleString('zh-CN');
      
      console.log('\n═══════════════════════════════════════════════════');
      console.log(`📅 ${timestamp}`);
      console.log(`📦 [上架事件] NFT Listed`);
      console.log(`├─ 区块号: ${blockNumber}`);
      console.log(`├─ 交易哈希: ${transactionHash}`);
      console.log(`├─ 卖家: ${formatAddress(args.seller)}`);
      console.log(`├─ Token ID: ${args.tokenId.toString()}`);
      console.log(`└─ 价格: ${formatEther(args.price)} MTK`);
      console.log('═══════════════════════════════════════════════════');
    }
  );

  return unwatch;
};

// 监听买卖事件
const listenForSales = async () => {
  console.log('\n🔔 开始监听 NFT 买卖事件...');
  
  const unwatch = watchContractEvent(
    publicClient,
    {
      address: NFT_MARKET_ADDRESS,
      abi: nftMarketAbi,
      eventName: 'NFTSold'
    },
    (event) => {
      const { args, blockNumber, transactionHash } = event;
      const timestamp = new Date().toLocaleString('zh-CN');
      
      console.log('\n═══════════════════════════════════════════════════');
      console.log(`📅 ${timestamp}`);
      console.log(`💰 [买卖事件] NFT Sold`);
      console.log(`├─ 区块号: ${blockNumber}`);
      console.log(`├─ 交易哈希: ${transactionHash}`);
      console.log(`├─ 卖家: ${formatAddress(args.seller)}`);
      console.log(`├─ 买家: ${formatAddress(args.buyer)}`);
      console.log(`├─ Token ID: ${args.tokenId.toString()}`);
      console.log(`└─ 成交价格: ${formatEther(args.price)} MTK`);
      console.log('═══════════════════════════════════════════════════');
    }
  );

  return unwatch;
};

// 监听下架事件
const listenForDelistings = async () => {
  console.log('\n🔔 开始监听 NFT 下架事件...');
  
  const unwatch = watchContractEvent(
    publicClient,
    {
      address: NFT_MARKET_ADDRESS,
      abi: nftMarketAbi,
      eventName: 'NFTDelisted'
    },
    (event) => {
      const { args, blockNumber, transactionHash } = event;
      const timestamp = new Date().toLocaleString('zh-CN');
      
      console.log('\n═══════════════════════════════════════════════════');
      console.log(`📅 ${timestamp}`);
      console.log(`❌ [下架事件] NFT Delisted`);
      console.log(`├─ 区块号: ${blockNumber}`);
      console.log(`├─ 交易哈希: ${transactionHash}`);
      console.log(`├─ 卖家: ${formatAddress(args.seller)}`);
      console.log(`└─ Token ID: ${args.tokenId.toString()}`);
      console.log('═══════════════════════════════════════════════════');
    }
  );

  return unwatch;
};

// 主函数
const main = async () => {
  console.log('==============================================');
  console.log('      NFT Market Event Listener');
  console.log('==============================================');
  console.log(`📡 连接到: ${process.env.RPC_URL || 'http://127.0.0.1:8545'}`);
  console.log(`📄 监听合约: ${NFT_MARKET_ADDRESS}`);
  console.log('==============================================');

  try {
    // 测试连接
    const chainId = await publicClient.getChainId();
    console.log(`✅ 已连接到链 ID: ${chainId}`);

    // 启动所有监听器
    const unwatchers = [
      await listenForListings(),
      await listenForSales(),
      await listenForDelistings()
    ];

    console.log('\n🚀 所有监听器已启动，等待事件...');
    console.log('按 Ctrl+C 停止监听');

    // 处理退出
    process.on('SIGINT', () => {
      console.log('\n\n⏹️ 正在停止监听器...');
      unwatchers.forEach(unwatch => unwatch());
      console.log('✅ 已停止所有监听器');
      process.exit(0);
    });

  } catch (error) {
    console.error('❌ 启动失败:', error.message);
    process.exit(1);
  }
};

main();