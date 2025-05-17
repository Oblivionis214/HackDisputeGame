import { useState, FormEvent } from 'react'
import { useAccount } from 'wagmi'

interface TokenVerificationProps {
  onVerify: (verified: boolean, address: string) => void
}

const REGISTERED_TOKEN_ADDRESS = '0x1df44B5C1160fca5AE1d9430D221A6c39CCEd00D'

const TokenVerification = ({ onVerify }: TokenVerificationProps) => {
  const [tokenAddress, setTokenAddress] = useState('')
  const [error, setError] = useState('')
  const { isConnected } = useAccount()

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault()
    
    if (!isConnected) {
      setError('请先连接钱包')
      return
    }

    if (!tokenAddress) {
      setError('请输入Token地址')
      return
    }

    // 验证地址格式
    if (!/^0x[a-fA-F0-9]{40}$/.test(tokenAddress)) {
      setError('无效的以太坊地址格式')
      return
    }

    // 验证是否是注册的Token地址
    if (tokenAddress.toLowerCase() === REGISTERED_TOKEN_ADDRESS.toLowerCase()) {
      onVerify(true, tokenAddress)
    } else {
      setError('地址未注册')
    }
  }

  return (
    <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
      <h2 className="text-xl font-semibold mb-4 text-gray-900 dark:text-white">验证Token地址</h2>
      
      <form onSubmit={handleSubmit}>
        <div className="mb-4">
          <label htmlFor="tokenAddress" className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            Token地址
          </label>
          <input
            id="tokenAddress"
            type="text"
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-700 dark:text-white"
            placeholder="请输入Token地址 (0x...)"
            value={tokenAddress}
            onChange={(e) => setTokenAddress(e.target.value)}
          />
        </div>

        {error && (
          <div className="mb-4 text-red-500 text-sm">
            {error}
          </div>
        )}

        <button
          type="submit"
          className="w-full bg-indigo-600 text-white py-2 px-4 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          disabled={!isConnected}
        >
          验证
        </button>
        
        {!isConnected && (
          <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">
            请先连接您的钱包
          </p>
        )}
      </form>
    </div>
  )
}

export default TokenVerification 