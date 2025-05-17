import { useState, useEffect } from 'react'
import { useContractRead, usePublicClient } from 'wagmi'
import disputeResolverABI from '../contracts/DisputeResolverABI'

const DISPUTE_RESOLVER_CONTRACT = '0x1ebAbed3057e4C53F1d7E002046b3b832a330852'

// 游戏状态枚举
export enum GameState {
  NONE,
  PROPOSED,
  DISPUTED,
  RESOLVED
}

export interface DisputeGame {
  requestId: number
  exists: boolean
  gameId: bigint
  gameAddress: string
  gameState: GameState
}

export function useDisputeGameDetails(requestId: number | null) {
  const [gameDetails, setGameDetails] = useState<DisputeGame | null>(null)

  const { data, isLoading, error } = useContractRead({
    address: DISPUTE_RESOLVER_CONTRACT,
    abi: disputeResolverABI,
    functionName: 'getDisputeGame',
    args: requestId !== null ? [requestId] : undefined,
    enabled: requestId !== null,
  })

  useEffect(() => {
    if (!data || !requestId) return

    // 将合约返回的数据转换为更有用的格式
    const [exists, gameId, gameAddress, gameState] = data as [boolean, bigint, string, number]
    
    setGameDetails({
      requestId,
      exists,
      gameId,
      gameAddress,
      gameState: gameState as GameState
    })
  }, [data, requestId])

  return {
    gameDetails,
    isLoading,
    error,
  }
}

export function useMultipleDisputeGames(requestIds: number[]) {
  const [games, setGames] = useState<DisputeGame[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)
  const publicClient = usePublicClient()

  useEffect(() => {
    if (!requestIds || requestIds.length === 0) {
      setGames([])
      setIsLoading(false)
      return
    }

    // 去重请求ID
    const uniqueRequestIds = Array.from(new Set(requestIds))

    const fetchGames = async () => {
      try {
        setIsLoading(true)
        
        // 创建批量请求
        const gamePromises = uniqueRequestIds.map(async (requestId) => {
          try {
            // 直接调用合约的getDisputeGame函数
            const result = await publicClient.readContract({
              address: DISPUTE_RESOLVER_CONTRACT as `0x${string}`,
              abi: disputeResolverABI,
              functionName: 'getDisputeGame',
              args: [BigInt(requestId)]
            }) as [boolean, bigint, string, number]
            
            const [exists, gameId, gameAddress, gameState] = result
            
            return {
              requestId,
              exists,
              gameId,
              gameAddress,
              gameState: gameState as GameState
            } as DisputeGame
          } catch (err) {
            console.error(`获取请求ID ${requestId} 的争议游戏失败:`, err)
            return {
              requestId,
              exists: false,
              gameId: BigInt(0),
              gameAddress: '0x0000000000000000000000000000000000000000',
              gameState: GameState.NONE
            } as DisputeGame
          }
        })

        const results = await Promise.all(gamePromises)
        setGames(results)
        setIsLoading(false)
      } catch (err) {
        setError(err as Error)
        setIsLoading(false)
      }
    }

    fetchGames()
  }, [requestIds, publicClient])

  return {
    games,
    isLoading,
    error
  }
} 