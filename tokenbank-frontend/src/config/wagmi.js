import { createConfig, http } from 'wagmi';
import { injected } from 'wagmi/connectors';
import appConfig from './index.js';

const anvil = {
  id: 31337,
  name: 'Anvil Local',
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
  chains: [anvil],
  connectors: [
    injected({ target: 'metaMask' }),
  ],
  transports: {
    [anvil.id]: http('http://127.0.0.1:8545'),
  },
});

export const networks = [anvil];
