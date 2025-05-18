import { useState } from 'react'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import TokenVerification from './components/TokenVerification'
import WithdrawRequestList from './components/WithdrawRequestList'
import WrapperOperations from './components/WrapperOperations'

function App() {
  const [isVerified, setIsVerified] = useState(false)
  const [tokenAddress, setTokenAddress] = useState('')

  return (
    <div className="min-h-screen bg-gray-100 dark:bg-gray-900 py-8">
      <div className="container mx-auto px-4">
        <header className="mb-8">
          <div className="flex justify-between items-center">
            <h1 className="text-3xl font-bold text-gray-900 dark:text-white">
              DisputeGame DApp
            </h1>
            <ConnectButton />
          </div>
        </header>

        <main>
          {!isVerified ? (
            <TokenVerification 
              onVerify={(verified, address) => {
                setIsVerified(verified)
                setTokenAddress(address)
              }}
            />
          ) : (
            <div className="flex flex-col md:flex-row gap-6">
              {/* 左侧 Wrapper 操作区域 (1/3宽度) */}
              <div className="w-full md:w-1/3">
                <WrapperOperations />
              </div>
              
              {/* 右侧提款请求列表区域 (2/3宽度) */}
              <div className="w-full md:w-2/3">
                <WithdrawRequestList tokenAddress={tokenAddress} />
              </div>
            </div>
          )}
        </main>
      </div>
    </div>
  )
}

export default App 