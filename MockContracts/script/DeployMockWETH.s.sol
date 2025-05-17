// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MockWETH.sol";

contract DeployMockWETH is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = uint256(/);
        
        vm.startBroadcast(deployerPrivateKey);

        // 部署 MockWETH
        MockWETH mockWETH = new MockWETH();
        
        console.log("MockWETH deployed at address:", address(mockWETH));

        vm.stopBroadcast();
    }
} 