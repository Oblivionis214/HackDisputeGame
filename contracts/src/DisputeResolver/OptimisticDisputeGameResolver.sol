// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../DisputeGameFactory.sol";
import "./BaseDisputeResolver.sol";
import "../ERC20Wrapper.sol";
import "../DisputeGame/OptimisticDisputeGame.sol";
import "../StakingPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title OptimisticDisputeGameResolver
 * @dev 用于连接DisputeGameFactory和ERC20Wrapper的争议解决合约
 * 允许任何人对活跃的提款请求发起争议并解决争议游戏
 */
contract OptimisticDisputeGameResolver is BaseDisputeResolver {
    using Math for uint256;
    
    // 争议游戏工厂
    DisputeGameFactory public immutable gameFactory;
    
    // 争议游戏映射 (requestId => gameId)
    mapping(uint256 => uint256) public disputeGames;
    
    // 争议游戏反向映射 (gameId => requestId)
    mapping(uint256 => uint256) public gameDisputes;
    
    // 争议初始质押金额
    uint256 public immutable disputeStake;
    
    // 事件
    event DisputeCreated(uint256 indexed requestId, uint256 indexed gameId, address attacker);
    event DisputeResolved(uint256 indexed requestId, uint256 indexed gameId, bool upheld);
    
    /**
     * @dev 构造函数
     * @param _gameFactory 争议游戏工厂地址
     * @param _disputeStake 发起争议的初始质押金额
     * @param _validationTimeout 验证超时时间(秒)
     */
    constructor(
        address _gameFactory,
        uint256 _disputeStake,
        uint256 _validationTimeout
    ) 
        BaseDisputeResolver(_validationTimeout) 
        Ownable(msg.sender)
    {
        require(_gameFactory != address(0), "Invalid game factory");
        require(_disputeStake > 0, "Invalid dispute stake");
        
        gameFactory = DisputeGameFactory(_gameFactory);
        disputeStake = _disputeStake;
    }
    
    /**
     * @dev 内部验证函数，验证争议请求的有效性
     * @param user 用户地址
     * @param requestId 提款请求ID
     * @return 提款请求是否有效
     */
    function _internalValidate(address user, uint256 requestId) internal view override returns (bool) {
        WithdrawRequest storage request = requests[requestId];
        
        // 验证请求者是否匹配
        if (request.user != user) {
            return false;
        }
        
        // 如果请求已被disputed
        if (request.disputed) {
            // 基于request.valid状态返回
            return request.valid;
        } else {
            // 如果未被disputed，检查时间戳
            if (request.timestamp + validationTimeout <= block.timestamp) {
                return true;
            }
        }
        
        // 默认返回false，需要进一步验证
        return false;
    }
    
    /**
     * @dev 发起争议
     * @param requestId 提款请求ID
     * @return gameId 创建的争议游戏ID
     */
    function dispute(uint256 requestId) external returns (uint256) {
        WithdrawRequest storage request = requests[requestId];
        require(request.user != address(0), "Request does not exist");
        require(!request.disputed, "Request already disputed");
        
        // 检查是否已经过了超时时间
        require(request.timestamp + validationTimeout > block.timestamp, "Validation timeout passed");
        
        // 检查该提款请求是否已有争议游戏
        require(disputeGames[requestId] == 0, "Dispute game already exists");
        
        // 获取ERC20Wrapper并验证
        ERC20Wrapper wrapper = ERC20Wrapper(tokenWrapper);
        require(address(wrapper) != address(0), "TokenWrapper not set");
        
        // 获取包装器使用的基础代币
        address underlyingToken = address(wrapper.underlyingToken());
        require(underlyingToken != address(0), "Invalid underlying token");
        
        // 检查调用者是否拥有足够的基础代币来发起争议
        uint256 callerBalance = IERC20(underlyingToken).balanceOf(msg.sender);
        require(callerBalance >= disputeStake, "Insufficient balance for dispute");
        
        // 检查调用者是否已批准足够的基础代币用于争议
        uint256 callerAllowance = IERC20(underlyingToken).allowance(msg.sender, address(this));
        require(callerAllowance >= disputeStake, "Insufficient allowance for dispute");
        
        // 创建游戏和质押池
        (
            uint256 gameId,
            address gameAddress,
            address attackerPoolAddress,
            address defenderPoolAddress
        ) = gameFactory.createGameWithPools(
            underlyingToken,
            disputeStake,
            IERC20Metadata(underlyingToken),
            IERC20Metadata(underlyingToken)
        );
        
        // 记录争议和游戏的关系
        disputeGames[requestId] = gameId;
        gameDisputes[gameId] = requestId;
        
        // 转移代币并批准用于StakingPool
        IERC20(underlyingToken).transferFrom(msg.sender, address(this), disputeStake);
        IERC20(underlyingToken).approve(attackerPoolAddress, disputeStake);
        
        // 通过攻击者质押池参与游戏
        uint256 shares = StakingPool(attackerPoolAddress).deposit(disputeStake, msg.sender);
        
        // 更新提款请求状态
        request.disputed = true;
        
        emit DisputeCreated(requestId, gameId, msg.sender);
        
        return gameId;
    }
    
    /**
     * @dev 解决争议
     * @param requestId 提款请求ID
     * @return success 是否成功解决
     */
    function resolve(uint256 requestId) external returns (bool) {
        // 获取游戏ID
        uint256 gameId = disputeGames[requestId];
        require(gameId != 0, "Dispute does not exist");
        
        // 检查提款请求是否存在
        WithdrawRequest storage request = requests[requestId];
        require(request.user != address(0), "Request does not exist");
        require(request.disputed, "Request not disputed");
        
        // 获取游戏信息 - 直接访问游戏地址
        (
            DisputeGameFactory.GameType gameType,
            address gameAddress,
            address attacker,
            address defender,
            address token,
            uint256 initialStake,
            uint256 createdAt,
            address attackerPool,
            address defenderPool
        ) = gameFactory.games(gameId);
        
        require(gameAddress != address(0), "Game address not found");
        
        // 检查游戏状态
        OptimisticDisputeGame game = OptimisticDisputeGame(gameAddress);
        (
            address _gameAttacker,
            address _gameDefender,
            OptimisticDisputeGame.Turn _gameTurn,
            OptimisticDisputeGame.GameState gameState,
            uint256 _attackerStake,
            uint256 _defenderStake,
            uint256 _timeoutTimestamp,
            uint256 _timeoutExtension,
            address _gameToken,
            uint256 _gameInitialStake,
            uint256 _gameRequiredStake
        ) = game.getGameInfo();
        
        // 确保游戏已经结束
        require(
            gameState == OptimisticDisputeGame.GameState.ATTACKER_WON || 
            gameState == OptimisticDisputeGame.GameState.DEFENDER_WON,
            "Game not resolved yet"
        );
        
        // 根据游戏结果解决争议
        bool upheld = (gameState == OptimisticDisputeGame.GameState.ATTACKER_WON);
        
        // 更新提款请求状态
        request.valid = !upheld; // 如果攻击者胜利，则请求无效
        
        emit DisputeResolved(requestId, gameId, upheld);
        
        return true;
    }
    
    /**
     * @dev 获取争议游戏信息
     * @param requestId 提款请求ID
     * @return exists 争议是否存在
     * @return gameId 争议游戏ID
     * @return gameAddress 游戏合约地址
     * @return gameState 游戏状态
     */
    function getDisputeGame(uint256 requestId) external view returns (
        bool exists,
        uint256 gameId,
        address gameAddress,
        OptimisticDisputeGame.GameState gameState
    ) {
        gameId = disputeGames[requestId];
        exists = (gameId != 0);
        
        if (!exists) {
            return (false, 0, address(0), OptimisticDisputeGame.GameState.ACTIVE);
        }
        
        // 获取游戏信息 - 确保正确解构
        (
            DisputeGameFactory.GameType gameType,
            address gameAddress,
            address attacker,
            address defender,
            address token,
            uint256 initialStake,
            uint256 createdAt,
            address attackerPool,
            address defenderPool
        ) = gameFactory.games(gameId);
        
        require(gameAddress != address(0), "Game address not found");
        
        // 获取游戏状态
        OptimisticDisputeGame game = OptimisticDisputeGame(gameAddress);
        (
            address _gameAttacker,
            address _gameDefender,
            OptimisticDisputeGame.Turn _gameTurn,
            OptimisticDisputeGame.GameState _gameState,
            uint256 _attackerStake,
            uint256 _defenderStake,
            uint256 _timeoutTimestamp,
            uint256 _timeoutExtension,
            address _gameToken,
            uint256 _gameInitialStake,
            uint256 _gameRequiredStake
        ) = game.getGameInfo();
        
        gameState = _gameState;
        
        return (exists, gameId, gameAddress, gameState);
    }
}

