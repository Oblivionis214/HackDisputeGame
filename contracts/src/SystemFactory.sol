// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ISystemFactory.sol";
import "./interfaces/IDisputeGameFactory.sol";
import "./interfaces/IOptimisticDisputeGameResolver.sol";
import "./interfaces/IERC20Wrapper.sol";
import "./interfaces/IOptimisticDisputeGame.sol";
import "./interfaces/IStakingPool.sol";

// Import implementations for deployment
import "./DisputeGameFactory.sol";
import "./DisputeResolver/OptimisticDisputeGameResolver.sol";
import "./ERC20Wrapper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SystemFactory
 * @author Oblivionis
 * @notice Factory contract for creating and deploying the complete dispute resolution system
 * @dev Deploys DisputeGameFactory, OptimisticDisputeGameResolver and ERC20Wrapper
 */
contract SystemFactory is Ownable {
    // Deployed contract addresses
    address public gameFactoryAddress;
    address public resolverAddress;
    address public wrapperAddress;
    
    // Implementation contract addresses
    address public immutable optimisticGameImplementation;
    address public immutable stakingPoolImplementation;
    
    // Precomputed contract creation bytecodes
    bytes private factoryCreationCodeBase;
    bytes private resolverCreationCodeBase;
    bytes private wrapperCreationCodeBase;
    
    // Deployment event
    event SystemDeployed(
        address gameFactory,
        address resolver,
        address wrapper
    );
    
    /**
     * @notice Constructor initializes implementation contract addresses and precomputes bytecodes
     * @param _optimisticGameImplementation OptimisticDisputeGame implementation contract address
     * @param _stakingPoolImplementation StakingPool implementation contract address
     */
    constructor(
        address _optimisticGameImplementation,
        address _stakingPoolImplementation
    ) Ownable(msg.sender) {
        require(_optimisticGameImplementation != address(0), "Game implementation cannot be zero");
        require(_stakingPoolImplementation != address(0), "Pool implementation cannot be zero");
        
        optimisticGameImplementation = _optimisticGameImplementation;
        stakingPoolImplementation = _stakingPoolImplementation;
        
        // Precompute base bytecodes
        factoryCreationCodeBase = type(DisputeGameFactory).creationCode;
        resolverCreationCodeBase = type(OptimisticDisputeGameResolver).creationCode; 
        wrapperCreationCodeBase = type(ERC20Wrapper).creationCode;
    }
    
    /**
     * @notice Deploy the complete system components using low-level create
     * @param _disputeStake Dispute stake amount
     * @param _validationTimeout Validation timeout period (in seconds)
     * @param _name Wrapper token name
     * @param _symbol Wrapper token symbol
     * @param _underlyingToken Underlying token address
     * @return factory Deployed DisputeGameFactory address
     * @return resolver Deployed OptimisticDisputeGameResolver address
     * @return wrapper Deployed ERC20Wrapper address
     */
    function deploySystem(
        uint256 _disputeStake,
        uint256 _validationTimeout,
        string memory _name,
        string memory _symbol,
        address _underlyingToken
    ) 
        external 
        onlyOwner
        returns (
            address factory,
            address resolver,
            address wrapper
        ) 
    {
        require(_underlyingToken != address(0), "Underlying token cannot be zero");
        require(_disputeStake > 0, "Dispute stake must be greater than 0");
        require(_validationTimeout > 0, "Validation timeout must be greater than 0");
        
        // 1. Deploy DisputeGameFactory using create
        bytes memory factoryCreationCode = abi.encodePacked(
            factoryCreationCodeBase,
            abi.encode(optimisticGameImplementation, stakingPoolImplementation)
        );
        
        address factoryAddress;
        assembly {
            factoryAddress := create(0, add(factoryCreationCode, 0x20), mload(factoryCreationCode))
            if iszero(extcodesize(factoryAddress)) {
                revert(0, 0)
            }
        }
        gameFactoryAddress = factoryAddress;
        
        // 2. Deploy OptimisticDisputeGameResolver using create
        bytes memory resolverCreationCode = abi.encodePacked(
            resolverCreationCodeBase,
            abi.encode(gameFactoryAddress, _disputeStake, _validationTimeout)
        );
        
        address resolverAddress_;
        assembly {
            resolverAddress_ := create(0, add(resolverCreationCode, 0x20), mload(resolverCreationCode))
            if iszero(extcodesize(resolverAddress_)) {
                revert(0, 0)
            }
        }
        resolverAddress = resolverAddress_;
        
        // 3. Deploy ERC20Wrapper using create
        bytes memory wrapperCreationCode = abi.encodePacked(
            wrapperCreationCodeBase,
            abi.encode(_name, _symbol, _underlyingToken, resolverAddress)
        );
        
        address wrapperAddress_;
        assembly {
            wrapperAddress_ := create(0, add(wrapperCreationCode, 0x20), mload(wrapperCreationCode))
            if iszero(extcodesize(wrapperAddress_)) {
                revert(0, 0)
            }
        }
        wrapperAddress = wrapperAddress_;
        
        // 4. Set wrapper address in resolver
        OptimisticDisputeGameResolver(resolverAddress).setTokenWrapper(wrapperAddress);
        
        // Emit system deployment event
        emit SystemDeployed(
            gameFactoryAddress,
            resolverAddress,
            wrapperAddress
        );
        
        return (gameFactoryAddress, resolverAddress, wrapperAddress);
    }
} 