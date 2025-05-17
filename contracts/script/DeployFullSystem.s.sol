// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/SystemFactory.sol";

/**
 * @title DeployFullSystem
 * @notice Script for deploying the complete system
 * @dev First deploys SystemFactory, then calls deploySystem function to deploy the complete system
 */
contract DeployFullSystem is Script {
    // Addresses of deployed implementation contracts
    address public constant OPTIMISTIC_GAME_IMPL = 0x04409D09EA82d3954A23655f3640428C879F7442;
    address public constant STAKING_POOL_IMPL = 0x0fbeBD16a02c26ecE90f39cd422D317C17dD808d;
    
    // Existing ERC20 token address
    address public constant UNDERLYING_TOKEN = 0x1df44B5C1160fca5AE1d9430D221A6c39CCEd00D;
    
    // System parameters
    uint256 public constant DISPUTE_STAKE = 1 * 10**18; // 1 tokens
    uint256 public constant VALIDATION_TIMEOUT = 1 hours;
    string public constant WRAPPER_NAME = "MockETH";
    string public constant WRAPPER_SYMBOL = "mETH";
    
    function run() public {
        // Get deployer private key and address
        uint256 deployerPrivateKey = uint256(/);
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        console.log("Deployer Address:", deployerAddress);
        console.log("OptimisticDisputeGame Implementation:", OPTIMISTIC_GAME_IMPL);
        console.log("StakingPool Implementation:", STAKING_POOL_IMPL);
        console.log("Underlying Token Address:", UNDERLYING_TOKEN);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy SystemFactory
        SystemFactory systemFactory = new SystemFactory(
            OPTIMISTIC_GAME_IMPL,
            STAKING_POOL_IMPL
        );
        console.log("SystemFactory Deployed At:", address(systemFactory));
        
        // 2. Deploy complete system
        (address factoryAddr, address resolverAddr, address wrapperAddr) = systemFactory.deploySystem(
            DISPUTE_STAKE,
            VALIDATION_TIMEOUT,
            WRAPPER_NAME,
            WRAPPER_SYMBOL,
            UNDERLYING_TOKEN
        );
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Output deployment results
        console.log("Complete System Deployed:");
        console.log("DisputeGameFactory:", factoryAddr);
        console.log("OptimisticDisputeGameResolver:", resolverAddr);
        console.log("ERC20Wrapper:", wrapperAddr);
    }
} 