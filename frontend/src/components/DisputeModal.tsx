import { useState, useEffect } from 'react'
import { useContractWrite, usePublicClient } from 'wagmi'
import { parseEther } from 'viem'

interface DisputeModalProps {
  isOpen: boolean
  onClose: () => void
  requestId: number
  onSubmit?: (requestId: number) => void
}

// ERC20代币合约ABI
const tokenABI = [
  {
    "inputs": [
      {"internalType": "address", "name": "spender", "type": "address"},
      {"internalType": "uint256", "name": "amount", "type": "uint256"}
    ],
    "name": "approve",
    "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]

// DisputeResolver合约ABI
const disputeResolverABI = [
  {
    "inputs": [{"internalType": "uint256", "name": "requestId", "type": "uint256"}],
    "name": "dispute",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]

const TOKEN_ADDRESS = '0x1df44B5C1160fca5AE1d9430D221A6c39CCEd00D'
const DISPUTE_RESOLVER_ADDRESS = '0x1ebAbed3057e4C53F1d7E002046b3b832a330852'
const MAX_UINT256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'

const DisputeModal = ({ isOpen, onClose, requestId, onSubmit }: DisputeModalProps) => {
  const [step, setStep] = useState<'approve' | 'dispute'>('approve')
  const [txHash, setTxHash] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  
  const publicClient = usePublicClient()
  
  // 用于approve操作的合约写入
  const { 
    write: approveToken, 
    isLoading: isApprovingToken, 
    isSuccess: isApproveSuccess,
    error: approveError,
    data: approveData
  } = useContractWrite({
    address: TOKEN_ADDRESS,
    abi: tokenABI,
    functionName: 'approve',
  })
  
  // 用于dispute操作的合约写入
  const { 
    write: disputeRequest, 
    isLoading: isDisputingRequest,
    isSuccess: isDisputeSuccess,
    error: disputeError,
    data: disputeData
  } = useContractWrite({
    address: DISPUTE_RESOLVER_ADDRESS,
    abi: disputeResolverABI,
    functionName: 'dispute',
  })
  
  // 处理approve按钮点击
  const handleApprove = () => {
    setError(null)
    try {
      approveToken({
        args: [DISPUTE_RESOLVER_ADDRESS, MAX_UINT256],
      })
    } catch (err) {
      setError("授权过程中出错，请重试")
      console.error("Approve error:", err)
    }
  }
  
  // 处理dispute按钮点击
  const handleDispute = () => {
    setError(null)
    try {
      disputeRequest({
        args: [requestId],
      })
    } catch (err) {
      setError("发起争议过程中出错，请重试")
      console.error("Dispute error:", err)
    }
  }
  
  // 监控approve是否成功，成功后自动切换到dispute步骤
  useEffect(() => {
    if (isApproveSuccess && approveData?.hash) {
      setTxHash(approveData.hash)
      setStep('dispute')
    }
  }, [isApproveSuccess, approveData])
  
  // 监控dispute是否成功，成功后关闭模态框
  useEffect(() => {
    if (isDisputeSuccess && disputeData?.hash) {
      setTxHash(disputeData.hash)
      
      // 如果提供了onSubmit回调，则调用它
      if (onSubmit) {
        onSubmit(requestId)
      }
      
      // 等待1.5秒后关闭模态框，以便用户看到成功状态
      const timer = setTimeout(() => {
        onClose()
      }, 1500)
      return () => clearTimeout(timer)
    }
  }, [isDisputeSuccess, disputeData, onClose, onSubmit, requestId])
  
  // 监控错误
  useEffect(() => {
    if (approveError) {
      setError(`授权失败: ${approveError.message}`)
    }
    if (disputeError) {
      setError(`争议失败: ${disputeError.message}`)
    }
  }, [approveError, disputeError])
  
  if (!isOpen) return null
  
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-md w-full p-6">
        <h3 className="text-xl font-semibold mb-4 text-gray-900 dark:text-white">提起争议</h3>
        
        <div className="mb-6">
          <p className="text-gray-700 dark:text-gray-300 font-medium mb-2">
            进行dispute意味着你将成为第一个attacker
          </p>
          <p className="text-sm text-gray-600 dark:text-gray-400">
            1. 首先，需要授权代币合约允许DisputeResolver合约使用您的代币
            <br />
            2. 然后，您可以对请求ID {requestId} 发起争议
          </p>
          
          {error && (
            <div className="mt-4 p-3 bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200 rounded-md text-sm">
              {error}
            </div>
          )}
          
          {txHash && (
            <div className="mt-4 p-3 bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200 rounded-md text-sm">
              交易已提交! <a 
                href={`https://sepolia.etherscan.io/tx/${txHash}`} 
                target="_blank" 
                rel="noopener noreferrer"
                className="underline hover:no-underline"
              >
                查看交易
              </a>
            </div>
          )}
        </div>
        
        <div className="flex flex-col space-y-4">
          <button
            onClick={handleApprove}
            disabled={step !== 'approve' || isApprovingToken}
            className={`py-2 px-4 rounded-md ${
              step === 'approve' 
                ? 'bg-indigo-600 text-white hover:bg-indigo-700' 
                : 'bg-gray-300 text-gray-700 cursor-not-allowed'
            } transition-colors focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:opacity-70`}
          >
            {isApprovingToken ? (
              <span className="flex items-center justify-center">
                <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                授权中...
              </span>
            ) : step === 'approve' ? 'Approve' : '已授权'}
          </button>
          
          <button
            onClick={handleDispute}
            disabled={step !== 'dispute' || isDisputingRequest}
            className={`py-2 px-4 rounded-md ${
              step === 'dispute' 
                ? 'bg-red-600 text-white hover:bg-red-700' 
                : 'bg-gray-300 text-gray-700 cursor-not-allowed'
            } transition-colors focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 disabled:opacity-70`}
          >
            {isDisputingRequest ? (
              <span className="flex items-center justify-center">
                <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                处理中...
              </span>
            ) : 'Dispute'}
          </button>
          
          <button
            onClick={onClose}
            className="py-2 px-4 bg-gray-200 text-gray-800 rounded-md hover:bg-gray-300 transition-colors focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
          >
            取消
          </button>
        </div>
      </div>
    </div>
  )
}

export default DisputeModal 