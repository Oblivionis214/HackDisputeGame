// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OptimisticDisputeGame {
    address public attacker;
    address public defender;
    
    enum Turn { ATTACKER, DEFENDER }
    enum GameState { ACTIVE, ATTACKER_WON, DEFENDER_WON }
    
    Turn public currentTurn;
    GameState public gameState;
    
    uint256 public attackerStake;
    uint256 public defenderStake;
    
    uint256 public timeoutTimestamp;
    uint256 public timeoutExtension;
    
    address public token; // ERC20代币地址
    uint256 public initialStake; // 初始stake金额
    uint256 public currentRequiredStake; // 当前轮次需要的stake金额
    
    // 表示合约是否已初始化
    bool private initialized;
    
    event Attack(address indexed attacker, uint256 amount, uint256 newTimeoutTimestamp);
    event Defend(address indexed defender, uint256 amount, uint256 newTimeoutTimestamp);
    event GameEnded(GameState result, address winner, uint256 winnings);
    
    modifier onlyAttacker() {
        require(msg.sender == attacker, "Only attacker can call this function");
        _;
    }
    
    modifier onlyDefender() {
        require(msg.sender == defender, "Only defender can call this function");
        _;
    }
    
    modifier gameActive() {
        require(gameState == GameState.ACTIVE, "Game is not active");
        _;
    }
    
    // 防止重复初始化
    modifier initializer() {
        require(!initialized, "Contract is already initialized");
        _;
        initialized = true;
    }
    
    constructor() {
        initialized = true;
    }
    
    /**
     * @dev 初始化函数，用于Clone模式下的合约初始化
     * @param _attacker 攻击者地址
     * @param _defender 防御者地址
     * @param _token ERC20代币地址
     * @param _initialStake 初始stake金额
     */
    function initialize(address _attacker, address _defender, address _token, uint256 _initialStake) external initializer {
        _initialize(_attacker, _defender, _token, _initialStake);
    }
    
    /**
     * @dev 内部初始化逻辑，被构造函数和initialize函数共用
     */
    function _initialize(address _attacker, address _defender, address _token, uint256 _initialStake) internal {
        require(_attacker != address(0) && _defender != address(0), "Invalid addresses");
        require(_attacker != _defender, "Attacker and defender must be different");
        require(_initialStake > 0, "Initial stake must be greater than 0");
        require(_token != address(0), "Token address cannot be zero");
        
        attacker = _attacker;
        defender = _defender;
        token = _token;
        initialStake = _initialStake;
        currentRequiredStake = _initialStake; // 设置初始stake金额
        
        // 初始化为攻击者的回合
        currentTurn = Turn.ATTACKER;
        gameState = GameState.ACTIVE;
        
        // 设置超时时间，默认为2小时
        timeoutExtension = 2 hours;
        timeoutTimestamp = block.timestamp + timeoutExtension;
    }
    
    function attack() external onlyAttacker gameActive {
        require(currentTurn == Turn.ATTACKER, "Not attacker's turn");
        
        // 检查是否已超时，如果超时则直接revert
        require(block.timestamp <= timeoutTimestamp, "Game has timed out");
        
        // 从用户处获取ERC20代币，要求精确的金额
        bool success = IERC20(token).transferFrom(msg.sender, address(this), currentRequiredStake);
        require(success, "Token transfer failed");
        
        // 增加攻击者的stake
        attackerStake += currentRequiredStake;
        
        // 更新下一轮defender需要的stake金额，等于当前attacker的stake
        currentRequiredStake = currentRequiredStake;
        
        // 更新超时时间
        timeoutTimestamp = block.timestamp + timeoutExtension;
        
        // 转换回合
        currentTurn = Turn.DEFENDER;
        
        emit Attack(msg.sender, currentRequiredStake, timeoutTimestamp);
    }
    
    function defend() external onlyDefender gameActive {
        require(currentTurn == Turn.DEFENDER, "Not defender's turn");
        
        // 检查是否已超时，如果超时则直接revert
        require(block.timestamp <= timeoutTimestamp, "Game has timed out");
        
        // 从用户处获取ERC20代币，要求精确的金额
        bool success = IERC20(token).transferFrom(msg.sender, address(this), currentRequiredStake);
        require(success, "Token transfer failed");
        
        // 增加防御者的stake
        defenderStake += currentRequiredStake;
        
        // 更新下一轮attacker需要的stake金额，是当前stake的两倍
        currentRequiredStake = currentRequiredStake * 2;
        
        // 更新超时时间
        timeoutTimestamp = block.timestamp + timeoutExtension;
        
        // 转换回合
        currentTurn = Turn.ATTACKER;
        
        emit Defend(msg.sender, currentRequiredStake / 2, timeoutTimestamp);
    }
    
    function claimTimeout() external gameActive {
        require(block.timestamp > timeoutTimestamp, "Timeout not reached yet");
        
        if (currentTurn == Turn.ATTACKER) {
            _endGame(GameState.DEFENDER_WON);
        } else {
            _endGame(GameState.ATTACKER_WON);
        }
    }
    
    function _endGame(GameState result) private {
        gameState = result;
        
        address winner;
        uint256 winnings = attackerStake + defenderStake;
        
        if (result == GameState.ATTACKER_WON) {
            winner = attacker;
        } else {
            winner = defender;
        }
        
        emit GameEnded(result, winner, winnings);
        
        // 将所有资金发送给获胜者
        bool success = IERC20(token).transfer(winner, winnings);
        require(success, "Token transfer to winner failed");
    }
    
    // 获取当前游戏状态信息
    function getGameInfo() external view returns (
        address _attacker,
        address _defender,
        Turn _currentTurn,
        GameState _gameState,
        uint256 _attackerStake,
        uint256 _defenderStake,
        uint256 _timeoutTimestamp,
        uint256 _timeoutExtension,
        address _token,
        uint256 _initialStake,
        uint256 _currentRequiredStake
    ) {
        return (
            attacker,
            defender,
            currentTurn,
            gameState,
            attackerStake,
            defenderStake,
            timeoutTimestamp,
            timeoutExtension,
            token,
            initialStake,
            currentRequiredStake
        );
    }
    
    // 获取当前所需stake金额
    function getRequiredStake() external view returns (uint256) {
        return currentRequiredStake;
    }
} 