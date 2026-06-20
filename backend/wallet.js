#!/usr/bin/env node
/**
 * CLI Wallet - ERC20 Transfer Tool
 *
 * Usage:
 *   node wallet.js --to <address> --amount <amount>
 *
 * Example:
 *   node wallet.js --to 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --amount 100
 */

const { createWalletClient, http, parseEther, formatEther } = require('viem');
const { privateKeyToAccount } = require('viem/accounts');
const fs = require('fs');
const path = require('path');

// Load .env file
function loadEnv() {
  const envPath = path.join(__dirname, '.env');
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf-8');
    const envVars = {};
    envContent.split('\n').forEach(line => {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith('#')) {
        const [key, ...valueParts] = trimmed.split('=');
        if (key && valueParts.length > 0) {
          envVars[key.trim()] = valueParts.join('=').trim();
        }
      }
    });
    return envVars;
  }
  return {};
}

// Parse CLI arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const options = {};

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--to' && i + 1 < args.length) {
      options.to = args[++i];
    } else if (args[i] === '--amount' && i + 1 < args.length) {
      options.amount = args[++i];
    }
  }

  return options;
}

// Main function
async function main() {
  const options = parseArgs();

  if (!options.to || !options.amount) {
    console.error('Usage: node wallet.js --to <address> --amount <amount>');
    console.error('Example: node wallet.js --to 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --amount 100');
    process.exit(1);
  }

  // Load environment variables
  const env = loadEnv();
  const privateKey = env.PRIVATE_KEY;
  const erc20Address = env.ERC20_ADDRESS;
  const rpcUrl = env.RPC_URL || 'http://localhost:8545';

  if (!privateKey || !erc20Address) {
    console.error('Error: PRIVATE_KEY and ERC20_ADDRESS must be set in .env file');
    process.exit(1);
  }

  // Validate address
  if (!/^0x[0-9a-fA-F]{40}$/.test(options.to)) {
    console.error('Error: Invalid recipient address:', options.to);
    process.exit(1);
  }

  // Parse amount (assuming 18 decimals for the token)
  const amount = BigInt(options.amount) * BigInt(10 ** 18);

  console.log('=== CLI Wallet - ERC20 Transfer ===');
  console.log('Network: Anvil (http://localhost:8545)');
  console.log('ERC20 Token:', erc20Address);
  console.log('Recipient:', options.to);
  console.log('Amount:', options.amount, 'MTK');
  console.log('');

  // Create account from private key
  const account = privateKeyToAccount(privateKey);
  console.log('Sender:', account.address);
  console.log('');

  // Create wallet client
  const walletClient = createWalletClient({
    account,
    transport: http(rpcUrl),
    chain: {
      id: 31337,
      name: 'Anvil',
      nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
      rpcUrls: {
        default: { http: [rpcUrl] },
        public: { http: [rpcUrl] },
      },
    },
  });

  // ERC20 transfer function selector: transfer(address,uint256)
  // 0xa9059cbb
  const transferSelector = '0xa9059cbb';
  const recipientAddress = options.to.toLowerCase().replace('0x', '');
  const amountHex = amount.toString(16).padStart(64, '0');
  const data = transferSelector + recipientAddress + amountHex;

  console.log('Building EIP1559 transaction...');
  console.log('Data (function call):', data);

  try {
    // Get sender's balance before transfer
    const balanceOfSelector = '0x70a08231';
    const senderAddressHex = account.address.toLowerCase().replace('0x', '').padStart(64, '0');

    const balanceRead = await walletClient.transport.request({
      method: 'eth_call',
      params: [{
        to: erc20Address,
        data: balanceOfSelector + senderAddressHex
      }],
    });

    const balance = BigInt(balanceRead);
    console.log('Sender balance:', formatEther(balance), 'MTK');

    if (balance < amount) {
      console.error('Error: Insufficient balance');
      process.exit(1);
    }

    // Build EIP1559 transaction
    const hash = await walletClient.sendTransaction({
      to: erc20Address,
      data: data,
      account: account,
      chain: {
        id: 31337,
        name: 'Anvil',
        nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
        rpcUrls: {
          default: { http: [rpcUrl] },
          public: { http: [rpcUrl] },
        },
      },
    });

    console.log('');
    console.log('Transaction submitted!');
    console.log('Transaction Hash:', hash);
    console.log('');
    console.log('Waiting for confirmation...');

    // Wait for receipt
    const receipt = await walletClient.transport.request({
      method: 'eth_waitForTransactionReceipt',
      params: [hash],
    });

    if (receipt.status === '0x1') {
      console.log('Transaction confirmed successfully!');
      console.log('Block Number:', receipt.blockNumber);
      console.log('Gas Used:', receipt.gasUsed.toString());
    } else {
      console.error('Transaction failed!');
      process.exit(1);
    }

    // Show new balance
    const newBalanceRead = await walletClient.transport.request({
      method: 'eth_call',
      params: [{
        to: erc20Address,
        data: balanceOfSelector + senderAddressHex
      }],
    });

    const newBalance = BigInt(newBalanceRead);
    console.log('');
    console.log('=== Transfer Complete ===');
    console.log('New Balance:', formatEther(newBalance), 'MTK');

  } catch (error) {
    console.error('Error:', error.message || error);
    process.exit(1);
  }
}

main();
