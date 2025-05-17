import { useState } from 'react'
import { useContractWrite, useAccount } from 'wagmi'
import disputeResolverABI from '../contracts/DisputeResolverABI'
import { useAllWithdrawRequests } from '../hooks/useContractDetails'
import GameList from './GameList'

interface WithdrawRequestListProps {
  tokenAddress: string
}

const DISPUTE_RESOLVER_CONTRACT = '0x1ebAbed3057e4C53F1d7E002046b3b832a330852'

const WithdrawRequestList = ({ tokenAddress }: WithdrawRequestListProps) => {
  const { address } = useAccount()
  const { requests, isLoading, error } = useAllWithdrawRequests(address)
  const [disputedRequestIds, setDisputedRequestIds] = useState<number[]>([])

  // 用于执行争议操作的合约写入
  const { write: disputeRequest, data: disputeData } = useContractWrite({
    address: DISPUTE_RESOLVER_CONTRACT,
    abi: disputeResolverABI,
    functionName: 'dispute',
  })

  // 监听交易成功
  const handleDispute = (requestId: number) => {
    if (!address) return
    
    // 记录正在处理的请求ID
    const currentRequestId = requestId;
    
    disputeRequest({
      args: [requestId],
    })
    
    // 假设交易成功，将请求ID添加到disputedRequestIds
    // 注意：实际应用中应该监听交易的确认事件
    if (currentRequestId) {
      setDisputedRequestIds(prev => {
        if (!prev.includes(currentRequestId)) {
          return [...prev, currentRequestId];
        }
        return prev;
      });
    }
  }

  return (
    <>
      <div className="bg-white dark:bg-gray-800 rounded-lg shadow">
        <div className="p-6">
          <h2 className="text-xl font-semibold mb-4 text-gray-900 dark:text-white">提款请求列表</h2>
          
          {isLoading ? (
            <div className="text-center py-4">加载中...</div>
          ) : error ? (
            <div className="text-center py-4 text-red-500">加载失败: {error.message}</div>
          ) : requests.length === 0 ? (
            <div className="text-center py-4 text-gray-500">没有找到提款请求</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                <thead className="bg-gray-50 dark:bg-gray-700">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">ID</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">用户地址</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">金额</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">时间戳</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">状态</th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">操作</th>
                  </tr>
                </thead>
                <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                  {requests.map((request) => (
                    <tr key={request.id}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">{request.id}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                        {request.user.substring(0, 6)}...{request.user.substring(38)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                        {(Number(request.amount) / 1e18).toFixed(6)} ETH
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                        {new Date(Number(request.timestamp) * 1000).toLocaleString()}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        {request.disputed ? (
                          <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200">
                            已争议
                          </span>
                        ) : request.valid ? (
                          <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">
                            已验证
                          </span>
                        ) : (
                          <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200">
                            待验证
                          </span>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <button
                          onClick={() => handleDispute(request.id)}
                          disabled={request.disputed || request.valid}
                          className="text-indigo-600 hover:text-indigo-900 dark:text-indigo-400 dark:hover:text-indigo-300 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          提起争议
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {/* 显示用户参与的所有游戏 */}
      <GameList />
    </>
  )
}

export default WithdrawRequestList 