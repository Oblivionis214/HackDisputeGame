// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./DisputeGame/OptimisticDisputeGame.sol";
import "./DisputeGameFactory.sol";

/**
 * @title StakingPool
 * @dev 符合ERC4626标准的质押池，作为OptimisticDisputeGame的攻击者或防御者
 * 用户可以向池中存入代币，当池中资金足够时自动参与游戏
 * 每个池只支持一个游戏，由DisputeGameFactory创建
 */
contract StakingPool is Initializable, ERC4626Upgradeable {
    using Math for uint256;
    
    enum Role { ATTACKER, DEFENDER }
    enum PoolState { UNINITIALIZED, ACTIVE }
    
    // 质押池角色
    Role public poolRole;
    
    // 池状态
    PoolState public state;
    
    // 争议游戏工厂
    DisputeGameFactory public gameFactory;
    
    // 游戏对手地址（另一个StakingPool）
    address public opponent;
    
    // 游戏合约地址
    address public gameAddress;
    
    // 游戏信息
    struct GameData {
        uint256 initialStake;     // 初始质押金额
        uint256 totalStaked;      // 总质押金额
        address token;            // 游戏使用的代币
    }
    
    // 当前游戏数据
    GameData public currentGame;
    
    // 事件
    event GameInitialized(address indexed gameAddress, address indexed opponent);
    event TurnPlayed(address indexed gameAddress, uint256 amount);
    
    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev 初始化函数 - 用于代理模式
     * @param _asset 基础资产代币
     * @param _name 质押池代币名称
     * @param _symbol 质押池代币符号
     * @param _gameFactory 争议游戏工厂地址
     * @param _poolRole 质押池角色（攻击者或防御者）
     * @param _opponent 游戏对手地址（另一个StakingPool）
     * @param _gameAddress 游戏合约地址
     */
    function initialize(
        IERC20Metadata _asset,
        string memory _name,
        string memory _symbol,
        address _gameFactory,
        Role _poolRole,
        address _opponent,
        address _gameAddress
    ) external initializer {
        require(address(_asset) != address(0), "Invalid asset");
        require(_gameFactory != address(0), "Invalid game factory");
        require(_opponent != address(0), "Invalid opponent address");
        require(_gameAddress != address(0), "Invalid game address");
        
        // 初始化ERC20Upgradeable和ERC4626Upgradeable
        __ERC20_init(_name, _symbol);
        __ERC4626_init(_asset);
        
        // 初始化StakingPool特定属性
        gameFactory = DisputeGameFactory(_gameFactory);
        poolRole = _poolRole;
        opponent = _opponent;
        gameAddress = _gameAddress;
        state = PoolState.ACTIVE;
        
        // 获取游戏信息
        OptimisticDisputeGame game = OptimisticDisputeGame(gameAddress);
        (, , , , , , , , address token, uint256 initialStake, ) = game.getGameInfo();
        
        currentGame = GameData({
            initialStake: initialStake,
            totalStaked: initialStake,
            token: token
        });
        
        emit GameInitialized(gameAddress, opponent);
    }
    
    /**
     * @dev 存款并自动尝试进行游戏回合
     * 当存款足够时会自动调用attack/defend
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        // 使用父合约的_deposit函数处理存款
        uint256 shares = super.deposit(assets, receiver);
        
        // 如果游戏处于活跃状态，尝试执行游戏回合
        if (state == PoolState.ACTIVE) {
            _tryPlayTurn();
        }
        
        return shares;
    }
    
    /**
     * @dev 铸造股份并自动尝试进行游戏回合
     */
    function mint(uint256 shares, address receiver) public override returns (uint256) {
        // 使用父合约的_mint函数处理铸造
        uint256 assets = super.mint(shares, receiver);
        
        // 如果游戏处于活跃状态，尝试执行游戏回合
        if (state == PoolState.ACTIVE) {
            _tryPlayTurn();
        }
        
        return assets;
    }
    
    /**
     * @dev 提取资产并将相应份额从所有者处销毁
     */
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        // 使用父合约的withdraw函数处理提款
        return super.withdraw(assets, receiver, owner);
    }
    
    /**
     * @dev 赎回份额并向接收者发送相应的资产数量
     */
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        // 使用父合约的redeem函数处理赎回
        return super.redeem(shares, receiver, owner);
    }
    
    /**
     * @dev 尝试进行游戏回合（内部函数）
     */
    function _tryPlayTurn() internal {
        // 检查游戏状态
        OptimisticDisputeGame disputeGame = OptimisticDisputeGame(gameAddress);
        
        // 获取游戏信息
        (
            ,
            ,
            OptimisticDisputeGame.Turn _currentTurn,
            OptimisticDisputeGame.GameState _gameState,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 _currentRequiredStake
        ) = disputeGame.getGameInfo();
        
        // 如果游戏已经结束则不执行操作
        if (_gameState != OptimisticDisputeGame.GameState.ACTIVE) {
            return;
        }
        
        // 检查是否轮到我们
        bool isOurTurn = (poolRole == Role.ATTACKER && _currentTurn == OptimisticDisputeGame.Turn.ATTACKER) ||
                         (poolRole == Role.DEFENDER && _currentTurn == OptimisticDisputeGame.Turn.DEFENDER);
        
        if (!isOurTurn) {
            return; // 不是我们的回合，跳过
        }
        
        // 检查池中是否有足够的资产
        uint256 poolAssetBalance = IERC20Metadata(asset()).balanceOf(address(this));
        if (poolAssetBalance < _currentRequiredStake) {
            return; // 资金不足，跳过
        }
        
        // 准备进行攻击或防御
        IERC20(currentGame.token).approve(gameAddress, _currentRequiredStake);
        
        if (poolRole == Role.ATTACKER) {
            disputeGame.attack();
        } else {
            disputeGame.defend();
        }
        
        // 更新总质押金额
        currentGame.totalStaked += _currentRequiredStake;
        
        emit TurnPlayed(gameAddress, _currentRequiredStake);
    }
    
    /**
     * @dev 手动触发游戏回合
     * 当自动尝试失败时可以手动触发
     */
    function playTurn() external {
        require(state == PoolState.ACTIVE, "No active game");
        _tryPlayTurn();
    }
    
    /**
     * @dev 获取当前游戏状态信息
     */
    function getGameStatus() external view returns (
        PoolState _state,
        address _gameAddress,
        uint256 _totalStaked,
        bool _isOurTurn,
        uint256 _requiredStake,
        bool _hasEnoughFunds,
        bool _isGameActive
    ) {
        _state = state;
        
        if (state != PoolState.ACTIVE) {
            return (_state, address(0), 0, false, 0, false, false);
        }
        
        OptimisticDisputeGame disputeGame = OptimisticDisputeGame(gameAddress);
        
        (
            ,
            ,
            OptimisticDisputeGame.Turn _currentTurn,
            OptimisticDisputeGame.GameState _gameState,
            ,
            ,
            ,
            ,
            ,
            ,
            uint256 _currentRequiredStake
        ) = disputeGame.getGameInfo();
        
        // 检查是否轮到我们
        bool isOurTurn = (poolRole == Role.ATTACKER && _currentTurn == OptimisticDisputeGame.Turn.ATTACKER) ||
                         (poolRole == Role.DEFENDER && _currentTurn == OptimisticDisputeGame.Turn.DEFENDER);
        
        // 检查是否有足够资金
        uint256 poolAssetBalance = IERC20Metadata(asset()).balanceOf(address(this));
        bool hasEnoughFunds = poolAssetBalance >= _currentRequiredStake;
        
        // 检查游戏是否活跃
        bool isGameActive = _gameState == OptimisticDisputeGame.GameState.ACTIVE;
        
        return (
            _state,
            gameAddress,
            currentGame.totalStaked,
            isOurTurn,
            _currentRequiredStake,
            hasEnoughFunds,
            isGameActive
        );
    }
}
