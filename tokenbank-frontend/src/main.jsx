import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { createAppKit } from '@reown/appkit/react';
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi';
import './index.css';
import App from './App.jsx';
import appConfig from './config/index.js';
import { wagmiConfig, networks } from './config/wagmi.js';

const queryClient = new QueryClient();

const wagmiAdapter = new WagmiAdapter({
  networks,
  projectId: appConfig.walletConnectProjectId,
  ssr: true
});

createAppKit({
  adapters: [wagmiAdapter],
  networks,
  projectId: appConfig.walletConnectProjectId,
  metadata: {
    name: appConfig.appName,
    description: 'TokenBank DApp',
    url: appConfig.appUrl,
    icons: ['https://example.com/favicon.ico']
  },
  features: {
    analytics: false
  },
  enableWallets: true,
  featuredWalletIds: [
    'c57ca95b47569778a828d19178114f4db188b89b763c899ba0be274e97267d96', // MetaMask
  ],
  debug: true
});

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <App />
      </QueryClientProvider>
    </WagmiProvider>
  </StrictMode>,
);
