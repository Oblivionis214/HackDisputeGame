// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title IStakingPool
 * @notice Interface for the StakingPool contract
 */
interface IStakingPool is IERC4626 {
    enum Role { ATTACKER, DEFENDER }
    enum PoolState { UNINITIALIZED, ACTIVE }
    
    struct GameData {
        uint256 initialStake;
        uint256 totalStaked;
        address token;
    }
    
    // Events
    event GameInitialized(address indexed gameAddress, address indexed opponent);
    event TurnPlayed(address indexed gameAddress, uint256 amount);
    
    /**
     * @notice Initialization function
     */
    function initialize(
        IERC20Metadata _asset,
        string memory _name,
        string memory _symbol,
        address _gameFactory,
        Role _poolRole,
        address _opponent,
        address _gameAddress
    ) external;
    
    /**
     * @notice Manually triggers a game turn
     */
    function playTurn() external;
    
    /**
     * @notice Gets current game status information
     */
    function getGameStatus() external view returns (
        PoolState _state,
        address _gameAddress,
        uint256 _totalStaked,
        bool _isOurTurn,
        uint256 _requiredStake,
        bool _hasEnoughFunds,
        bool _isGameActive
    );
    
    /**
     * @notice Get the pool role (attacker or defender)
     */
    function poolRole() external view returns (Role);
    
    /**
     * @notice Get the pool state
     */
    function state() external view returns (PoolState);
    
    /**
     * @notice Get the game factory address
     */
    function gameFactory() external view returns (address);
    
    /**
     * @notice Get the opponent pool address
     */
    function opponent() external view returns (address);
    
    /**
     * @notice Get the game address
     */
    function gameAddress() external view returns (address);
    
    /**
     * @notice Get the current game data
     */
    function currentGame() external view returns (GameData memory);
} 