import { useState, useEffect } from 'react'
import { createPublicClient, createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { localhost } from 'viem/chains'

const COUNTER_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3'

const counterABI = [
  {
    "inputs": [],
    "name": "increment",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "number",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "newNumber",
        "type": "uint256"
      }
    ],
    "name": "setNumber",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]

const account = privateKeyToAccount('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80')

const publicClient = createPublicClient({
  chain: localhost,
  transport: http('http://127.0.0.1:8545'),
})

const walletClient = createWalletClient({
  account,
  chain: localhost,
  transport: http('http://127.0.0.1:8545'),
})

function App() {
  const [number, setNumber] = useState(null)
  const [inputValue, setInputValue] = useState('')
  const [status, setStatus] = useState('')
  const [txHash, setTxHash] = useState(null)
  const [isLoading, setIsLoading] = useState(false)
  const [isConnected, setIsConnected] = useState(false)

  useEffect(() => {
    checkConnection()
    fetchNumber()
  }, [])

  const checkConnection = async () => {
    try {
      await publicClient.getBlockNumber()
      setIsConnected(true)
    } catch {
      setIsConnected(false)
    }
  }

  const fetchNumber = async () => {
    if (!isConnected) return
    
    try {
      setIsLoading(true)
      const result = await publicClient.readContract({
        address: COUNTER_ADDRESS,
        abi: counterABI,
        functionName: 'number',
      })
      setNumber(result.toString())
    } catch (error) {
      console.error('读取失败:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const handleSetNumber = async () => {
    if (!inputValue || !isConnected) return
    
    try {
      setIsLoading(true)
      setStatus('pending')
      
      const hash = await walletClient.writeContract({
        address: COUNTER_ADDRESS,
        abi: counterABI,
        functionName: 'setNumber',
        args: [BigInt(inputValue)],
      })
      
      setTxHash(hash)
      setStatus('success')
      setInputValue('')
      
      await publicClient.waitForTransactionReceipt({ hash })
      await fetchNumber()
    } catch (error) {
      setStatus('error')
      console.error('交易失败:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const handleIncrement = async () => {
    if (!isConnected) return
    
    try {
      setIsLoading(true)
      setStatus('pending')
      
      const hash = await walletClient.writeContract({
        address: COUNTER_ADDRESS,
        abi: counterABI,
        functionName: 'increment',
        args: [],
      })
      
      setTxHash(hash)
      setStatus('success')
      
      await publicClient.waitForTransactionReceipt({ hash })
      await fetchNumber()
    } catch (error) {
      setStatus('error')
      console.error('交易失败:', error)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-900 via-purple-900 to-pink-800 flex items-center justify-center p-4">
      <div className="bg-white/10 backdrop-blur-lg rounded-2xl p-8 w-full max-w-md shadow-2xl border border-white/20">
        <div className="text-center mb-6">
          <h1 className="text-3xl font-bold text-white mb-2">Counter</h1>
          <p className="text-gray-300 text-sm">
            {isConnected ? (
              <span className="text-green-400">✓ 已连接到本地节点</span>
            ) : (
              <span className="text-red-400">✗ 未连接到节点</span>
            )}
          </p>
        </div>

        <div className="bg-white/5 rounded-xl p-6 mb-6">
          <p className="text-gray-400 text-sm text-center mb-2">当前数值</p>
          <p className="text-5xl font-bold text-center text-white">
            {isLoading ? '...' : number || '-'}
          </p>
        </div>

        {status === 'pending' && (
          <div className="bg-yellow-500/20 border border-yellow-500/50 rounded-lg p-3 mb-4 flex items-center gap-2">
            <div className="w-4 h-4 border-2 border-yellow-400 border-t-transparent rounded-full animate-spin"></div>
            <span className="text-yellow-300 text-sm">交易处理中...</span>
          </div>
        )}

        {status === 'success' && txHash && (
          <div className="bg-green-500/20 border border-green-500/50 rounded-lg p-3 mb-4">
            <p className="text-green-300 text-sm">
              ✓ 交易成功! Hash: {txHash.slice(0, 10)}...
            </p>
          </div>
        )}

        {status === 'error' && (
          <div className="bg-red-500/20 border border-red-500/50 rounded-lg p-3 mb-4">
            <p className="text-red-300 text-sm">✗ 交易失败，请重试</p>
          </div>
        )}

        <div className="space-y-3">
          <div className="flex gap-2">
            <input
              type="number"
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              placeholder="输入数值"
              className="flex-1 px-4 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-purple-500"
              disabled={!isConnected}
            />
            <button
              onClick={handleSetNumber}
              disabled={!inputValue || isLoading || !isConnected}
              className="px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white font-semibold rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              设置
            </button>
          </div>

          <button
            onClick={handleIncrement}
            disabled={isLoading || !isConnected}
            className="w-full py-3 bg-gradient-to-r from-pink-500 to-orange-500 hover:from-pink-600 hover:to-orange-600 text-white font-bold rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          >
            +1 递增
          </button>
        </div>

        <div className="mt-6 text-center">
          <p className="text-gray-400 text-xs">
            合约地址: {COUNTER_ADDRESS}
          </p>
          <p className="text-gray-500 text-xs mt-1">
            账户: {account.address.slice(0, 6)}...{account.address.slice(-4)}
          </p>
        </div>
      </div>
    </div>
  )
}

export default App
