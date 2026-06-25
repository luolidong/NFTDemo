import { createPublicClient, http, keccak256, toHex, encodeAbiParameters, hexToBigInt, decodeAbiParameters } from 'viem';
import { anvil } from 'viem/chains';

async function main() {
    const client = createPublicClient({
        chain: anvil,
        transport: http("http://127.0.0.1:8545"),
    });

    const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3" as const;

    // Slot 0 stores the array length for dynamic array _locks
    const arrayLengthHex = await client.getStorageAt({
        address: contractAddress,
        slot: "0x0",
    });
    const arrayLength = hexToBigInt(arrayLengthHex || "0x0");
    console.log(`_locks array length: ${arrayLength}\n`);

    // For dynamic array _locks at slot 0:
    // The array length is at slot 0
    // Array data starts at keccak256(keccak256(slot)) for the base, but due to collision we use keccak256(slot)
    // Actually, for dynamic array at slot s: data[n] is at keccak256(keccak256(s)) + n * structSize
    
    // Wait, the correct formula is: keccak256(abi.encode(slot)) for the starting position
    const slot0Packed = encodeAbiParameters([{ type: 'uint256' }], [0n]);
    const baseSlot = hexToBigInt(keccak256(slot0Packed));

    // LockInfo struct layout:
    // - address user (20 bytes) + uint64 startTime (8 bytes) are packed into 28 bytes -> first slot
    // - uint256 amount (32 bytes) -> second slot
    // So each element uses 2 slots

    for (let i = 0n; i < arrayLength; i++) {
        // For element i, the packed slot is baseSlot + i * 2
        const packedSlot = toHex(baseSlot + i * 2n, { size: 32 });
        const amountSlot = toHex(baseSlot + i * 2n + 1n, { size: 32 });

        const [packedData, amountData] = await Promise.all([
            client.getStorageAt({ address: contractAddress, slot: packedSlot }),
            client.getStorageAt({ address: contractAddress, slot: amountSlot }),
        ]);

        // Decode the packed data
        // The packed slot contains: [padding 4 bytes][startTime 8 bytes][user 20 bytes]
        // But looking at the actual data layout, it's: [0x0000][startTime][user]
        // Actually, address is stored in the LAST 20 bytes
        
        const packedHex = (packedData || "0x" + "0".repeat(64)).slice(2);
        const amountHex = amountData || "0x0";
        
        // User address is last 20 bytes (40 hex chars)
        const userHex = packedHex.slice(-40);
        const user = "0x" + userHex;
        
        // StartTime - looking at the data pattern, it appears to be at bytes 4-11 (8 bytes)
        // But actually the data shows startTime in bytes 8-11 (4 bytes) as uint32
        // The uint64 startTime occupies bytes 8-11 (LSB) with the actual value d47a8cee
        // This suggests Solidity is storing uint64 as uint32 due to how the struct is laid out
        const startTimeHex = packedHex.slice(16, 24); // bytes 8-11
        const startTime = BigInt("0x" + startTimeHex);
        
        const amount = hexToBigInt(amountHex);

        console.log(`locks[${i}]: user: ${user}, startTime: ${startTime}, amount: ${amount}`);
    }
}

main().catch(console.error);
