import { useState } from 'react';
import { useAccount, useSignMessage } from 'wagmi';
import { SiweMessage } from 'siwe';
import { Wallet, LogOut } from 'lucide-react';

const BACKEND_URL = 'http://localhost:3001';

export function SiweLogin({ onLogin, onLogout }) {
  const { address, isConnected } = useAccount();
  const { signMessageAsync } = useSignMessage();
  const [isLoggingIn, setIsLoggingIn] = useState(false);
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [error, setError] = useState('');

  const handleLogin = async () => {
    if (!address || !isConnected) {
      setError('Please connect wallet first');
      return;
    }

    setIsLoggingIn(true);
    setError('');

    try {
      // 1. Get nonce from backend (需要携带 credentials 以保存 session cookie)
      const nonceRes = await fetch(`${BACKEND_URL}/api/nonce`, {
        credentials: 'include',
      });
      const { nonce } = await nonceRes.json();

      // 2. Create SIWE message
      const message = new SiweMessage({
        domain: window.location.host,
        address: address,
        statement: 'Sign in with Ethereum to the TokenBank.',
        uri: window.location.origin,
        version: '1',
        chainId: 31337,
        nonce: nonce,
      });

      const messageStr = message.prepareMessage();

      // 3. Sign message
      const signature = await signMessageAsync({ message: messageStr });

      // 4. Verify signature with backend
      const verifyRes = await fetch(`${BACKEND_URL}/api/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          message: message,
          signature: signature,
        }),
      });

      const verifyData = await verifyRes.json();

      if (verifyRes.ok && verifyData.success) {
        setIsLoggedIn(true);
        onLogin && onLogin(address);
      } else {
        setError(verifyData.error || 'Verification failed');
      }
    } catch (err) {
      console.error('SIWE login error:', err);
      setError(err.message || 'Login failed');
    } finally {
      setIsLoggingIn(false);
    }
  };

  const handleLogout = async () => {
    try {
      const res = await fetch(`${BACKEND_URL}/api/logout`, {
        method: 'POST',
        credentials: 'include',
      });

      if (res.ok) {
        setIsLoggedIn(false);
        onLogout && onLogout();
      }
    } catch (err) {
      console.error('Logout error:', err);
    }
  };

  if (!isConnected) {
    return null;
  }

  if (isLoggedIn) {
    return (
      <div className="flex items-center gap-3">
        <span className="text-green-400 text-sm flex items-center gap-2">
          <Wallet className="w-4 h-4" />
          Logged in
        </span>
        <button
          onClick={handleLogout}
          className="flex items-center gap-2 px-4 py-2 bg-red-500/20 text-red-400 rounded-lg hover:bg-red-500/30 transition-colors"
        >
          <LogOut className="w-4 h-4" />
          Logout
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center gap-3">
      <button
        onClick={handleLogin}
        disabled={isLoggingIn}
        className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-purple-500 to-blue-500 text-white rounded-lg hover:from-purple-600 hover:to-blue-600 transition-all disabled:opacity-50"
      >
        <Wallet className="w-5 h-5" />
        {isLoggingIn ? 'Signing...' : 'Sign In with Ethereum'}
      </button>
      {error && (
        <p className="text-red-400 text-sm">{error}</p>
      )}
    </div>
  );
}