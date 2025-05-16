// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DisputeGame/OptimisticDisputeGame.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./StakingPool.sol";

/**
 * @title DisputeGameFactory
 * @dev 用于创建和管理OptimisticDisputeGame实例的工厂合约，使用Clone模式以降低Gas成本
 * 同时创建对应的StakingPool作为attacker和defender
 */
contract DisputeGameFactory is Ownable {
    // 使用OpenZeppelin的Clones库
    using Clones for address;

    // 游戏类型枚举
    enum GameType { OPTIMISTIC }
    
    // 游戏创建事件
    event GameCreated(
        uint256 indexed gameId,
        GameType gameType,
        address gameAddress,
        address attacker,
        address defender,
        address token,
        uint256 initialStake
    );
    
    // StakingPool创建事件
    event StakingPoolsCreated(
        uint256 indexed gameId,
        address attackerPoolAddress,
        address defenderPoolAddress
    );
    
    // 存储所有创建的游戏信息
    struct GameInfo {
        GameType gameType;
        address gameAddress;
        address attacker;
        address defender;
        address token;
        uint256 initialStake;
        uint256 createdAt;
        address attackerPool;
        address defenderPool;
    }
    
    // OptimisticDisputeGame实现合约地址（用作模板）
    address public optimisticGameImplementation;
    
    // StakingPool实现合约地址（用作模板）
    address public stakingPoolImplementation;
    
    // 游戏ID到游戏信息的映射
    mapping(uint256 => GameInfo) public games;
    
    // 用户参与的游戏ID列表
    mapping(address => uint256[]) public userGames;
    
    // 游戏总数
    uint256 public gameCount;
    
    // 游戏超时扩展时间（可由管理员设置）
    uint256 public defaultTimeoutExtension;
    
    /**
     * @dev 构造函数
     * @param _optimisticGameImplementation OptimisticDisputeGame实现合约地址
     * @param _stakingPoolImplementation StakingPool实现合约地址
     */
    constructor(address _optimisticGameImplementation, address _stakingPoolImplementation) Ownable(msg.sender) {
        require(_optimisticGameImplementation != address(0), "Game implementation cannot be zero");
        require(_stakingPoolImplementation != address(0), "Pool implementation cannot be zero");
        
        optimisticGameImplementation = _optimisticGameImplementation;
        stakingPoolImplementation = _stakingPoolImplementation;
        defaultTimeoutExtension = 2 hours; // 默认超时扩展时间
    }
    
    /**
     * @dev 部署游戏实现合约（在工厂合约部署后需要调用一次）
     * @return implementation 新部署的实现合约地址
     */
    function deployOptimisticGameImplementation() external onlyOwner returns (address implementation) {
        // 部署一个OptimisticDisputeGame作为实现合约
        // 注意：这里使用的参数只是占位符，不会被实际使用
        OptimisticDisputeGame impl = new OptimisticDisputeGame();
        optimisticGameImplementation = address(impl);
        return optimisticGameImplementation;
    }
    
    /**
     * @dev 部署StakingPool实现合约
     * @return implementation 新部署的StakingPool实现合约地址
     */
    function deployStakingPoolImplementation() external onlyOwner returns (address implementation) {
        // 在新版本中StakingPool构造函数不需要参数
        StakingPool impl = new StakingPool();
        stakingPoolImplementation = address(impl);
        return stakingPoolImplementation;
    }
    
    /**
     * @dev 创建新的OptimisticDisputeGame实例（使用Clone模式）并同时创建两个StakingPool
     * @param _token ERC20代币地址
     * @param _initialStake 初始stake金额
     * @param _attackerAsset 攻击者池使用的资产
     * @param _defenderAsset 防御者池使用的资产
     * @return gameId 新游戏的ID
     * @return gameAddress 新游戏合约的地址
     * @return attackerPoolAddress 攻击者StakingPool地址
     * @return defenderPoolAddress 防御者StakingPool地址
     */
    function createGameWithPools(
        address _token,
        uint256 _initialStake,
        IERC20Metadata _attackerAsset,
        IERC20Metadata _defenderAsset
    ) external returns (
        uint256 gameId,
        address gameAddress,
        address attackerPoolAddress,
        address defenderPoolAddress
    ) {
        require(_initialStake > 0, "Initial stake must be greater than 0");
        require(optimisticGameImplementation != address(0), "Game implementation not set");
        require(stakingPoolImplementation != address(0), "Pool implementation not set");
        require(address(_attackerAsset) != address(0), "Invalid attacker asset");
        require(address(_defenderAsset) != address(0), "Invalid defender asset");
        require(_token != address(0), "Token address cannot be zero");
        
        // 1. 创建两个StakingPool
        address attackerPoolClone = stakingPoolImplementation.clone();
        address defenderPoolClone = stakingPoolImplementation.clone();
        
        // 2. 使用Clone模式创建新的OptimisticDisputeGame实例
        address gameClone = optimisticGameImplementation.clone();
        
        // 3. 初始化游戏合约，使用两个StakingPool作为attacker和defender
        OptimisticDisputeGame(gameClone).initialize(
            attackerPoolClone,
            defenderPoolClone,
            _token,
            _initialStake
        );
        
        // 4. 分配游戏ID
        gameId = ++gameCount;
        gameAddress = gameClone;
        attackerPoolAddress = attackerPoolClone;
        defenderPoolAddress = defenderPoolClone;
        
        // 5. 初始化两个StakingPool
        string memory attackerName = string(abi.encodePacked("Attacker Pool #", _toString(gameId)));
        string memory defenderName = string(abi.encodePacked("Defender Pool #", _toString(gameId)));
        
        string memory attackerSymbol = string(abi.encodePacked("ATK", _toString(gameId)));
        string memory defenderSymbol = string(abi.encodePacked("DEF", _toString(gameId)));
        
        // 修复类型转换问题，使用接口调用模式
        (bool successAttacker,) = attackerPoolClone.call(
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,string,string,address,uint8,address,address)")),
                address(_attackerAsset),
                attackerName,
                attackerSymbol,
                address(this),
                uint8(StakingPool.Role.ATTACKER),
                defenderPoolClone,
                gameClone
            )
        );
        require(successAttacker, "Failed to initialize attacker pool");
        
        (bool successDefender,) = defenderPoolClone.call(
            abi.encodeWithSelector(
                bytes4(keccak256("initialize(address,string,string,address,uint8,address,address)")),
                address(_defenderAsset),
                defenderName,
                defenderSymbol,
                address(this),
                uint8(StakingPool.Role.DEFENDER),
                attackerPoolClone,
                gameClone
            )
        );
        require(successDefender, "Failed to initialize defender pool");
        
        // 6. 存储游戏信息
        games[gameId] = GameInfo({
            gameType: GameType.OPTIMISTIC,
            gameAddress: gameAddress,
            attacker: attackerPoolAddress,
            defender: defenderPoolAddress,
            token: _token,
            initialStake: _initialStake,
            createdAt: block.timestamp,
            attackerPool: attackerPoolAddress,
            defenderPool: defenderPoolAddress
        });
        
        // 7. 更新用户参与的游戏记录
        userGames[attackerPoolAddress].push(gameId);
        userGames[defenderPoolAddress].push(gameId);
        
        // 8. 发出事件
        emit GameCreated(
            gameId,
            GameType.OPTIMISTIC,
            gameAddress,
            attackerPoolAddress,
            defenderPoolAddress,
            _token,
            _initialStake
        );
        
        emit StakingPoolsCreated(
            gameId,
            attackerPoolAddress,
            defenderPoolAddress
        );
        
        return (gameId, gameAddress, attackerPoolAddress, defenderPoolAddress);
    }
    
    /**
     * @dev 设置OptimisticDisputeGame实现合约地址
     * @param _implementation 新的实现合约地址
     */
    function setOptimisticGameImplementation(address _implementation) external onlyOwner {
        require(_implementation != address(0), "Implementation cannot be zero address");
        optimisticGameImplementation = _implementation;
    }
    
    /**
     * @dev 设置StakingPool实现合约地址
     * @param _implementation 新的实现合约地址
     */
    function setStakingPoolImplementation(address _implementation) external onlyOwner {
        require(_implementation != address(0), "Implementation cannot be zero address");
        stakingPoolImplementation = _implementation;
    }
    
    /**
     * @dev 获取游戏信息
     * @param _gameId 游戏ID
     * @return 游戏信息结构
     */
    function getGameInfo(uint256 _gameId) external view returns (GameInfo memory) {
        require(_gameId > 0 && _gameId <= gameCount, "Invalid game ID");
        return games[_gameId];
    }
    
    /**
     * @dev 获取用户参与的所有游戏ID
     * @param _user 用户地址
     * @return 游戏ID数组
     */
    function getUserGames(address _user) external view returns (uint256[] memory) {
        return userGames[_user];
    }
    
    /**
     * @dev 获取用户作为攻击者的游戏
     * @param _user 用户地址
     * @return 游戏ID数组
     */
    function getUserAttackerGames(address _user) external view returns (uint256[] memory) {
        uint256[] memory userGameIds = userGames[_user];
        uint256[] memory attackerGames = new uint256[](userGameIds.length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < userGameIds.length; i++) {
            if (games[userGameIds[i]].attacker == _user) {
                attackerGames[count] = userGameIds[i];
                count++;
            }
        }
        
        // 裁剪数组到实际大小
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = attackerGames[i];
        }
        
        return result;
    }
    
    /**
     * @dev 获取用户作为防御者的游戏
     * @param _user 用户地址
     * @return 游戏ID数组
     */
    function getUserDefenderGames(address _user) external view returns (uint256[] memory) {
        uint256[] memory userGameIds = userGames[_user];
        uint256[] memory defenderGames = new uint256[](userGameIds.length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < userGameIds.length; i++) {
            if (games[userGameIds[i]].defender == _user) {
                defenderGames[count] = userGameIds[i];
                count++;
            }
        }
        
        // 裁剪数组到实际大小
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = defenderGames[i];
        }
        
        return result;
    }
    
    /**
     * @dev 获取特定代币的所有游戏
     * @param _token 代币地址
     * @return 游戏ID数组
     */
    function getTokenGames(address _token) external view returns (uint256[] memory) {
        uint256[] memory tokenGames = new uint256[](gameCount);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= gameCount; i++) {
            if (games[i].token == _token) {
                tokenGames[count] = i;
                count++;
            }
        }
        
        // 裁剪数组到实际大小
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tokenGames[i];
        }
        
        return result;
    }
    
    /**
     * @dev 获取活跃游戏列表 (不进行链上状态检查，仅返回创建的游戏)
     * @param _startId 起始游戏ID
     * @param _count 获取的游戏数量
     * @return 游戏ID数组
     */
    function getActiveGames(uint256 _startId, uint256 _count) external view returns (uint256[] memory) {
        require(_startId > 0 && _startId <= gameCount, "Invalid start ID");
        
        uint256 actualCount = _count;
        if (_startId + _count - 1 > gameCount) {
            actualCount = gameCount - _startId + 1;
        }
        
        uint256[] memory activeGames = new uint256[](actualCount);
        
        for (uint256 i = 0; i < actualCount; i++) {
            activeGames[i] = _startId + i;
        }
        
        return activeGames;
    }
    
    /**
     * @dev 设置默认超时扩展时间
     * @param _timeoutExtension 新的超时扩展时间（秒）
     */
    function setDefaultTimeoutExtension(uint256 _timeoutExtension) external onlyOwner {
        defaultTimeoutExtension = _timeoutExtension;
    }
    
    /**
     * @dev 将数字转换为字符串的辅助函数
     * @param value 要转换的数字
     * @return 数字的字符串表示
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        // 特殊情况处理：值为0
        if (value == 0) {
            return "0";
        }
        
        // 计算数字的位数
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        // 构建字符串
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
}
