// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/StakingPool.sol";
import "../src/DisputeGame/OptimisticDisputeGame.sol";

/**
 * @title DeployBaseContracts
 * @notice Deploy StakingPool and OptimisticDisputeGame contracts
 * @dev Only deploy contracts, do not initialize
 */
contract DeployBaseContracts is Script {
    function run() external {
        uint256 deployerPrivateKey = uint256(/);
        vm.startBroadcast(deployerPrivateKey);

        // Deploy OptimisticDisputeGame contract
        OptimisticDisputeGame optimisticDisputeGame = new OptimisticDisputeGame();
        console.log("OptimisticDisputeGame deployed at:", address(optimisticDisputeGame));

        // Deploy StakingPool contract
        StakingPool stakingPool = new StakingPool();
        console.log("StakingPool deployed at:", address(stakingPool));

        vm.stopBroadcast();
    }
} 