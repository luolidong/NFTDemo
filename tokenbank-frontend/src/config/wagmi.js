import { createConfig, http } from 'wagmi';
import { mainnet, sepolia } from '@reown/appkit/networks';
import { injected, walletConnect, coinbaseWallet } from 'wagmi/connectors';
import appConfig from './index.js';

const anvil = {
  ...mainnet,
  id: 31337,
  name: 'Anvil',
  nativeCurrency: { name: 'Anvil Local', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] },
    public: { http: ['http://127.0.0.1:8545'] },
  },
  blockExplorers: {
    default: { name: 'Anvil Explorer', url: 'http://127.0.0.1:8545' },
  },
  testnet: true,
};

export const wagmiConfig = createConfig({
  chains: [anvil, sepolia, mainnet],
  connectors: [
    injected(),
    coinbaseWallet({
      appName: appConfig.appName,
    }),
    walletConnect({
      projectId: appConfig.walletConnectProjectId,
      metadata: {
        name: appConfig.appName,
        description: 'TokenBank DApp',
        url: appConfig.appUrl,
        icons: ['https://example.com/favicon.ico'],
      },
    }),
  ],
  transports: {
    [anvil.id]: http(),
    [mainnet.id]: http(),
    [sepolia.id]: http(),
  },
});

export const networks = [sepolia, anvil, mainnet];
