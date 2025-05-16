// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DisputeGameFactory
 * @author Oblivionis
 * @notice Factory contract for creating and managing dispute game instances
 * @dev Uses Clone pattern to reduce gas costs when creating OptimisticDisputeGame instances
 *      and simultaneously creates corresponding StakingPools as attacker and defender
 */

import "./DisputeGame/OptimisticDisputeGame.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./StakingPool.sol";

contract DisputeGameFactory is Ownable {
    // Use OpenZeppelin's Clones library
    using Clones for address;

    // Game type enumeration
    enum GameType { OPTIMISTIC }
    
    // Game creation event
    event GameCreated(
        uint256 indexed gameId,
        GameType gameType,
        address gameAddress,
        address attacker,
        address defender,
        address token,
        uint256 initialStake
    );
    
    // StakingPool creation event
    event StakingPoolsCreated(
        uint256 indexed gameId,
        address attackerPoolAddress,
        address defenderPoolAddress
    );
    
    // Store information for all created games
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
    
    // OptimisticDisputeGame implementation address (used as template)
    address public optimisticGameImplementation;
    
    // StakingPool implementation address (used as template)
    address public stakingPoolImplementation;
    
    // Mapping from game ID to game information
    mapping(uint256 => GameInfo) public games;
    
    // List of game IDs a user has participated in
    mapping(address => uint256[]) public userGames;
    
    // Total number of games
    uint256 public gameCount;
    
    // Game timeout extension (can be set by admin)
    uint256 public defaultTimeoutExtension;
    
    /**
     * @notice Constructor initializes the factory with implementation addresses
     * @param _optimisticGameImplementation OptimisticDisputeGame implementation contract address
     * @param _stakingPoolImplementation StakingPool implementation contract address
     */
    constructor(address _optimisticGameImplementation, address _stakingPoolImplementation) Ownable(msg.sender) {
        require(_optimisticGameImplementation != address(0), "Game implementation cannot be zero");
        require(_stakingPoolImplementation != address(0), "Pool implementation cannot be zero");
        
        optimisticGameImplementation = _optimisticGameImplementation;
        stakingPoolImplementation = _stakingPoolImplementation;
        defaultTimeoutExtension = 2 hours; // Default timeout extension
    }
    
    /**
     * @notice Deploy the game implementation contract
     * @dev Should be called once after factory deployment
     * @return implementation Address of the newly deployed implementation contract
     */
    function deployOptimisticGameImplementation() external onlyOwner returns (address implementation) {
        // Deploy an OptimisticDisputeGame as implementation contract
        // Note: Parameters used here are just placeholders and won't be used in practice
        OptimisticDisputeGame impl = new OptimisticDisputeGame();
        optimisticGameImplementation = address(impl);
        return optimisticGameImplementation;
    }
    
    /**
     * @notice Deploy the StakingPool implementation contract
     * @return implementation Address of the newly deployed StakingPool implementation
     */
    function deployStakingPoolImplementation() external onlyOwner returns (address implementation) {
        // In the new version, StakingPool constructor doesn't require parameters
        StakingPool impl = new StakingPool();
        stakingPoolImplementation = address(impl);
        return stakingPoolImplementation;
    }
    
    /**
     * @notice Create a new OptimisticDisputeGame instance using Clone pattern and simultaneously create two StakingPools
     * @param _token ERC20 token address
     * @param _initialStake Initial stake amount
     * @param _attackerAsset Asset used by the attacker pool
     * @param _defenderAsset Asset used by the defender pool
     * @return gameId ID of the new game
     * @return gameAddress Address of the new game contract
     * @return attackerPoolAddress Address of the attacker's StakingPool
     * @return defenderPoolAddress Address of the defender's StakingPool
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
        
        // 1. Create two StakingPools
        address attackerPoolClone = stakingPoolImplementation.clone();
        address defenderPoolClone = stakingPoolImplementation.clone();
        
        // 2. Use Clone pattern to create a new OptimisticDisputeGame instance
        address gameClone = optimisticGameImplementation.clone();
        
        // 3. Initialize the game contract using the two StakingPools as attacker and defender
        OptimisticDisputeGame(gameClone).initialize(
            attackerPoolClone,
            defenderPoolClone,
            _token,
            _initialStake
        );
        
        // 4. Assign game ID
        gameId = ++gameCount;
        gameAddress = gameClone;
        attackerPoolAddress = attackerPoolClone;
        defenderPoolAddress = defenderPoolClone;
        
        // 5. Initialize the two StakingPools
        string memory attackerName = string(abi.encodePacked("Attacker Pool #", _toString(gameId)));
        string memory defenderName = string(abi.encodePacked("Defender Pool #", _toString(gameId)));
        
        string memory attackerSymbol = string(abi.encodePacked("ATK", _toString(gameId)));
        string memory defenderSymbol = string(abi.encodePacked("DEF", _toString(gameId)));
        
        // Fix type conversion issues using interface call pattern
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
        
        // 6. Store game information
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
        
        // 7. Update record of games the user has participated in
        userGames[attackerPoolAddress].push(gameId);
        userGames[defenderPoolAddress].push(gameId);
        
        // 8. Emit events
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
     * @notice Set the OptimisticDisputeGame implementation contract address
     * @param _implementation New implementation contract address
     */
    function setOptimisticGameImplementation(address _implementation) external onlyOwner {
        require(_implementation != address(0), "Implementation cannot be zero address");
        optimisticGameImplementation = _implementation;
    }
    
    /**
     * @notice Set the StakingPool implementation contract address
     * @param _implementation New implementation contract address
     */
    function setStakingPoolImplementation(address _implementation) external onlyOwner {
        require(_implementation != address(0), "Implementation cannot be zero address");
        stakingPoolImplementation = _implementation;
    }
    
    /**
     * @notice Get game information
     * @param _gameId Game ID
     * @return Game information structure
     */
    function getGameInfo(uint256 _gameId) external view returns (GameInfo memory) {
        require(_gameId > 0 && _gameId <= gameCount, "Invalid game ID");
        return games[_gameId];
    }
    
    /**
     * @notice Get all game IDs that a user has participated in
     * @param _user User address
     * @return Array of game IDs
     */
    function getUserGames(address _user) external view returns (uint256[] memory) {
        return userGames[_user];
    }
    
    /**
     * @notice Get games where the user is an attacker
     * @param _user User address
     * @return Array of game IDs
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
        
        // Resize array to actual size
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = attackerGames[i];
        }
        
        return result;
    }
    
    /**
     * @notice Get games where the user is a defender
     * @param _user User address
     * @return Array of game IDs
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
        
        // Resize array to actual size
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = defenderGames[i];
        }
        
        return result;
    }
    
    /**
     * @notice Get all games for a specific token
     * @param _token Token address
     * @return Array of game IDs
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
        
        // Resize array to actual size
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tokenGames[i];
        }
        
        return result;
    }
    
    /**
     * @notice Get list of active games (does not check on-chain state, only returns created games)
     * @param _startId Starting game ID
     * @param _count Number of games to fetch
     * @return Array of game IDs
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
     * @notice Set the default timeout extension period
     * @param _timeoutExtension New timeout extension period (in seconds)
     */
    function setDefaultTimeoutExtension(uint256 _timeoutExtension) external onlyOwner {
        defaultTimeoutExtension = _timeoutExtension;
    }
    
    /**
     * @notice Helper function to convert a number to a string
     * @param value Number to convert
     * @return String representation of the number
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        // Handle special case: value is 0
        if (value == 0) {
            return "0";
        }
        
        // Calculate number of digits
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        
        // Build string
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        
        return string(buffer);
    }
}
