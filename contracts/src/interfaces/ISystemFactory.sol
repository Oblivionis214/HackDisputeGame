// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ISystemFactory
 * @notice Interface for the SystemFactory contract
 */
interface ISystemFactory {
    // Events
    event SystemDeployed(
        address gameFactory,
        address resolver,
        address wrapper
    );
    
    /**
     * @notice Deploy a complete system
     * @param _disputeStake Dispute stake amount
     * @param _validationTimeout Validation timeout period
     * @param _name Wrapper token name
     * @param _symbol Wrapper token symbol
     * @param _underlyingToken Underlying token address
     * @return factory DisputeGameFactory address
     * @return resolver OptimisticDisputeGameResolver address
     * @return wrapper ERC20Wrapper address
     */
    function deploySystem(
        uint256 _disputeStake,
        uint256 _validationTimeout,
        string memory _name,
        string memory _symbol,
        address _underlyingToken
    ) external returns (
        address factory,
        address resolver,
        address wrapper
    );
    
    /**
     * @notice Get the optimistic game implementation address
     */
    function optimisticGameImplementation() external view returns (address);
    
    /**
     * @notice Get the staking pool implementation address
     */
    function stakingPoolImplementation() external view returns (address);
    
    /**
     * @notice Get the game factory address of the latest deployment
     */
    function gameFactoryAddress() external view returns (address);
    
    /**
     * @notice Get the resolver address of the latest deployment
     */
    function resolverAddress() external view returns (address);
    
    /**
     * @notice Get the wrapper address of the latest deployment
     */
    function wrapperAddress() external view returns (address);
} 