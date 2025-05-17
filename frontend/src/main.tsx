import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'
import { configureChains, createConfig, WagmiConfig } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { alchemyProvider } from 'wagmi/providers/alchemy'
import { publicProvider } from 'wagmi/providers/public'
import { getDefaultWallets, RainbowKitProvider } from '@rainbow-me/rainbowkit'
import '@rainbow-me/rainbowkit/styles.css'

// 配置链和提供商
const { chains, publicClient } = configureChains(
  [sepolia],
  [
    // 使用环境变量中的Alchemy API密钥
    alchemyProvider({ apiKey: import.meta.env.VITE_ALCHEMY_API_KEY || 'demo' }), 
    publicProvider()
  ]
)

// 配置RainbowKit和Wagmi
const { connectors } = getDefaultWallets({
  appName: 'DisputeGame DApp',
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || 'demo', // 使用环境变量中的WalletConnect项目ID
  chains
})

const wagmiConfig = createConfig({
  autoConnect: true,
  connectors,
  publicClient
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <WagmiConfig config={wagmiConfig}>
      <RainbowKitProvider chains={chains}>
        <App />
      </RainbowKitProvider>
    </WagmiConfig>
  </React.StrictMode>,
) 