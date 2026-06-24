export const TokenBankABI = [
  {
    "inputs": [{"name": "_tokenAddress", "type": "address"}, {"name": "_permit2Address", "type": "address"}],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [{"name": "_permit2Address", "type": "address"}],
    "name": "setPermit2",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"name": "_amount", "type": "uint256"}],
    "name": "deposit",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"name": "_amount", "type": "uint256"},
      {"name": "_deadline", "type": "uint256"},
      {"name": "_v", "type": "uint8"},
      {"name": "_r", "type": "bytes32"},
      {"name": "_s", "type": "bytes32"}
    ],
    "name": "permitDeposit",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getBalance",
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"name": "_user", "type": "address"}],
    "name": "getUserDeposit",
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "permit2",
    "outputs": [{"name": "", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {"components": [
        {"name": "permitted", "type": "address"},
        {"name": "spender", "type": "address"},
        {"name": "amount", "type": "uint256"},
        {"name": "expiration", "type": "uint256"},
        {"name": "nonce", "type": "uint256"}
      ], "name": "_permit", "type": "tuple"},
      {"components": [
        {"name": "to", "type": "address"},
        {"name": "requestedAmount", "type": "uint256"}
      ], "name": "_transferDetails", "type": "tuple"},
      {"name": "_owner", "type": "address"},
      {"name": "_signature", "type": "bytes"}
    ],
    "name": "depositWithPermit2",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "owner",
    "outputs": [{"name": "", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"name": "", "type": "address"}],
    "name": "deposits",
    "outputs": [{"name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "token",
    "outputs": [{"name": "", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "withdraw",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"name": "user", "type": "address"}, {"name": "amount", "type": "uint256"}],
    "name": "Deposit",
    "type": "event"
  },
  {
    "inputs": [{"name": "owner", "type": "address"}, {"name": "amount", "type": "uint256"}],
    "name": "Withdraw",
    "type": "event"
  }
];
