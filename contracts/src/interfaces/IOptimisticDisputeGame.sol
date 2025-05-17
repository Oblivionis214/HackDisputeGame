// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IOptimisticDisputeGame
 * @notice Interface for the OptimisticDisputeGame contract
 */
interface IOptimisticDisputeGame {
    enum Turn { ATTACKER, DEFENDER }
    enum GameState { ACTIVE, ATTACKER_WON, DEFENDER_WON }
    
    // Events
    event Attack(address indexed attacker, uint256 amount, uint256 newTimeoutTimestamp);
    event Defend(address indexed defender, uint256 amount, uint256 newTimeoutTimestamp);
    event GameEnded(GameState result, address winner, uint256 winnings);
    
    /**
     * @notice Initialize a game with the given parameters
     */
    function initialize(address _attacker, address _defender, address _token, uint256 _initialStake) external;
    
    /**
     * @notice Attacker makes a move by staking tokens
     */
    function attack() external;
    
    /**
     * @notice Defender makes a move by staking tokens
     */
    function defend() external;
    
    /**
     * @notice Claim timeout if the opponent doesn't respond in time
     */
    function claimTimeout() external;
    
    /**
     * @notice Get current game information
     */
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
    );
    
    /**
     * @notice Get current required stake amount
     */
    function getRequiredStake() external view returns (uint256);
    
    /**
     * @notice Get the attacker address
     */
    function attacker() external view returns (address);
    
    /**
     * @notice Get the defender address
     */
    function defender() external view returns (address);
    
    /**
     * @notice Get the current turn
     */
    function currentTurn() external view returns (Turn);
    
    /**
     * @notice Get the current game state
     */
    function gameState() external view returns (GameState);
    
    /**
     * @notice Get the attacker's stake
     */
    function attackerStake() external view returns (uint256);
    
    /**
     * @notice Get the defender's stake
     */
    function defenderStake() external view returns (uint256);
    
    /**
     * @notice Get the timeout timestamp
     */
    function timeoutTimestamp() external view returns (uint256);
    
    /**
     * @notice Get the timeout extension
     */
    function timeoutExtension() external view returns (uint256);
    
    /**
     * @notice Get the token address
     */
    function token() external view returns (address);
    
    /**
     * @notice Get the initial stake amount
     */
    function initialStake() external view returns (uint256);
    
    /**
     * @notice Get the current required stake amount
     */
    function currentRequiredStake() external view returns (uint256);
} 