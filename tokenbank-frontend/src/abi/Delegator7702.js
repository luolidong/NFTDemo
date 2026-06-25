export const Delegator7702ABI = [
  {
    "inputs": [
      { "name": "target", "type": "address" },
      { "name": "data", "type": "bytes" }
    ],
    "name": "execute",
    "outputs": [{"name": "result", "type": "bytes"}],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "name": "target", "type": "address" },
      { "name": "data", "type": "bytes" },
      { "name": "value", "type": "uint256" }
    ],
    "name": "execute",
    "outputs": [{"name": "result", "type": "bytes"}],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "components": [
          { "name": "target", "type": "address" },
          { "name": "allowFailure", "type": "bool" },
          { "name": "callData", "type": "bytes" }
        ],
        "name": "calls",
        "type": "tuple[]"
      }
    ],
    "name": "aggregate3",
    "outputs": [
      {
        "components": [
          { "name": "success", "type": "bool" },
          { "name": "returnData", "type": "bytes" }
        ],
        "name": "",
        "type": "tuple[]"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "name",
    "outputs": [{"name": "", "type": "string"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "version",
    "outputs": [{"name": "", "type": "string"}],
    "stateMutability": "view",
    "type": "function"
  }
];