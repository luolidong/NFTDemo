/**
 * 使用 Viem 通过 getStorageAt 读取 esRNT 合约中 _locks 数组的所有元素
 * 
 * 合约存储布局说明：
 * - esRNT 合约的 _locks 动态数组位于 slot 0
 * - Slot 0 存储数组长度（uint256）
 * - 数组数据从 keccak256(keccak256(slot)) 开始存储
 * - LockInfo 结构体布局：
 *   - address user (20 bytes) + uint64 startTime (8 bytes) = 28 bytes，打包存储在同一个 slot
 *   - uint256 amount (32 bytes)，独占一个 slot
 * - 因此每个 LockInfo 元素占用 2 个连续的 slot
 */

import { createPublicClient, http, keccak256, toHex, encodeAbiParameters, hexToBigInt } from 'viem';
import { anvil } from 'viem/chains';

async function main() {
    // 创建 Viem 公开客户端，连接到本地 Anvil 节点
    const client = createPublicClient({
        chain: anvil,
        transport: http("http://127.0.0.1:8545"),
    });

    // esRNT 合约部署地址（Anvil 上部署的默认地址）
    const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3" as const;

    // ============================================
    // 步骤1：读取数组长度（slot 0）
    // ============================================
    // 在 Solidity 中，动态数组的长度存储在数组变量声明时的 slot 位置
    // _locks 位于 slot 0，所以 slot 0 存储的是数组长度（uint256）
    const arrayLengthHex = await client.getStorageAt({
        address: contractAddress,
        slot: "0x0",
    });
    const arrayLength = hexToBigInt(arrayLengthHex || "0x0");
    console.log(`_locks 数组长度: ${arrayLength}\n`);

    // ============================================
    // 步骤2：计算数组数据的起始 slot
    // ============================================
    // 动态数组的数据存储位置由公式决定：
    // data[n] 存储在 keccak256(keccak256(var_slot)) + n * element_size
    // 其中 var_slot 是数组变量所在的 slot（这里是 0）
    //
    // keccak256(0) 的计算：
    // 1. 先将 slot 编号编码为 32 字节的 uint256：abi.encode(0) = 0x0000...0000 (64个字符)
    // 2. 对编码结果计算 keccak256 哈希
    const slot0Packed = encodeAbiParameters([{ type: 'uint256' }], [0n]);
    // slot0Packed = "0x0000000000000000000000000000000000000000000000000000000000000000"
    
    // 计算 keccak256(slot 0 的编码值)，得到数据存储的起始位置
    const baseSlot = hexToBigInt(keccak256(slot0Packed));
    // baseSlot = 18569430475105882587588266137607568536673111973893...

    // ============================================
    // 步骤3：遍历读取每个数组元素
    // ============================================
    // LockInfo 结构体在 slot 中的布局：
    // - packedSlot (baseSlot + i*2): 存储 [padding][startTime][user]
    //   - 前 4 字节（字节0-3）：0x0000 填充
    //   - 中间 8 字节（字节4-11）：startTime (uint64)
    //   - 后 20 字节（字节12-31）：user (address)
    // - amountSlot (baseSlot + i*2 + 1): 存储完整的 uint256 amount

    for (let i = 0n; i < arrayLength; i++) {
        // 计算当前元素 i 的两个 slot 位置
        const packedSlot = toHex(baseSlot + i * 2n, { size: 32 });    // user + startTime
        const amountSlot = toHex(baseSlot + i * 2n + 1n, { size: 32 }); // amount

        // 并行读取两个 slot 的数据
        const [packedData, amountData] = await Promise.all([
            client.getStorageAt({ address: contractAddress, slot: packedSlot }),
            client.getStorageAt({ address: contractAddress, slot: amountSlot }),
        ]);

        // ============================================
        // 步骤4：解码 packed slot 数据
        // ============================================
        // packedData 格式（32 字节 = 64 个十六进制字符）：
        // 0xAAAAAAAABBBBBBBBCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
        // └─────┬─────┘└─────┬─────┘└───────────────────────┬───────────────────┘
        //     字节0-3      字节4-11                    字节12-31
        //    填充(4字节)   startTime(8字节)              user(20字节)

        // 确保 packedData 存在，默认为全 0
        const packedHex = (packedData || "0x" + "0".repeat(64)).slice(2);
        const amountHex = amountData || "0x0";

        // 解码 user 地址：取最后 20 字节（最后 40 个十六进制字符）
        const userHex = packedHex.slice(-40);
        const user = "0x" + userHex;

        // 解码 startTime：取字节 8-11（十六进制位置 16-24）
        // startTime 是 uint64，在 slot 中占据 8 字节，但实际存储时只用了 4 字节（uint32）
        // 这导致 startTime 值被当作 uint32 处理，实际值 = 原始 uint64 的低 32 位
        const startTimeHex = packedHex.slice(16, 24); // 字节 8-11
        const startTime = BigInt("0x" + startTimeHex);

        // 解码 amount：完整的 32 字节 uint256
        const amount = hexToBigInt(amountHex);

        // 打印结果
        console.log(`locks[${i}]: user: ${user}, startTime: ${startTime}, amount: ${amount}`);
    }
}

// 执行主函数并捕获错误
main().catch(console.error);
