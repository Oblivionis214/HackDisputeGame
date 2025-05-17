import { useMultipleDisputeGames, GameState } from '../hooks/useDisputeGameDetails'

interface DisputeGameListProps {
  requestIds: number[]
}

const getGameStateText = (state: GameState): string => {
  switch (state) {
    case GameState.NONE:
      return '无'
    case GameState.PROPOSED:
      return '已提议'
    case GameState.DISPUTED:
      return '有争议'
    case GameState.RESOLVED:
      return '已解决'
    default:
      return '未知'
  }
}

const getGameStateClass = (state: GameState): string => {
  switch (state) {
    case GameState.NONE:
      return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200'
    case GameState.PROPOSED:
      return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
    case GameState.DISPUTED:
      return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
    case GameState.RESOLVED:
      return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
    default:
      return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200'
  }
}

const DisputeGameList = ({ requestIds }: DisputeGameListProps) => {
  const { games, isLoading, error } = useMultipleDisputeGames(requestIds)

  return (
    <div className="bg-white dark:bg-gray-800 rounded-lg shadow mt-8">
      <div className="p-6">
        <h2 className="text-xl font-semibold mb-4 text-gray-900 dark:text-white">争议游戏列表</h2>
        
        {isLoading ? (
          <div className="text-center py-4">加载中...</div>
        ) : error ? (
          <div className="text-center py-4 text-red-500">加载失败: {error.message}</div>
        ) : games.length === 0 || !games.some(game => game.exists) ? (
          <div className="text-center py-4 text-gray-500">没有找到争议游戏</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead className="bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">请求ID</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">游戏ID</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">游戏合约地址</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">状态</th>
                </tr>
              </thead>
              <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                {games.filter(game => game.exists).map((game) => (
                  <tr key={game.requestId}>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                      {game.requestId}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                      {game.gameId.toString()}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                      <a 
                        href={`https://sepolia.etherscan.io/address/${game.gameAddress}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-indigo-600 hover:text-indigo-900 dark:text-indigo-400 dark:hover:text-indigo-300"
                      >
                        {game.gameAddress.substring(0, 6)}...{game.gameAddress.substring(38)}
                      </a>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${getGameStateClass(game.gameState)}`}>
                        {getGameStateText(game.gameState)}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}

export default DisputeGameList 