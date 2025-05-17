// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IBaseDisputeResolver.sol";
import "../DisputeGame/OptimisticDisputeGame.sol";

/**
 * @title IOptimisticDisputeGameResolver
 * @notice Interface for the OptimisticDisputeGameResolver contract
 */
interface IOptimisticDisputeGameResolver is IBaseDisputeResolver {
    // Events
    event DisputeCreated(uint256 indexed requestId, uint256 indexed gameId, address attacker);
    event DisputeResolved(uint256 indexed requestId, uint256 indexed gameId, bool upheld);
    
    /**
     * @notice Create a dispute for a withdrawal request
     * @param requestId ID of the withdrawal request to dispute
     * @return gameId ID of the created dispute game
     */
    function dispute(uint256 requestId) external returns (uint256 gameId);
    
    /**
     * @notice Resolve a dispute for a withdrawal request
     * @param requestId ID of the withdrawal request
     * @return success Whether resolution was successful
     */
    function resolve(uint256 requestId) external returns (bool success);
    
    /**
     * @notice Get information about a dispute game for a withdrawal request
     * @param requestId ID of the withdrawal request
     * @return exists Whether a dispute exists
     * @return gameId ID of the dispute game
     * @return gameAddress Address of the dispute game contract
     * @return gameState Current state of the dispute game
     */
    function getDisputeGame(uint256 requestId) external view returns (
        bool exists,
        uint256 gameId,
        address gameAddress,
        OptimisticDisputeGame.GameState gameState
    );
    
    /**
     * @notice Get the DisputeGameFactory address
     */
    function gameFactory() external view returns (address);
    
    /**
     * @notice Get the dispute stake amount
     */
    function disputeStake() external view returns (uint256);
    
    /**
     * @notice Get the game ID for a withdrawal request
     */
    function disputeGames(uint256 requestId) external view returns (uint256);
    
    /**
     * @notice Get the request ID for a game
     */
    function gameDisputes(uint256 gameId) external view returns (uint256);
} 