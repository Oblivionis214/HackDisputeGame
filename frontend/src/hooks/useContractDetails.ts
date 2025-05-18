import { useState, useEffect } from 'react'
import { useContractRead } from 'wagmi'
import { readContract } from 'wagmi/actions'
import disputeResolverABI from '../contracts/DisputeResolverABI'

const DISPUTE_RESOLVER_CONTRACT = '0x1ebAbed3057e4C53F1d7E002046b3b832a330852'

// 零地址常量
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

interface WithdrawRequest {
  id: number
  user: string
  amount: bigint
  timestamp: bigint
  disputed: boolean
  valid: boolean
}

// 单个请求详情的钩子函数
export function useSingleWithdrawRequest(requestId: number) {
  const [request, setRequest] = useState<WithdrawRequest | null>(null)

  const { data, isLoading, error } = useContractRead({
    address: DISPUTE_RESOLVER_CONTRACT,
    abi: disputeResolverABI,
    functionName: 'getRequestDetails',
    args: [requestId],
  })

  useEffect(() => {
    if (!data) return

    try {
      // 将合约返回的数据转换为更有用的格式
      const [user, amount, timestamp, disputed, valid] = data as [string, bigint, bigint, boolean, boolean]
      
      setRequest({
        id: requestId,
        user,
        amount,
        timestamp,
        disputed,
        valid
      })
    } catch (err) {
      console.error(`解析请求ID ${requestId} 数据时出错:`, err)
    }
  }, [data, requestId])

  return {
    request,
    isLoading,
    error,
  }
}

export function useWithdrawRequestDetails(requestId: number | null) {
  const [requestDetails, setRequestDetails] = useState<WithdrawRequest | null>(null)

  const { data, isLoading, error } = useContractRead({
    address: DISPUTE_RESOLVER_CONTRACT,
    abi: disputeResolverABI,
    functionName: 'getRequestDetails',
    args: requestId !== null ? [requestId] : undefined,
    enabled: requestId !== null,
  })

  useEffect(() => {
    if (!data || requestId === null) return

    try {
      // 将合约返回的数据转换为更有用的格式
      const [user, amount, timestamp, disputed, valid] = data as [string, bigint, bigint, boolean, boolean]
      
      setRequestDetails({
        id: requestId,
        user,
        amount,
        timestamp,
        disputed,
        valid
      })
    } catch (err) {
      console.error(`解析请求ID ${requestId} 数据时出错:`, err)
    }
  }, [data, requestId])

  return {
    requestDetails,
    isLoading,
    error,
  }
}

export function useAllWithdrawRequests(userAddress: string | undefined) {
  const [requests, setRequests] = useState<WithdrawRequest[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)
  
  useEffect(() => {
    // 标记组件为加载中
    setIsLoading(true)
    setError(null)
    
    const fetchAllRequests = async () => {
      try {
        const allRequests: WithdrawRequest[] = []
        let index = 0
        const MAX_INDEX = 100 // 设置一个上限，防止无限循环
        
        // 从0开始依次获取，直到遇到用户地址为0或金额为0
        while (index < MAX_INDEX) {
          try {
            const data = await readContract({
              address: DISPUTE_RESOLVER_CONTRACT,
              abi: disputeResolverABI,
              functionName: 'getRequestDetails',
              args: [index]
            })
            
            const [user, amount, timestamp, disputed, valid] = data as [string, bigint, bigint, boolean, boolean]
            
            // 如果用户地址为0或金额为0，则表示已经没有更多有效请求
            if (user === ZERO_ADDRESS || amount === BigInt(0)) {
              break
            }
            
            // 添加有效请求
            allRequests.push({
              id: index,
              user,
              amount,
              timestamp,
              disputed,
              valid
            })
            
            // 继续下一个索引
            index++
          } catch (err) {
            console.error(`获取请求ID ${index} 失败:`, err)
            // 遇到错误，停止获取
            break
          }
        }
        
        setRequests(allRequests)
      } catch (err) {
        console.error('获取请求列表失败:', err)
        setError(err instanceof Error ? err : new Error(String(err)))
      } finally {
        setIsLoading(false)
      }
    }
    
    fetchAllRequests()
  }, []) // 只在组件挂载时获取一次
  
  return {
    requests,
    isLoading,
    error,
  }
} 