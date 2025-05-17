// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/SystemFactory.sol";

/**
 * @title DeploySystemFactory
 * @notice Script for deploying the SystemFactory contract
 * @dev Uses already deployed OptimisticDisputeGame and StakingPool addresses
 */
contract DeploySystemFactory is Script {
    // Addresses of deployed implementation contracts
    address public constant OPTIMISTIC_GAME_IMPL = 0x04409D09EA82d3954A23655f3640428C879F7442;
    address public constant STAKING_POOL_IMPL = 0x0fbeBD16a02c26ecE90f39cd422D317C17dD808d;
    
    function run() public {
        // Get deployer private key and address
        uint256 deployerPrivateKey = uint256(/);
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        console.log("Deployer Address:", deployerAddress);
        console.log("OptimisticDisputeGame Implementation:", OPTIMISTIC_GAME_IMPL);
        console.log("StakingPool Implementation:", STAKING_POOL_IMPL);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy SystemFactory
        SystemFactory systemFactory = new SystemFactory(
            OPTIMISTIC_GAME_IMPL,
            STAKING_POOL_IMPL
        );
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        console.log("SystemFactory Deployed At:", address(systemFactory));
    }
} 