import { useState, useEffect } from 'react'
import { useContractRead } from 'wagmi'
import disputeResolverABI from '../contracts/DisputeResolverABI'

const DISPUTE_RESOLVER_CONTRACT = '0x1ebAbed3057e4C53F1d7E002046b3b832a330852'

interface WithdrawRequest {
  id: number
  user: string
  amount: bigint
  timestamp: bigint
  disputed: boolean
  valid: boolean
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
    if (!data || !requestId) return

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
  }, [data, requestId])

  return {
    requestDetails,
    isLoading,
    error,
  }
}

export function useUserRequestIds(userAddress: string | undefined) {
  const [requestIds, setRequestIds] = useState<number[]>([])

  const { data, isLoading, error } = useContractRead({
    address: DISPUTE_RESOLVER_CONTRACT,
    abi: disputeResolverABI,
    functionName: 'getUserRequestIds',
    args: userAddress ? [userAddress] : undefined,
    enabled: !!userAddress,
    watch: true,
  })

  useEffect(() => {
    if (!data) return
    
    const ids = (data as bigint[]).map(id => Number(id))
    setRequestIds(ids)
  }, [data])

  return {
    requestIds,
    isLoading,
    error,
  }
}

export function useAllWithdrawRequests(userAddress: string | undefined) {
  const [requests, setRequests] = useState<WithdrawRequest[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)

  const { 
    requestIds, 
    isLoading: isLoadingIds, 
    error: idsError 
  } = useUserRequestIds(userAddress)

  useEffect(() => {
    if (isLoadingIds) return
    if (idsError) {
      setError(idsError as Error)
      setIsLoading(false)
      return
    }

    if (!requestIds || requestIds.length === 0) {
      setRequests([])
      setIsLoading(false)
      return
    }

    // 创建获取每个请求详情的Promise数组
    const fetchPromises = requestIds.map(async (id) => {
      try {
        // 这里实际应该使用contract.getRequestDetails(id)调用合约
        // 但为了简化示例，我们假设这里已经获取到了数据
        const details = await new Promise<WithdrawRequest>((resolve) => {
          setTimeout(() => {
            resolve({
              id,
              user: userAddress || '0x0',
              amount: BigInt(1000000000000000000), // 1 ETH
              timestamp: BigInt(Math.floor(Date.now() / 1000) - id * 86400), // 从当前时间开始，每个请求间隔1天
              disputed: false,
              valid: id % 2 === 0, // 模拟一些请求已验证，一些未验证
            })
          }, 500)
        })
        return details
      } catch (err) {
        console.error(`获取请求ID ${id} 的详情失败:`, err)
        return null
      }
    })

    Promise.all(fetchPromises)
      .then((results) => {
        setRequests(results.filter((r): r is WithdrawRequest => r !== null))
        setIsLoading(false)
      })
      .catch((err) => {
        setError(err as Error)
        setIsLoading(false)
      })
  }, [requestIds, isLoadingIds, idsError, userAddress])

  return {
    requests,
    isLoading,
    error,
  }
} 