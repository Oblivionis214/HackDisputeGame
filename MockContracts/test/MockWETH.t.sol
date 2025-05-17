// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MockWETH.sol";

contract MockWETHTest is Test {
    MockWETH public mockWETH;
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        mockWETH = new MockWETH();
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function testMint() public {
        // 任何人都可以mint代币
        mockWETH.mint(user1, 1000);
        assertEq(mockWETH.balanceOf(user1), 1000);

        // 从user2调用mint
        vm.prank(user2);
        mockWETH.mint(user2, 2000);
        assertEq(mockWETH.balanceOf(user2), 2000);
    }

    function testDeposit() public {
        // 通过deposit函数测试
        vm.prank(user1);
        mockWETH.deposit{value: 1 ether}();
        assertEq(mockWETH.balanceOf(user1), 1 ether);

        // 通过receive函数测试
        vm.prank(user2);
        (bool success,) = address(mockWETH).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(mockWETH.balanceOf(user2), 1 ether);
    }

    function testWithdraw() public {
        // 先存入ETH
        vm.prank(user1);
        mockWETH.deposit{value: 1 ether}();
        
        uint256 balanceBefore = user1.balance;
        
        // 提取ETH
        vm.prank(user1);
        mockWETH.withdraw(0.5 ether);
        
        // 验证代币和ETH的变化
        assertEq(mockWETH.balanceOf(user1), 0.5 ether);
        assertEq(user1.balance, balanceBefore + 0.5 ether);
    }
} 