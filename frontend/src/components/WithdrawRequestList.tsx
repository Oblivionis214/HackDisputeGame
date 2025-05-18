import { useState } from 'react'
import { useAccount } from 'wagmi'
import { useAllWithdrawRequests } from '../hooks/useContractDetails'
import GameList from './GameList'
import DisputeModal from './DisputeModal'

interface WithdrawRequestListProps {
  tokenAddress: string
}

const WithdrawRequestList = ({ tokenAddress }: WithdrawRequestListProps) => {
  const { address } = useAccount()
  const { requests, isLoading, error } = useAllWithdrawRequests(address)
  const [disputedRequestIds, setDisputedRequestIds] = useState<number[]>([])
  
  // 用于模态框的状态
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [selectedRequestId, setSelectedRequestId] = useState<number | null>(null)

  // 处理提起争议按钮点击
  const handleDisputeClick = (requestId: number) => {
    setSelectedRequestId(requestId)
    setIsModalOpen(true)
  }
  
  // 处理模态框关闭
  const handleModalClose = () => {
    setIsModalOpen(false)
  }
  
  // 记录成功提交的请求ID
  const recordDisputedRequest = (requestId: number) => {
    if (requestId) {
      setDisputedRequestIds(prev => {
        if (!prev.includes(requestId)) {
          return [...prev, requestId]
        }
        return prev
      })
    }
  }
  
  // 处理模态框提交
  const handleModalSubmit = (requestId: number) => {
    // 记录已提交争议的请求ID
    recordDisputedRequest(requestId)
    // 关闭模态框
    handleModalClose()
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
                          onClick={() => handleDisputeClick(request.id)}
                          disabled={request.disputed || request.valid || disputedRequestIds.includes(request.id)}
                          className="text-indigo-600 hover:text-indigo-900 dark:text-indigo-400 dark:hover:text-indigo-300 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {disputedRequestIds.includes(request.id) ? '已提交争议' : '提起争议'}
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
      
      {/* 争议模态框 */}
      {selectedRequestId !== null && (
        <DisputeModal 
          isOpen={isModalOpen} 
          onClose={handleModalClose} 
          requestId={selectedRequestId}
          onSubmit={handleModalSubmit}
        />
      )}
    </>
  )
}

export default WithdrawRequestList 