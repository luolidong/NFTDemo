import { useState, useEffect } from 'react';
import { ArrowUpCircle, ArrowDownCircle, RefreshCw, X } from 'lucide-react';

const BACKEND_URL = 'http://localhost:3001';

export function TransferList({ address, onClose }) {
  const [transfers, setTransfers] = useState([]);
  const [stats, setStats] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [type, setType] = useState('all'); // all, sent, received

  const fetchTransfers = async () => {
    if (!address) return;

    setIsLoading(true);
    setError('');

    console.log('\n🔍 查询转账记录...');
    console.log('地址:', address);
    console.log('类型:', type);

    try {
      const res = await fetch(`${BACKEND_URL}/api/transfers/${address}?type=${type}&limit=20`, {
        credentials: 'include',
      });

      console.log('响应状态:', res.status);

      if (!res.ok) {
        const data = await res.json();
        console.error('错误:', data);
        throw new Error(data.error || 'Failed to fetch transfers');
      }

      const data = await res.json();
      console.log('转账记录:', data.transfers);
      console.log('总数:', data.total);
      setTransfers(data.transfers);
    } catch (err) {
      console.error('Fetch transfers error:', err);
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  };

  const fetchStats = async () => {
    if (!address) return;

    try {
      const res = await fetch(`${BACKEND_URL}/api/transfers/${address}/stats`, {
        credentials: 'include',
      });

      if (res.ok) {
        const data = await res.json();
        setStats(data);
      }
    } catch (err) {
      console.error('Fetch stats error:', err);
    }
  };

  useEffect(() => {
    fetchTransfers();
    fetchStats();
  }, [address, type]);

  const formatDate = (timestamp) => {
    return new Date(timestamp).toLocaleString();
  };

  const formatAddress = (addr) => {
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
      <div className="bg-slate-900 rounded-2xl p-6 max-w-2xl w-full mx-4 max-h-[80vh] overflow-y-auto">
        <div className="flex justify-between items-center mb-6">
          <h2 className="text-2xl font-bold text-white flex items-center gap-2">
            <RefreshCw className="w-6 h-6 text-purple-400" />
            Transfer History
          </h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {stats && (
          <div className="grid grid-cols-2 gap-4 mb-6">
            <div className="bg-white/5 rounded-xl p-4">
              <div className="flex items-center gap-2 mb-2">
                <ArrowUpCircle className="w-4 h-4 text-red-400" />
                <span className="text-gray-400 text-sm">Sent</span>
              </div>
              <p className="text-xl font-bold text-white">{stats.sent.totalFormatted} MTK</p>
              <p className="text-gray-500 text-sm">{stats.sent.count} transactions</p>
            </div>
            <div className="bg-white/5 rounded-xl p-4">
              <div className="flex items-center gap-2 mb-2">
                <ArrowDownCircle className="w-4 h-4 text-green-400" />
                <span className="text-gray-400 text-sm">Received</span>
              </div>
              <p className="text-xl font-bold text-white">{stats.received.totalFormatted} MTK</p>
              <p className="text-gray-500 text-sm">{stats.received.count} transactions</p>
            </div>
          </div>
        )}

        <div className="flex gap-2 mb-4">
          <button
            onClick={() => setType('all')}
            className={`px-4 py-2 rounded-lg transition-colors ${
              type === 'all' ? 'bg-purple-500 text-white' : 'bg-white/10 text-gray-400 hover:bg-white/20'
            }`}
          >
            All
          </button>
          <button
            onClick={() => setType('sent')}
            className={`px-4 py-2 rounded-lg transition-colors ${
              type === 'sent' ? 'bg-purple-500 text-white' : 'bg-white/10 text-gray-400 hover:bg-white/20'
            }`}
          >
            Sent
          </button>
          <button
            onClick={() => setType('received')}
            className={`px-4 py-2 rounded-lg transition-colors ${
              type === 'received' ? 'bg-purple-500 text-white' : 'bg-white/10 text-gray-400 hover:bg-white/20'
            }`}
          >
            Received
          </button>
        </div>

        {error && (
          <div className="mb-4 p-3 bg-red-500/20 text-red-400 rounded-lg">
            {error}
          </div>
        )}

        {isLoading ? (
          <div className="text-center py-8">
            <RefreshCw className="w-8 h-8 text-purple-400 animate-spin mx-auto mb-2" />
            <p className="text-gray-400">Loading...</p>
          </div>
        ) : transfers.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-gray-400">No transfer records found</p>
          </div>
        ) : (
          <div className="space-y-3">
            {transfers.map((transfer) => (
              <div
                key={transfer.id}
                className="bg-white/5 rounded-xl p-4 flex items-center gap-4"
              >
                <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                  transfer.type === 'sent' ? 'bg-red-500/20' : 'bg-green-500/20'
                }`}>
                  {transfer.type === 'sent' ? (
                    <ArrowUpCircle className="w-5 h-5 text-red-400" />
                  ) : (
                    <ArrowDownCircle className="w-5 h-5 text-green-400" />
                  )}
                </div>
                <div className="flex-1">
                  <div className="flex justify-between items-start">
                    <div>
                      <p className="text-white font-semibold">
                        {transfer.type === 'sent' ? 'Sent' : 'Received'} {transfer.valueFormatted} MTK
                      </p>
                      <p className="text-gray-400 text-sm">
                        {transfer.type === 'sent' ? 'To: ' : 'From: '}
                        {formatAddress(transfer.type === 'sent' ? transfer.to : transfer.from)}
                      </p>
                    </div>
                    <div className="text-right">
                      <p className="text-gray-500 text-sm">Block #{transfer.blockNumber}</p>
                      <p className="text-gray-500 text-xs">{formatDate(transfer.timestamp)}</p>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        <button
          onClick={fetchTransfers}
          disabled={isLoading}
          className="mt-4 w-full flex items-center justify-center gap-2 px-4 py-2 bg-purple-500/20 text-purple-400 rounded-lg hover:bg-purple-500/30 transition-colors disabled:opacity-50"
        >
          <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
          Refresh
        </button>
      </div>
    </div>
  );
}