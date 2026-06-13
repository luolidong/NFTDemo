import { useState, useEffect } from 'react';
import { useChainId, useAccount, useDisconnect, useWalletClient, useConnect } from 'wagmi';
import { ethers } from 'ethers';
import { TokenBankABI } from './abi/TokenBank.js';
import { MyTokenABI } from './abi/MyToken.js';
import { Wallet, ArrowUpCircle, ArrowDownCircle, Eye, RefreshCw, LogOut, History } from 'lucide-react';
import { SiweLogin } from './components/SiweLogin.jsx';
import { TransferList } from './components/TransferList.jsx';

import appConfig from './config/index.js';

const TOKEN_BANK_ADDRESS = appConfig.tokenBankAddress;
const MY_TOKEN_ADDRESS = appConfig.myTokenAddress;

function App() {
  const { address, isConnected } = useAccount();
  const { disconnect } = useDisconnect();
  const { data: walletClient } = useWalletClient();
  const { connect, connectors } = useConnect();
  const chainId = useChainId();
  
  const [depositAmount, setDepositAmount] = useState('');
  const [userDeposit, setUserDeposit] = useState('0');
  const [bankBalance, setBankBalance] = useState('0');
  const [userTokenBalance, setUserTokenBalance] = useState('0');
  const [allowance, setAllowance] = useState('0');
  const [isOwner, setIsOwner] = useState(false);
  const [isApproving, setIsApproving] = useState(false);
  const [isDepositing, setIsDepositing] = useState(false);
  const [isWithdrawing, setIsWithdrawing] = useState(false);
  const [message, setMessage] = useState('');
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [showTransferList, setShowTransferList] = useState(false);

  const formatBalance = (balance) => {
    return ethers.formatUnits(balance, 18);
  };

  // 支持的网络 ID: Anvil (31337)
  const isSupportedNetwork = chainId === 31337;

  const fetchData = async () => {
    if (!address || !isSupportedNetwork || !walletClient) return;

    try {
      const provider = new ethers.BrowserProvider(walletClient);
      const signer = await provider.getSigner();

      const tokenContract = new ethers.Contract(MY_TOKEN_ADDRESS, MyTokenABI, signer);
      const bankContract = new ethers.Contract(TOKEN_BANK_ADDRESS, TokenBankABI, signer);

      const [userBal, bankBal, userDep, owner, allow] = await Promise.all([
        tokenContract.balanceOf(address),
        tokenContract.balanceOf(TOKEN_BANK_ADDRESS),
        bankContract.getUserDeposit(address),
        bankContract.owner(),
        tokenContract.allowance(address, TOKEN_BANK_ADDRESS),
      ]);

      setUserTokenBalance(formatBalance(userBal));
      setBankBalance(formatBalance(bankBal));
      setUserDeposit(formatBalance(userDep));
      setIsOwner(owner.toLowerCase() === address.toLowerCase());
      setAllowance(formatBalance(allow));
    } catch (error) {
      console.error('Error fetching data:', error);
      setMessage('Failed to fetch data');
    }
  };

  useEffect(() => {
    fetchData();
  }, [address, chainId]);

  const handleApprove = async () => {
    if (!address || !depositAmount || !walletClient) return;
    setIsApproving(true);
    setMessage('');

    try {
      const provider = new ethers.BrowserProvider(walletClient);
      const signer = await provider.getSigner();
      const tokenContract = new ethers.Contract(MY_TOKEN_ADDRESS, MyTokenABI, signer);

      const amount = ethers.parseUnits(depositAmount, 18);
      const tx = await tokenContract.approve(TOKEN_BANK_ADDRESS, amount);
      await tx.wait();
      
      setMessage('Approval successful!');
      await fetchData();
    } catch (error) {
      console.error('Approval error:', error);
      setMessage('Approval failed: ' + error.message);
    } finally {
      setIsApproving(false);
    }
  };

  const handleDeposit = async () => {
    if (!address || !depositAmount || !walletClient) return;
    setIsDepositing(true);
    setMessage('');

    try {
      const provider = new ethers.BrowserProvider(walletClient);
      const signer = await provider.getSigner();
      const bankContract = new ethers.Contract(TOKEN_BANK_ADDRESS, TokenBankABI, signer);

      const tx = await bankContract.deposit(ethers.parseUnits(depositAmount, 18));
      await tx.wait();
      
      setMessage('Deposit successful!');
      setDepositAmount('');
      await fetchData();
    } catch (error) {
      console.error('Deposit error:', error);
      setMessage('Deposit failed: ' + error.message);
    } finally {
      setIsDepositing(false);
    }
  };

  const handleWithdraw = async () => {
    if (!address || !isOwner || !walletClient) return;
    setIsWithdrawing(true);
    setMessage('');

    try {
      const provider = new ethers.BrowserProvider(walletClient);
      const signer = await provider.getSigner();
      const bankContract = new ethers.Contract(TOKEN_BANK_ADDRESS, TokenBankABI, signer);

      const tx = await bankContract.withdraw();
      await tx.wait();
      
      setMessage('Withdrawal successful!');
      await fetchData();
    } catch (error) {
      console.error('Withdraw error:', error);
      setMessage('Withdrawal failed: ' + error.message);
    } finally {
      setIsWithdrawing(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 py-8 px-4">
      <div className="max-w-2xl mx-auto">
        <header className="text-center mb-8">
          <div className="flex items-center justify-center gap-3 mb-2">
            <Wallet className="w-10 h-10 text-purple-400" />
            <h1 className="text-3xl font-bold text-white">TokenBank</h1>
          </div>
          <p className="text-gray-400">Securely deposit and manage your tokens</p>
        </header>

        <div className="bg-white/10 backdrop-blur-lg rounded-2xl p-6 shadow-xl">
          <div className="flex justify-between items-center mb-6">
            <div className="flex items-center gap-3">
              {isConnected && (
                <SiweLogin
                  onLogin={(addr) => setIsLoggedIn(true)}
                  onLogout={() => setIsLoggedIn(false)}
                />
              )}
            </div>
            <div className="flex items-center gap-3">
              {isConnected && isLoggedIn && (
                <button
                  onClick={() => setShowTransferList(true)}
                  className="flex items-center gap-2 px-4 py-2 bg-purple-500/20 text-purple-400 rounded-lg hover:bg-purple-500/30 transition-colors"
                >
                  <History className="w-4 h-4" />
                  Transfer History
                </button>
              )}
              {isConnected ? (
                <div className="flex items-center gap-3">
                  <span className="text-white/80 text-sm">
                    {address ? `${address.slice(0, 6)}...${address.slice(-4)}` : ''}
                  </span>
                  <button
                    onClick={() => disconnect()}
                    className="flex items-center gap-2 px-4 py-2 bg-red-500/20 text-red-400 rounded-lg hover:bg-red-500/30 transition-colors"
                  >
                    <LogOut className="w-4 h-4" />
                    Disconnect
                  </button>
                </div>
              ) : (
                <div className="flex gap-3">
                  <button
                    onClick={() => {
                      const injectedConnector = connectors.find(c => c.type === 'injected');
                      if (injectedConnector) {
                        connect({ connector: injectedConnector });
                      }
                    }}
                    className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors"
                  >
                    <Wallet className="w-4 h-4" />
                    MetaMask
                  </button>
                </div>
              )}
            </div>
          </div>

          {chainId !== 31337 && isConnected && (
            <div className="mb-4 p-3 bg-yellow-500/20 text-yellow-400 rounded-lg text-sm">
              Please switch to Anvil network (Chain ID: 31337)
            </div>
          )}

          {isConnected && isSupportedNetwork && (
            <>
              <div className="grid grid-cols-2 gap-4 mb-6">
                <div className="bg-white/5 rounded-xl p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <Eye className="w-4 h-4 text-blue-400" />
                    <span className="text-gray-400 text-sm">Your Balance</span>
                  </div>
                  <p className="text-2xl font-bold text-white">{userTokenBalance} MTK</p>
                </div>
                <div className="bg-white/5 rounded-xl p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <Eye className="w-4 h-4 text-green-400" />
                    <span className="text-gray-400 text-sm">Your Deposit</span>
                  </div>
                  <p className="text-2xl font-bold text-white">{userDeposit} MTK</p>
                </div>
                <div className="bg-white/5 rounded-xl p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <Eye className="w-4 h-4 text-purple-400" />
                    <span className="text-gray-400 text-sm">Bank Balance</span>
                  </div>
                  <p className="text-2xl font-bold text-white">{bankBalance} MTK</p>
                </div>
                <div className="bg-white/5 rounded-xl p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <RefreshCw className="w-4 h-4 text-orange-400" />
                    <span className="text-gray-400 text-sm">Allowance</span>
                  </div>
                  <p className="text-2xl font-bold text-white">{allowance} MTK</p>
                </div>
              </div>

              {message && (
                <div className={`mb-4 p-3 rounded-lg text-sm ${
                  message.includes('success') ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'
                }`}>
                  {message}
                </div>
              )}

              <div className="bg-white/5 rounded-xl p-4 mb-4">
                <h3 className="text-white font-semibold mb-3">Deposit Tokens</h3>
                <div className="flex gap-3">
                  <input
                    type="number"
                    value={depositAmount}
                    onChange={(e) => setDepositAmount(e.target.value)}
                    placeholder="Enter amount"
                    className="flex-1 bg-white/10 border border-white/20 rounded-lg px-4 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-purple-400"
                  />
                  <button
                    onClick={handleApprove}
                    disabled={isApproving || !depositAmount}
                    className="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors disabled:opacity-50"
                  >
                    {isApproving ? 'Approving...' : 'Approve'}
                  </button>
                  <button
                    onClick={handleDeposit}
                    disabled={isDepositing || !depositAmount || parseFloat(allowance) < parseFloat(depositAmount)}
                    className="flex items-center gap-1 px-4 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 transition-colors disabled:opacity-50"
                  >
                    <ArrowUpCircle className="w-4 h-4" />
                    Deposit
                  </button>
                </div>
              </div>

              {isOwner && (
                <div className="bg-white/5 rounded-xl p-4">
                  <h3 className="text-white font-semibold mb-3">Owner Actions</h3>
                  <button
                    onClick={handleWithdraw}
                    disabled={isWithdrawing || parseFloat(bankBalance) <= 0}
                    className="flex items-center gap-2 w-full px-4 py-3 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-colors disabled:opacity-50"
                  >
                    <ArrowDownCircle className="w-5 h-5" />
                    {isWithdrawing ? 'Withdrawing...' : `Withdraw All (${bankBalance} MTK)`}
                  </button>
                </div>
              )}
            </>
          )}

          {!isConnected && (
            <div className="text-center py-12">
              <Wallet className="w-16 h-16 text-purple-400 mx-auto mb-4 opacity-50" />
              <p className="text-gray-400">Connect your wallet to use TokenBank</p>
              <p className="text-gray-500 text-sm mt-2">Powered by Reown AppKit</p>
            </div>
          )}
        </div>

        <footer className="text-center mt-8 text-gray-500 text-sm">
          <p>TokenBank - Secure Token Management</p>
        </footer>
      </div>

      {/* Transfer List Modal */}
      {showTransferList && address && (
        <TransferList
          address={address}
          onClose={() => setShowTransferList(false)}
        />
      )}
    </div>
  );
}

export default App;
