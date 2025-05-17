import { useState } from 'react'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import TokenVerification from './components/TokenVerification'
import WithdrawRequestList from './components/WithdrawRequestList'

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
            <WithdrawRequestList tokenAddress={tokenAddress} />
          )}
        </main>
      </div>
    </div>
  )
}

export default App 