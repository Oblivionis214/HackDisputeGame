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
 * @author Oblivionis
 * @notice ERC4626-compliant staking pool that acts as attacker or defender in OptimisticDisputeGame
 * @dev Users can deposit tokens into the pool, and when sufficient funds are available, 
 *      the pool automatically participates in the game.
 *      Each pool supports only one game, created by DisputeGameFactory.
 */
contract StakingPool is Initializable, ERC4626Upgradeable {
    using Math for uint256;
    
    enum Role { ATTACKER, DEFENDER }
    enum PoolState { UNINITIALIZED, ACTIVE }
    
    // Pool role
    Role public poolRole;
    
    // Pool state
    PoolState public state;
    
    // Dispute game factory
    DisputeGameFactory public gameFactory;
    
    // Opponent address (another StakingPool)
    address public opponent;
    
    // Game contract address
    address public gameAddress;
    
    // Game information
    struct GameData {
        uint256 initialStake;     // Initial stake amount
        uint256 totalStaked;      // Total staked amount
        address token;            // Token used in the game
    }
    
    // Current game data
    GameData public currentGame;
    
    // Events
    event GameInitialized(address indexed gameAddress, address indexed opponent);
    event TurnPlayed(address indexed gameAddress, uint256 amount);
    
    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Initialization function - used for proxy pattern
     * @param _asset Base asset token
     * @param _name Staking pool token name
     * @param _symbol Staking pool token symbol
     * @param _gameFactory Dispute game factory address
     * @param _poolRole Pool role (attacker or defender)
     * @param _opponent Game opponent address (another StakingPool)
     * @param _gameAddress Game contract address
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
        
        // Initialize ERC20Upgradeable and ERC4626Upgradeable
        __ERC20_init(_name, _symbol);
        __ERC4626_init(_asset);
        
        // Initialize StakingPool specific attributes
        gameFactory = DisputeGameFactory(_gameFactory);
        poolRole = _poolRole;
        opponent = _opponent;
        gameAddress = _gameAddress;
        state = PoolState.ACTIVE;
        
        // Get game information
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
     * @notice Deposits assets and automatically attempts to play a game turn
     * @dev When deposits are sufficient, automatically calls attack/defend
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        // Use parent contract's deposit function to handle deposits
        uint256 shares = super.deposit(assets, receiver);
        
        // If the game is active, try to execute a game turn
        if (state == PoolState.ACTIVE) {
            _tryPlayTurn();
        }
        
        return shares;
    }
    
    /**
     * @notice Mints shares and automatically attempts to play a game turn
     */
    function mint(uint256 shares, address receiver) public override returns (uint256) {
        // Use parent contract's mint function to handle minting
        uint256 assets = super.mint(shares, receiver);
        
        // If the game is active, try to execute a game turn
        if (state == PoolState.ACTIVE) {
            _tryPlayTurn();
        }
        
        return assets;
    }
    
    /**
     * @notice Withdraws assets and burns corresponding shares from owner
     */
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        // Use parent contract's withdraw function to handle withdrawals
        return super.withdraw(assets, receiver, owner);
    }
    
    /**
     * @notice Redeems shares and sends corresponding assets to the receiver
     */
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        // Use parent contract's redeem function to handle redemption
        return super.redeem(shares, receiver, owner);
    }
    
    /**
     * @notice Attempts to play a game turn (internal function)
     * @dev Checks game state, determines if it's our turn, and takes action if possible
     */
    function _tryPlayTurn() internal {
        // Check game state
        OptimisticDisputeGame disputeGame = OptimisticDisputeGame(gameAddress);
        
        // Get game information
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
        
        // If the game has ended, do nothing
        if (_gameState != OptimisticDisputeGame.GameState.ACTIVE) {
            return;
        }
        
        // Check if it's our turn
        bool isOurTurn = (poolRole == Role.ATTACKER && _currentTurn == OptimisticDisputeGame.Turn.ATTACKER) ||
                         (poolRole == Role.DEFENDER && _currentTurn == OptimisticDisputeGame.Turn.DEFENDER);
        
        if (!isOurTurn) {
            return; // Not our turn, skip
        }
        
        // Check if pool has sufficient assets
        uint256 poolAssetBalance = IERC20Metadata(asset()).balanceOf(address(this));
        if (poolAssetBalance < _currentRequiredStake) {
            return; // Insufficient funds, skip
        }
        
        // Prepare to attack or defend
        IERC20(currentGame.token).approve(gameAddress, _currentRequiredStake);
        
        if (poolRole == Role.ATTACKER) {
            disputeGame.attack();
        } else {
            disputeGame.defend();
        }
        
        // Update total staked amount
        currentGame.totalStaked += _currentRequiredStake;
        
        emit TurnPlayed(gameAddress, _currentRequiredStake);
    }
    
    /**
     * @notice Manually triggers a game turn
     * @dev Can be used when automatic attempts fail
     */
    function playTurn() external {
        require(state == PoolState.ACTIVE, "No active game");
        _tryPlayTurn();
    }
    
    /**
     * @notice Gets current game status information
     * @return _state Current pool state
     * @return _gameAddress Game contract address
     * @return _totalStaked Total staked amount
     * @return _isOurTurn Whether it's our turn in the game
     * @return _requiredStake Amount required for the next stake
     * @return _hasEnoughFunds Whether the pool has enough funds for the next move
     * @return _isGameActive Whether the game is still active
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
        
        // Check if it's our turn
        bool isOurTurn = (poolRole == Role.ATTACKER && _currentTurn == OptimisticDisputeGame.Turn.ATTACKER) ||
                         (poolRole == Role.DEFENDER && _currentTurn == OptimisticDisputeGame.Turn.DEFENDER);
        
        // Check if we have enough funds
        uint256 poolAssetBalance = IERC20Metadata(asset()).balanceOf(address(this));
        bool hasEnoughFunds = poolAssetBalance >= _currentRequiredStake;
        
        // Check if the game is active
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
