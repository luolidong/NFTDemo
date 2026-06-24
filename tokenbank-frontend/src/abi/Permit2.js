export const Permit2ABI = [
  {
    "inputs": [
      {
        "components": [
          { "name": "permitted", "type": "address" },
          { "name": "spender", "type": "address" },
          { "name": "amount", "type": "uint256" },
          { "name": "expiration", "type": "uint256" },
          { "name": "nonce", "type": "uint256" }
        ],
        "name": "permit",
        "type": "tuple"
      },
      {
        "components": [
          { "name": "to", "type": "address" },
          { "name": "requestedAmount", "type": "uint256" }
        ],
        "name": "transferDetails",
        "type": "tuple"
      },
      { "name": "owner", "type": "address" },
      { "name": "signature", "type": "bytes" }
    ],
    "name": "permitTransferFrom",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "name": "owner", "type": "address" },
      { "name": "token", "type": "address" }
    ],
    "name": "allowance",
    "outputs": [
      {
        "components": [
          { "name": "amount", "type": "uint256" },
          { "name": "expiration", "type": "uint256" }
        ],
        "name": "",
        "type": "tuple"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "name": "owner", "type": "address" },
      { "name": "token", "type": "address" }
    ],
    "name": "nonces",
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "DOMAIN_SEPARATOR",
    "outputs": [{ "name": "", "type": "bytes32" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "PERMIT_TYPEHASH",
    "outputs": [{ "name": "", "type": "bytes32" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "name",
    "outputs": [{ "name": "", "type": "string" }],
    "stateMutability": "view",
    "type": "function"
  }
];
