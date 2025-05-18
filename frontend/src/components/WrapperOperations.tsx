import { useState } from 'react'
import { useAccount, useContractWrite, useContractRead, useBalance } from 'wagmi'
import { parseEther, formatEther } from 'viem'

// ERC20Wrapper ABI
const wrapperABI = [
  {
    "inputs": [
      {"internalType": "uint256", "name": "wad", "type": "uint256"}
    ],
    "name": "deposit",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "wad", "type": "uint256"}
    ],
    "name": "withdraw",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "wad", "type": "uint256"},
      {"internalType": "address", "name": "to", "type": "address"}
    ],
    "name": "withdraw",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "requestId", "type": "uint256"}
    ],
    "name": "redeem",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "underlyingToken",
    "outputs": [{"internalType": "contract IERC20", "name": "", "type": "address"}],
    "stateMutability": "view",
    "type": "function"
  }
]

// ERC20 ABI
const erc20ABI = [
  {
    "inputs": [
      {"internalType": "address", "name": "spender", "type": "address"},
      {"internalType": "uint256", "name": "amount", "type": "uint256"}
    ],
    "name": "approve",
    "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address", "name": "account", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "symbol",
    "outputs": [{"internalType": "string", "name": "", "type": "string"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "decimals",
    "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}],
    "stateMutability": "view",
    "type": "function"
  }
]

// 合约地址 - 放在顶部，确保整个组件都能访问到这些常量
const WRAPPER_ADDRESS = '0x0E5eee2Ae97ED5FDE258fdE27dB3d85c97124bC0' // ERC20Wrapper合约地址
const UNDERLYING_TOKEN_ADDRESS = '0x1df44B5C1160fca5AE1d9430D221A6c39CCEd00D' // 基础代币地址

// 操作类型枚举
type OperationType = 'deposit' | 'withdraw' | 'redeem'

const WrapperOperations = () => {
  const { address } = useAccount()
  const [activeOperation, setActiveOperation] = useState<OperationType>('deposit')
  const [amount, setAmount] = useState('')
  const [recipient, setRecipient] = useState('')
  const [requestId, setRequestId] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)
  
  // 使用固定的基础代币地址，不再从合约查询
  const underlyingTokenAddress = UNDERLYING_TOKEN_ADDRESS
  
  // 获取当前用户的基础代币余额
  const { data: tokenBalanceData } = useContractRead({
    address: underlyingTokenAddress as `0x${string}`,
    abi: erc20ABI,
    functionName: 'balanceOf',
    args: [address as `0x${string}`],
    enabled: !!address,
  })
  
  // 获取基础代币符号
  const { data: rawTokenSymbol } = useContractRead({
    address: underlyingTokenAddress as `0x${string}`,
    abi: erc20ABI,
    functionName: 'symbol',
    enabled: true,
  })
  
  // 确保tokenSymbol是字符串类型
  const tokenSymbol = typeof rawTokenSymbol === 'string' ? rawTokenSymbol : 'tokens'
  
  // 获取当前用户的包装代币余额
  const { data: wrappedTokenBalance } = useBalance({
    address,
    token: WRAPPER_ADDRESS as `0x${string}`,
    enabled: !!address,
  })

  // Approve操作 - 授权基础代币给WRAPPER合约
  const { 
    write: approveToken, 
    isLoading: isApproving,
    isSuccess: isApproveSuccess 
  } = useContractWrite({
    address: underlyingTokenAddress as `0x${string}`,
    abi: erc20ABI,
    functionName: 'approve',
    onSuccess: (data) => {
      console.log('Approve transaction successful:', data)
      setSuccess('Authorization successful! Now you can make a deposit. Transaction hash: ' + data.hash)
      setTimeout(() => setSuccess(null), 10000)
    },
    onError: (err) => {
      console.error('Approve error:', err)
      setError(`Authorization failed: ${err.message}`)
      setTimeout(() => setError(null), 8000)
    }
  })
  
  // Deposit操作 - 调用WRAPPER合约存入基础代币获取包装代币
  const { 
    write: deposit, 
    isLoading: isDepositing,
    isSuccess: isDepositSuccess
  } = useContractWrite({
    address: WRAPPER_ADDRESS,
    abi: wrapperABI,
    functionName: 'deposit',
    onSuccess: (data) => {
      console.log('Deposit transaction successful:', data)
      setSuccess('Deposit successful! Transaction hash: ' + data.hash)
      setAmount('')
      setTimeout(() => setSuccess(null), 10000)
    },
    onError: (err) => {
      console.error('Deposit error:', err)
      setError(`Deposit failed: ${err.message}`)
      setTimeout(() => setError(null), 8000)
    }
  })
  
  // Withdraw操作 (简化版，发送到自己地址) - 调用WRAPPER合约申请提款
  const { 
    write: withdrawSimple, 
    isLoading: isWithdrawingSimple,
    isSuccess: isWithdrawSimpleSuccess 
  } = useContractWrite({
    address: WRAPPER_ADDRESS,
    abi: wrapperABI,
    functionName: 'withdraw',
    onSuccess: (data) => {
      console.log('Withdraw simple transaction successful:', data)
      setSuccess('Withdrawal request submitted! Transaction hash: ' + data.hash)
      setAmount('')
      setTimeout(() => setSuccess(null), 10000)
    },
    onError: (err) => {
      console.error('Withdraw simple error:', err)
      setError(`Withdrawal request failed: ${err.message}`)
      setTimeout(() => setError(null), 8000)
    }
  })
  
  // Withdraw操作 (发送到指定地址) - 调用WRAPPER合约申请提款到指定地址
  const { 
    write: withdrawToAddress, 
    isLoading: isWithdrawingToAddress,
    isSuccess: isWithdrawToAddressSuccess 
  } = useContractWrite({
    address: WRAPPER_ADDRESS,
    abi: wrapperABI,
    functionName: 'withdraw',
    onSuccess: (data) => {
      console.log('Withdraw to address transaction successful:', data)
      setSuccess('Withdrawal request submitted! Transaction hash: ' + data.hash)
      setAmount('')
      setRecipient('')
      setTimeout(() => setSuccess(null), 10000)
    },
    onError: (err) => {
      console.error('Withdraw to address error:', err)
      setError(`Withdrawal request failed: ${err.message}`)
      setTimeout(() => setError(null), 8000)
    }
  })
  
  // Redeem操作 - 调用WRAPPER合约完成已验证的提款请求
  const { 
    write: redeem, 
    isLoading: isRedeeming,
    isSuccess: isRedeemSuccess 
  } = useContractWrite({
    address: WRAPPER_ADDRESS,
    abi: wrapperABI,
    functionName: 'redeem',
    onSuccess: (data) => {
      console.log('Redeem transaction successful:', data)
      setSuccess('Withdrawal completed successfully! Transaction hash: ' + data.hash)
      setRequestId('')
      setTimeout(() => setSuccess(null), 10000)
    },
    onError: (err) => {
      console.error('Redeem error:', err)
      setError(`Withdrawal completion failed: ${err.message}`)
      setTimeout(() => setError(null), 8000)
    }
  })
  
  // 授权代币
  const handleApprove = () => {
    setError(null)
    if (!amount || isNaN(Number(amount)) || Number(amount) <= 0) {
      setError('Please enter a valid amount')
      return
    }
    
    // 确保用户有足够的基础代币余额
    if (tokenBalanceData !== undefined && parseFloat(amount) > parseFloat(formatEther(tokenBalanceData as bigint))) {
      setError(`Insufficient balance. You have ${formatEther(tokenBalanceData as bigint)} ${tokenSymbol}`)
      return
    }
    
    try {
      const amountInWei = parseEther(amount)
      
      // 确保underlyingTokenAddress已加载
      if (!underlyingTokenAddress) {
        setError('Base token address not loaded yet')
        return
      }
      
      console.log('Approving:', {
        token: underlyingTokenAddress,
        spender: WRAPPER_ADDRESS,
        amount: amountInWei.toString()
      })
      
      approveToken({
        args: [WRAPPER_ADDRESS, amountInWei]
      })
    } catch (err) {
      console.error('Approve error:', err)
      setError(`Authorization failed: ${err instanceof Error ? err.message : String(err)}`)
    }
  }
  
  // 处理存款
  const handleDeposit = () => {
    setError(null)
    if (!amount || isNaN(Number(amount)) || Number(amount) <= 0) {
      setError('Please enter a valid amount')
      return
    }
    
    // 确保用户有足够的基础代币余额
    if (tokenBalanceData !== undefined && parseFloat(amount) > parseFloat(formatEther(tokenBalanceData as bigint))) {
      setError(`Insufficient balance. You have ${formatEther(tokenBalanceData as bigint)} ${tokenSymbol}`)
      return
    }
    
    try {
      const amountInWei = parseEther(amount)
      
      console.log('Depositing:', {
        amount: amountInWei.toString()
      })
      
      // 注意：根据合约，deposit 函数只接受一个参数 
      deposit({
        args: [amountInWei]
      })
    } catch (err) {
      console.error('Deposit error:', err)
      setError(`Invalid amount format or operation failed: ${err instanceof Error ? err.message : String(err)}`)
    }
  }
  
  // 处理提款
  const handleWithdraw = () => {
    setError(null)
    if (!amount || isNaN(Number(amount)) || Number(amount) <= 0) {
      setError('Please enter a valid amount')
      return
    }
    
    // 确保用户有足够的包装代币余额
    if (wrappedTokenBalance && parseFloat(amount) > parseFloat(formatEther(wrappedTokenBalance.value))) {
      setError(`Insufficient balance. You have ${formatEther(wrappedTokenBalance.value)} ${wrappedTokenBalance.symbol}`)
      return
    }
    
    try {
      const amountInWei = parseEther(amount)
      
      console.log('Withdrawing:', {
        amount: amountInWei.toString(),
        recipient: recipient || 'self'
      })
      
      if (recipient && recipient.startsWith('0x')) {
        // 提款到指定地址
        withdrawToAddress({
          args: [amountInWei, recipient]
        })
      } else {
        // 提款到自己的地址
        withdrawSimple({
          args: [amountInWei]
        })
      }
    } catch (err) {
      console.error('Withdraw error:', err)
      setError(`Invalid amount format or operation failed: ${err instanceof Error ? err.message : String(err)}`)
    }
  }
  
  // 处理赎回
  const handleRedeem = () => {
    setError(null)
    if (!requestId || isNaN(Number(requestId)) || Number(requestId) < 0) {
      setError('Please enter a valid request ID')
      return
    }
    
    try {
      redeem({
        args: [BigInt(requestId)]
      })
    } catch (err) {
      setError('Invalid request ID format')
    }
  }
  
  return (
    <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
      <h2 className="text-xl font-semibold mb-6 text-gray-900 dark:text-white">Wrapper Operations</h2>
      
      {/* 合约地址信息 */}
      <div className="mb-4 text-xs text-gray-500 dark:text-gray-400">
        <div>Wrapper Contract: {WRAPPER_ADDRESS}</div>
        <div>Token Contract: {UNDERLYING_TOKEN_ADDRESS}</div>
      </div>
      
      {/* 操作类型选择 */}
      <div className="flex mb-6 bg-gray-100 dark:bg-gray-700 rounded-lg p-1">
        <button
          className={`flex-1 py-2 rounded-md text-sm font-medium transition-colors ${
            activeOperation === 'deposit'
              ? 'bg-indigo-600 text-white'
              : 'text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
          }`}
          onClick={() => setActiveOperation('deposit')}
        >
          Deposit
        </button>
        <button
          className={`flex-1 py-2 rounded-md text-sm font-medium transition-colors ${
            activeOperation === 'withdraw'
              ? 'bg-indigo-600 text-white'
              : 'text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
          }`}
          onClick={() => setActiveOperation('withdraw')}
        >
          Withdraw
        </button>
        <button
          className={`flex-1 py-2 rounded-md text-sm font-medium transition-colors ${
            activeOperation === 'redeem'
              ? 'bg-indigo-600 text-white'
              : 'text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
          }`}
          onClick={() => setActiveOperation('redeem')}
        >
          Redeem
        </button>
      </div>
      
      {/* 余额显示 */}
      <div className="mb-6 text-sm text-gray-600 dark:text-gray-400">
        {tokenBalanceData !== undefined && (
          <div className="mb-1">
            Base Token Balance: {formatEther(tokenBalanceData as bigint)} {tokenSymbol}
          </div>
        )}
        {wrappedTokenBalance && (
          <div>
            Wrapped Token Balance: {formatEther(wrappedTokenBalance.value)} {wrappedTokenBalance.symbol}
          </div>
        )}
      </div>
      
      {/* 错误和成功提示 */}
      {error && (
        <div className="mb-4 p-3 bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200 rounded-md text-sm">
          {error}
        </div>
      )}
      
      {success && (
        <div className="mb-4 p-3 bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200 rounded-md text-sm">
          {success}
        </div>
      )}
      
      {/* Deposit 操作 */}
      {activeOperation === 'deposit' && (
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Amount
            </label>
            <input
              type="text"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="Enter deposit amount"
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-700 text-gray-900 dark:text-white"
            />
          </div>
          
          <div className="flex flex-col space-y-2">
            <button
              onClick={handleApprove}
              disabled={isApproving || !amount}
              className="py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isApproving ? 'Approving...' : '1. Approve Base Token'}
            </button>
            
            <button
              onClick={handleDeposit}
              disabled={isDepositing || !amount}
              className="py-2 px-4 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isDepositing ? 'Depositing...' : '2. Deposit to Wrapper'}
            </button>
          </div>
          
          <p className="text-xs text-gray-500 dark:text-gray-400">
            Note: You need to approve the wrapper contract to use your base tokens before making a deposit.
          </p>
        </div>
      )}
      
      {/* Withdraw 操作 */}
      {activeOperation === 'withdraw' && (
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Amount
            </label>
            <input
              type="text"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="Enter withdraw amount"
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-700 text-gray-900 dark:text-white"
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Recipient Address (Optional)
            </label>
            <input
              type="text"
              value={recipient}
              onChange={(e) => setRecipient(e.target.value)}
              placeholder="Enter recipient address or leave empty for self"
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-700 text-gray-900 dark:text-white"
            />
          </div>
          
          <button
            onClick={handleWithdraw}
            disabled={isWithdrawingSimple || isWithdrawingToAddress || !amount}
            className="w-full py-2 px-4 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isWithdrawingSimple || isWithdrawingToAddress ? 'Processing...' : 'Submit Withdraw Request'}
          </button>
          
          <p className="text-xs text-gray-500 dark:text-gray-400">
            Note: After submitting a withdrawal request, you must wait for verification, then use Redeem to complete the withdrawal.
          </p>
        </div>
      )}
      
      {/* Redeem 操作 */}
      {activeOperation === 'redeem' && (
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Request ID
            </label>
            <input
              type="text"
              value={requestId}
              onChange={(e) => setRequestId(e.target.value)}
              placeholder="Enter withdraw request ID"
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-700 text-gray-900 dark:text-white"
            />
          </div>
          
          <button
            onClick={handleRedeem}
            disabled={isRedeeming || !requestId}
            className="w-full py-2 px-4 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isRedeeming ? 'Processing...' : 'Redeem Tokens'}
          </button>
          
          <p className="text-xs text-gray-500 dark:text-gray-400">
            Note: Only verified withdrawal requests can be redeemed. Make sure your request has been validated.
          </p>
        </div>
      )}
    </div>
  )
}

export default WrapperOperations 