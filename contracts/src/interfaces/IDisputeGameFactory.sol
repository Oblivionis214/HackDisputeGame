// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title IDisputeGameFactory
 * @notice Interface for the DisputeGameFactory contract
 */
interface IDisputeGameFactory {
    enum GameType { OPTIMISTIC }
    
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
    
    // Events
    event GameCreated(
        uint256 indexed gameId,
        GameType gameType,
        address gameAddress,
        address attacker,
        address defender,
        address token,
        uint256 initialStake
    );
    
    event StakingPoolsCreated(
        uint256 indexed gameId,
        address attackerPoolAddress,
        address defenderPoolAddress
    );
    
    /**
     * @notice Create a new game with staking pools
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
    );
    
    /**
     * @notice Deploy the game implementation contract
     */
    function deployOptimisticGameImplementation() external returns (address implementation);
    
    /**
     * @notice Deploy the staking pool implementation contract
     */
    function deployStakingPoolImplementation() external returns (address implementation);
    
    /**
     * @notice Set the game implementation address
     */
    function setOptimisticGameImplementation(address _implementation) external;
    
    /**
     * @notice Set the staking pool implementation address
     */
    function setStakingPoolImplementation(address _implementation) external;
    
    /**
     * @notice Get information about a game
     */
    function getGameInfo(uint256 _gameId) external view returns (GameInfo memory);
    
    /**
     * @notice Get all games a user has participated in
     */
    function getUserGames(address _user) external view returns (uint256[] memory);
    
    /**
     * @notice Get user's attacker games
     */
    function getUserAttackerGames(address _user) external view returns (uint256[] memory);
    
    /**
     * @notice Get user's defender games
     */
    function getUserDefenderGames(address _user) external view returns (uint256[] memory);
    
    /**
     * @notice Get all games for a token
     */
    function getTokenGames(address _token) external view returns (uint256[] memory);
    
    /**
     * @notice Get active games
     */
    function getActiveGames(uint256 _startId, uint256 _count) external view returns (uint256[] memory);
    
    /**
     * @notice Set the default timeout extension
     */
    function setDefaultTimeoutExtension(uint256 _timeoutExtension) external;
    
    /**
     * @notice Get the optimistic game implementation address
     */
    function optimisticGameImplementation() external view returns (address);
    
    /**
     * @notice Get the staking pool implementation address
     */
    function stakingPoolImplementation() external view returns (address);
    
    /**
     * @notice Get the game count
     */
    function gameCount() external view returns (uint256);
    
    /**
     * @notice Get the default timeout extension
     */
    function defaultTimeoutExtension() external view returns (uint256);
    
    /**
     * @notice Access the games mapping
     */
    function games(uint256 _gameId) external view returns (
        GameType gameType,
        address gameAddress,
        address attacker,
        address defender,
        address token,
        uint256 initialStake,
        uint256 createdAt,
        address attackerPool,
        address defenderPool
    );
} 