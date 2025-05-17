import { useState, useEffect } from 'react'
import { useContractRead, usePublicClient } from 'wagmi'

const GAME_FACTORY_CONTRACT = '0xeD6f6b001D9d2A2517c196D56C29e2666056349A'

// 游戏类型枚举
export enum GameType {
  NONE,
  OPTIMISTIC,
  INTERACTIVE
}

export interface GameInfo {
  gameId: number
  gameType: GameType
  gameAddress: string
  attacker: string
  defender: string
  token: string
  initialStake: bigint
  createdAt: bigint
  attackerPool: string
  defenderPool: string
}

// 合约ABI
const gameFactoryABI = [
  {
    "inputs": [{"internalType": "uint256", "name": "_gameId", "type": "uint256"}],
    "name": "getGameInfo",
    "outputs": [
      {
        "components": [
          {"internalType": "enum DisputeGameFactory.GameType", "name": "gameType", "type": "uint8"},
          {"internalType": "address", "name": "gameAddress", "type": "address"},
          {"internalType": "address", "name": "attacker", "type": "address"},
          {"internalType": "address", "name": "defender", "type": "address"},
          {"internalType": "address", "name": "token", "type": "address"},
          {"internalType": "uint256", "name": "initialStake", "type": "uint256"},
          {"internalType": "uint256", "name": "createdAt", "type": "uint256"},
          {"internalType": "address", "name": "attackerPool", "type": "address"},
          {"internalType": "address", "name": "defenderPool", "type": "address"}
        ],
        "internalType": "struct DisputeGameFactory.GameInfo",
        "name": "",
        "type": "tuple"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address", "name": "_user", "type": "address"}],
    "name": "getUserGames",
    "outputs": [{"internalType": "uint256[]", "name": "", "type": "uint256[]"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "gameCount",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "name": "games",
    "outputs": [
      {"internalType": "enum DisputeGameFactory.GameType", "name": "gameType", "type": "uint8"},
      {"internalType": "address", "name": "gameAddress", "type": "address"},
      {"internalType": "address", "name": "attacker", "type": "address"},
      {"internalType": "address", "name": "defender", "type": "address"},
      {"internalType": "address", "name": "token", "type": "address"},
      {"internalType": "uint256", "name": "initialStake", "type": "uint256"},
      {"internalType": "uint256", "name": "createdAt", "type": "uint256"},
      {"internalType": "address", "name": "attackerPool", "type": "address"},
      {"internalType": "address", "name": "defenderPool", "type": "address"}
    ],
    "stateMutability": "view",
    "type": "function"
  }
]

export function useGameInfo(gameId: number | null) {
  const [gameInfo, setGameInfo] = useState<GameInfo | null>(null)

  const { data, isLoading, error } = useContractRead({
    address: GAME_FACTORY_CONTRACT,
    abi: gameFactoryABI,
    functionName: 'getGameInfo',
    args: gameId !== null ? [gameId] : undefined,
    enabled: gameId !== null,
  })

  useEffect(() => {
    if (!data || !gameId) return

    // 将合约返回的数据转换为更有用的格式
    const [
      gameType,
      gameAddress,
      attacker,
      defender,
      token,
      initialStake,
      createdAt,
      attackerPool,
      defenderPool
    ] = data as [number, string, string, string, string, bigint, bigint, string, string]
    
    setGameInfo({
      gameId,
      gameType: gameType as GameType,
      gameAddress,
      attacker,
      defender,
      token,
      initialStake,
      createdAt,
      attackerPool,
      defenderPool
    })
  }, [data, gameId])

  return {
    gameInfo,
    isLoading,
    error,
  }
}

export function useUserGames(userAddress: string | undefined) {
  const [gameIds, setGameIds] = useState<number[]>([])

  const { data, isLoading, error } = useContractRead({
    address: GAME_FACTORY_CONTRACT,
    abi: gameFactoryABI,
    functionName: 'getUserGames',
    args: userAddress ? [userAddress] : undefined,
    enabled: !!userAddress,
  })

  useEffect(() => {
    if (!data) return
    
    const ids = (data as bigint[]).map(id => Number(id))
    setGameIds(ids)
  }, [data])

  return {
    gameIds,
    isLoading,
    error,
  }
}

export function useAllGames() {
  const [totalGames, setTotalGames] = useState<number>(0)
  
  const { data: gameCount } = useContractRead({
    address: GAME_FACTORY_CONTRACT,
    abi: gameFactoryABI,
    functionName: 'gameCount',
  })
  
  useEffect(() => {
    if (gameCount) {
      setTotalGames(Number(gameCount))
    }
  }, [gameCount])
  
  return {
    totalGames
  }
}

export function useMultipleGames(gameIds: number[]) {
  const [games, setGames] = useState<GameInfo[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)
  const publicClient = usePublicClient()

  useEffect(() => {
    if (!gameIds || gameIds.length === 0) {
      setGames([])
      setIsLoading(false)
      return
    }

    // 去重游戏ID
    const uniqueGameIds = Array.from(new Set(gameIds))

    const fetchGames = async () => {
      try {
        setIsLoading(true)
        
        // 创建批量请求
        const gamePromises = uniqueGameIds.map(async (gameId) => {
          try {
            // 直接调用合约的getGameInfo函数
            const result = await publicClient.readContract({
              address: GAME_FACTORY_CONTRACT as `0x${string}`,
              abi: gameFactoryABI,
              functionName: 'getGameInfo',
              args: [BigInt(gameId)]
            }) as [number, string, string, string, string, bigint, bigint, string, string]
            
            const [
              gameType,
              gameAddress,
              attacker,
              defender,
              token,
              initialStake,
              createdAt,
              attackerPool,
              defenderPool
            ] = result
            
            return {
              gameId,
              gameType: gameType as GameType,
              gameAddress,
              attacker,
              defender,
              token,
              initialStake,
              createdAt,
              attackerPool,
              defenderPool
            } as GameInfo
          } catch (err) {
            console.error(`获取游戏ID ${gameId} 的详情失败:`, err)
            return null
          }
        })

        const results = await Promise.all(gamePromises)
        setGames(results.filter((game): game is GameInfo => game !== null))
        setIsLoading(false)
      } catch (err) {
        setError(err as Error)
        setIsLoading(false)
      }
    }

    fetchGames()
  }, [gameIds, publicClient])

  return {
    games,
    isLoading,
    error
  }
}

export function useGameByIndex(index: number) {
  const [gameInfo, setGameInfo] = useState<GameInfo | null>(null)
  const [isError, setIsError] = useState(false)

  const { data, isLoading, error } = useContractRead({
    address: GAME_FACTORY_CONTRACT,
    abi: gameFactoryABI,
    functionName: 'games',
    args: [index],
  })

  useEffect(() => {
    if (!data) return

    try {
      // 将合约返回的数据转换为更有用的格式
      const [
        gameType,
        gameAddress,
        attacker,
        defender,
        token,
        initialStake,
        createdAt,
        attackerPool,
        defenderPool
      ] = data as [number, string, string, string, string, bigint, bigint, string, string]
      
      // 检查返回的数据是否有效（地址不为零，表示存在游戏）
      if (gameAddress === '0x0000000000000000000000000000000000000000') {
        setIsError(true)
        return
      }
      
      setGameInfo({
        gameId: index,
        gameType: gameType as GameType,
        gameAddress,
        attacker,
        defender,
        token,
        initialStake,
        createdAt,
        attackerPool,
        defenderPool
      })
      setIsError(false)
    } catch (err) {
      console.error(`解析游戏索引 ${index} 的数据失败:`, err)
      setIsError(true)
    }
  }, [data, index])

  return {
    gameInfo,
    isLoading,
    error: error || isError,
    exists: !isError && gameInfo !== null
  }
}

export function useAllGamesFromMapping() {
  const [games, setGames] = useState<GameInfo[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)
  const publicClient = usePublicClient()

  // 获取游戏总数来确定查询范围
  const { data: gameCount } = useContractRead({
    address: GAME_FACTORY_CONTRACT,
    abi: gameFactoryABI,
    functionName: 'gameCount',
  })

  useEffect(() => {
    if (!gameCount) return
    
    const fetchAllGames = async () => {
      try {
        setIsLoading(true)
        const totalGames = Number(gameCount)
        // 限制最大查询数量，避免过多请求
        const maxGamesToFetch = Math.min(totalGames, 100)
        const gamePromises = []
        
        // 创建所有游戏查询的请求，从索引1开始，而不是从0开始
        for (let i = 1; i <= maxGamesToFetch; i++) {
          gamePromises.push(fetchGameByIndex(i))
        }
        
        // 执行所有请求
        const results = await Promise.all(gamePromises)
        
        // 过滤掉无效结果，只保留有效的游戏信息
        const validGames = results.filter((game): game is GameInfo => 
          game !== null && 
          game.gameAddress !== '0x0000000000000000000000000000000000000000'
        )
        
        setGames(validGames)
        setIsLoading(false)
      } catch (err) {
        console.error("获取所有游戏失败:", err)
        setError(err as Error)
        setIsLoading(false)
      }
    }
    
    // 辅助函数：获取单个游戏信息
    const fetchGameByIndex = async (index: number): Promise<GameInfo | null> => {
      try {
        const result = await publicClient.readContract({
          address: GAME_FACTORY_CONTRACT as `0x${string}`,
          abi: gameFactoryABI,
          functionName: 'games',
          args: [BigInt(index)]
        }) as [number, string, string, string, string, bigint, bigint, string, string]
        
        const [
          gameType,
          gameAddress,
          attacker,
          defender,
          token,
          initialStake,
          createdAt,
          attackerPool,
          defenderPool
        ] = result
        
        // 零地址检查，跳过无效游戏
        if (gameAddress === '0x0000000000000000000000000000000000000000') {
          return null
        }
        
        return {
          gameId: index,
          gameType: gameType as GameType,
          gameAddress,
          attacker,
          defender,
          token,
          initialStake,
          createdAt,
          attackerPool,
          defenderPool
        }
      } catch (err) {
        console.error(`获取游戏索引 ${index} 失败:`, err)
        return null
      }
    }
    
    fetchAllGames()
  }, [gameCount, publicClient])
  
  return {
    games,
    isLoading,
    error
  }
} 