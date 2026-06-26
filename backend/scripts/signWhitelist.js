// SPDX-License-Identifier: MIT
/**
 * 项目方后端签名代码示例
 * 
 * 此代码展示如何为 NFTMarket2 合约生成白名单签名
 * 
 * 使用方法：
 * 1. 配置签名者私钥（从安全的地方获取）
 * 2. 配置市场合约地址
 * 3. 调用 generateWhitelistSignature 函数生成签名
 * 4. 将签名返回给前端，前端调用 permitBuy
 */

const { ethers } = require('ethers');

// 配置信息
const CONFIG = {
    // 签名者私钥（实际项目中应该从环境变量或安全存储中获取）
    SIGNER_PRIVATE_KEY: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
    
    // NFTMarket2 合约地址
    MARKET_ADDRESS: '0x...', // 替换为实际合约地址
    
    // 链 ID
    CHAIN_ID: 1, // Ethereum Mainnet, 其他链请修改
};

// EIP-712 域名定义
const DOMAIN = {
    name: 'NFTMarket2',
    version: '1',
    chainId: CONFIG.CHAIN_ID,
    verifyingContract: CONFIG.MARKET_ADDRESS,
};

// EIP-712 类型定义
const TYPES = {
    PermitBuy: [
        { name: 'buyer', type: 'address' },
        { name: 'tokenId', type: 'uint256' },
        { name: 'price', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
    ],
};

/**
 * 生成白名单签名
 * 
 * @param {string} buyer - 买家地址
 * @param {number|string} tokenId - NFT tokenId
 * @param {number|string} price - 购买价格（wei）
 * @param {number} deadline - 签名截止时间（Unix 时间戳，秒）
 * @returns {Promise<{v: number, r: string, s: string}>} 签名结果
 */
async function generateWhitelistSignature(buyer, tokenId, price, deadline) {
    // 创建签名者钱包
    const signer = new ethers.Wallet(CONFIG.SIGNER_PRIVATE_KEY);
    
    // 构造签名消息
    const value = {
        buyer,
        tokenId: BigInt(tokenId),
        price: BigInt(price),
        deadline: BigInt(deadline),
    };
    
    // 签名
    const signature = await signer.signTypedData(DOMAIN, TYPES, value);
    
    // 解析签名为 v, r, s
    const { v, r, s } = ethers.Signature.from(signature);
    
    return {
        v,
        r,
        s,
        // 也可以返回完整的签名（65 字节）
        signature,
    };
}

/**
 * 验证签名（可选，用于测试）
 * 
 * @param {string} buyer - 买家地址
 * @param {number|string} tokenId - NFT tokenId
 * @param {number|string} price - 购买价格
 * @param {number} deadline - 签名截止时间
 * @param {string} signature - 签名
 * @returns {Promise<string>} 恢复的签名者地址
 */
async function verifySignature(buyer, tokenId, price, deadline, signature) {
    const value = {
        buyer,
        tokenId: BigInt(tokenId),
        price: BigInt(price),
        deadline: BigInt(deadline),
    };
    
    const signerAddress = ethers.verifyTypedData(DOMAIN, TYPES, value, signature);
    return signerAddress;
}

// ==================== 使用示例 ====================

async function main() {
    try {
        console.log('🔐 开始生成白名单签名...\n');
        
        // 示例参数
        const buyer = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb';
        const tokenId = 0;
        const price = ethers.parseEther('100'); // 100 代币
        const deadline = Math.floor(Date.now() / 1000) + 86400; // 24 小时后过期
        
        console.log('📝 签名参数:');
        console.log(`   买家地址: ${buyer}`);
        console.log(`   Token ID: ${tokenId}`);
        console.log(`   价格: ${ethers.formatEther(price)} 代币`);
        console.log(`   截止时间: ${new Date(deadline * 1000).toISOString()}\n`);
        
        // 生成签名
        const { v, r, s, signature } = await generateWhitelistSignature(
            buyer,
            tokenId,
            price,
            deadline
        );
        
        console.log('✅ 签名生成成功!');
        console.log(`   v: ${v}`);
        console.log(`   r: ${r}`);
        console.log(`   s: ${s}`);
        console.log(`   完整签名: ${signature}\n`);
        
        // 验证签名（可选）
        const recoveredAddress = await verifySignature(buyer, tokenId, price, deadline, signature);
        const signerAddress = new ethers.Wallet(CONFIG.SIGNER_PRIVATE_KEY).address;
        
        console.log('🔍 签名验证:');
        console.log(`   恢复地址: ${recoveredAddress}`);
        console.log(`   签名者地址: ${signerAddress}`);
        console.log(`   验证结果: ${recoveredAddress.toLowerCase() === signerAddress.toLowerCase() ? '✅ 通过' : '❌ 失败'}\n`);
        
        // 返回前端需要的签名数据
        const frontendData = {
            whitelistDeadline: deadline,
            whitelistSignature: signature, // 或者使用 abi.encodePacked(r, s, v)
        };
        
        console.log('📤 返回给前端的数据:');
        console.log(JSON.stringify(frontendData, null, 2));
        
    } catch (error) {
        console.error('❌ 错误:', error);
    }
}

// ==================== Express API 示例 ====================

/**
 * Express API 端点示例
 * 
 * 前端调用：
 * POST /api/whitelist/sign
 * Body: {
 *   buyer: "0x...",
 *   tokenId: 0,
 *   price: "100000000000000000000"
 * }
 */
const express = require('express');
const app = express();

app.use(express.json());

app.post('/api/whitelist/sign', async (req, res) => {
    try {
        const { buyer, tokenId, price } = req.body;
        
        // 验证参数
        if (!buyer || !ethers.isAddress(buyer)) {
            return res.status(400).json({ error: 'Invalid buyer address' });
        }
        
        if (tokenId === undefined || tokenId < 0) {
            return res.status(400).json({ error: 'Invalid tokenId' });
        }
        
        if (!price || BigInt(price) <= 0) {
            return res.status(400).json({ error: 'Invalid price' });
        }
        
        // 检查买家是否在白名单中（可选）
        // if (!isWhitelisted(buyer)) {
        //     return res.status(403).json({ error: 'Buyer not in whitelist' });
        // }
        
        // 设置签名有效期（例如 24 小时）
        const deadline = Math.floor(Date.now() / 1000) + 86400;
        
        // 生成签名
        const { signature } = await generateWhitelistSignature(
            buyer,
            tokenId,
            price,
            deadline
        );
        
        // 返回签名
        res.json({
            success: true,
            data: {
                whitelistDeadline: deadline,
                whitelistSignature: signature,
            },
        });
        
    } catch (error) {
        console.error('签名生成失败:', error);
        res.status(500).json({ error: 'Failed to generate signature' });
    }
});

// ==================== 导出函数 ====================

module.exports = {
    generateWhitelistSignature,
    verifySignature,
    CONFIG,
    DOMAIN,
    TYPES,
};

// 如果直接运行此文件，执行示例
if (require.main === module) {
    main();
}