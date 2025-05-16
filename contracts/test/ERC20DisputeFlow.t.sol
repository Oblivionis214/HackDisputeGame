// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {ERC20Wrapper} from "../src/ERC20Wrapper.sol";
import {DisputeGameFactory} from "../src/DisputeGameFactory.sol";
import {OptimisticDisputeGame} from "../src/DisputeGame/OptimisticDisputeGame.sol";
import {StakingPool} from "../src/StakingPool.sol";
import {BaseDisputeResolver} from "../src/DisputeResolver/BaseDisputeResolver.sol";
import {OptimisticDisputeGameResolver} from "../src/DisputeResolver/OptimisticDisputeGameResolver.sol";
import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title ERC20DisputeFlowTest
 * @dev 完整测试从用户申请提款开始，通过争议流程，直到最终赎回的整个流程
 */
contract ERC20DisputeFlowTest is Test {
    // 基础代币
    ERC20Mock public underlying;
    
    // ERC20包装器
    ERC20Wrapper public wrapper;
    
    // 争议游戏系统
    OptimisticDisputeGame public gameImplementation;
    StakingPool public poolImplementation;
    DisputeGameFactory public factory;
    OptimisticDisputeGameResolver public resolver;
    
    // 测试账户
    address public deployer;
    address public user1;
    address public user2;
    address public user3;
    
    // 测试参数
    uint256 public initialStake = 1 ether;
    uint256 public validationTimeout = 1 days;
    
    // 事件
    event WithdrawRequested(uint256 indexed requestId, address indexed user, uint256 amount);
    event WithdrawProcessed(uint256 indexed requestId, address indexed user, uint256 amount);
    
    function setUp() public {
        // 创建测试账户
        deployer = makeAddr("deployer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        vm.startPrank(deployer);
        
        // 部署基础代币
        underlying = new ERC20Mock();
        underlying.mint(deployer, 1000 ether);
        underlying.mint(user1, 100 ether);
        underlying.mint(user2, 100 ether);
        underlying.mint(user3, 100 ether);
        
        // 部署ERC20包装器
        wrapper = new ERC20Wrapper(
            "Wrapped Token",
            "WRAP",
            address(underlying),
            address(0) // 初始为0地址，稍后设置正确的DisputeResolver
        );
        
        // 部署争议游戏系统
        gameImplementation = new OptimisticDisputeGame();
        poolImplementation = new StakingPool();
        
        // 部署争议游戏工厂
        factory = new DisputeGameFactory(
            address(gameImplementation),
            address(poolImplementation)
        );
        
        // 部署争议解决器
        resolver = new OptimisticDisputeGameResolver(
            address(factory),
            initialStake,
            validationTimeout
        );
        
        // 获取解决器地址
        address resolverAddress = address(resolver);
        
        // 添加设置DisputeResolver的函数调用
        // wrapper.setDisputeResolver(address(resolver));
        wrapper = new ERC20Wrapper(
            "Wrapped Token",
            "WRAP",
            address(underlying),
            resolverAddress
        );
        
        // 设置TokenWrapper
        resolver.setTokenWrapper(address(wrapper));
        
        vm.stopPrank();
    }
    
    //forge test --match-contract ERC20DisputeFlow --via-ir
    function test_CompleteDisputeFlow() public {
        // ===== 步骤1: 用户存款和提款申请 =====
        
        // User1 存入代币
        vm.startPrank(user1);
        underlying.approve(address(wrapper), 50 ether);
        wrapper.deposit(50 ether);
        assertEq(wrapper.balanceOf(user1), 50 ether, "User1 should have 50 wrapped tokens");
        
        // User1 请求提款
        wrapper.withdraw(20 ether);
        uint256 requestId = 0; // 第一个请求ID为0
        
        // 验证提款请求状态
        (
            address requestUser,
            uint256 amount,
            uint256 timestamp,
            bool disputed,
            bool valid
        ) = resolver.getRequestDetails(requestId);
        
        assertEq(requestUser, user1, "Request user should be user1");
        assertEq(amount, 20 ether, "Request amount should be 20 ether");
        assertFalse(disputed, "Request should not be disputed initially");
        assertFalse(valid, "Request should not be valid initially");
        
        vm.stopPrank();
        
        // ===== 步骤2: User2 发起争议 =====
        
        vm.startPrank(user2);
        
        // 授权代币给争议解决器
        underlying.approve(address(resolver), initialStake);
        
        // 发起争议
        uint256 gameId = resolver.dispute(requestId);
        
        // 验证争议状态
        (
            bool exists,
            uint256 storedGameId,
            address gameAddress,
            OptimisticDisputeGame.GameState gameState
        ) = resolver.getDisputeGame(requestId);
        
        assertTrue(exists, "Dispute should exist");
        assertEq(storedGameId, gameId, "Game IDs should match");
        assertNotEq(gameAddress, address(0), "Game address should not be zero");
        assertEq(uint(gameState), uint(OptimisticDisputeGame.GameState.ACTIVE), "Game should be active");
        
        vm.stopPrank();
        
        // ===== 步骤3: 进行游戏回合 - 三轮攻防 =====
        
        // 获取游戏信息
        (
            DisputeGameFactory.GameType gameTypeInfo,
            address gameAddressInfo,
            address attackerAddressInfo,
            address defenderAddressInfo,
            address tokenAddressInfo,
            uint256 initialStakeInfo,
            uint256 createdAtInfo,
            address attackerPoolAddress,
            address defenderPoolAddress
        ) = factory.games(gameId);
        
        OptimisticDisputeGame game = OptimisticDisputeGame(gameAddressInfo);
        
        // 为游戏合约铸造足够的代币以支付奖励
        vm.startPrank(deployer);
        underlying.mint(gameAddressInfo, 100 ether);
        vm.stopPrank();
        
        // 第一轮: 攻击者已经通过resolver.dispute进行了攻击，现在轮到防御者
        
        // User3作为防御者
        vm.startPrank(user3);
        underlying.approve(defenderPoolAddress, 10 ether);
        underlying.approve(gameAddressInfo, 10 ether);
        StakingPool(defenderPoolAddress).deposit(10 ether, user3);
        
        // 防御者进行防御
        StakingPool(defenderPoolAddress).playTurn();
        vm.stopPrank();
        
        // 验证游戏状态
        (
            address gameAttacker1,
            address gameDefender1,
            OptimisticDisputeGame.Turn currentTurn1,
            OptimisticDisputeGame.GameState gameState1,
            uint256 gameAttackerStake1,
            uint256 gameDefenderStake1,
            uint256 gameTimeout1,
            uint256 gameTimeoutExtension1,
            address gameToken1,
            uint256 gameInitialStake1,
            uint256 gameRequiredStake1
        ) = game.getGameInfo();
        
        assertEq(uint(currentTurn1), uint(OptimisticDisputeGame.Turn.ATTACKER), "Turn should be ATTACKER after defense");
        
        // 第二轮: 攻击者攻击
        vm.startPrank(user2);
        underlying.approve(attackerPoolAddress, 10 ether);
        underlying.approve(gameAddressInfo, 10 ether);
        StakingPool(attackerPoolAddress).deposit(10 ether, user2);
        StakingPool(attackerPoolAddress).playTurn();
        vm.stopPrank();
        
        // 第二轮: 防御者防御
        vm.startPrank(user3);
        underlying.approve(defenderPoolAddress, 20 ether);
        underlying.approve(gameAddressInfo, 20 ether);
        StakingPool(defenderPoolAddress).deposit(20 ether, user3);
        StakingPool(defenderPoolAddress).playTurn();
        vm.stopPrank();
        
        // 第三轮: 攻击者攻击
        vm.startPrank(user2);
        underlying.approve(attackerPoolAddress, 20 ether);
        underlying.approve(gameAddressInfo, 20 ether);
        StakingPool(attackerPoolAddress).deposit(20 ether, user2);
        StakingPool(attackerPoolAddress).playTurn();
        vm.stopPrank();
        
        // 第三轮: 防御者防御
        vm.startPrank(user3);
        underlying.approve(defenderPoolAddress, 40 ether);
        underlying.approve(gameAddressInfo, 40 ether);
        StakingPool(defenderPoolAddress).deposit(40 ether, user3);
        StakingPool(defenderPoolAddress).playTurn();
        vm.stopPrank();
        
        // ===== 步骤4: 攻击者放弃，防御者胜利 =====
        
        // 等待超时
        vm.warp(block.timestamp + 3 hours);
        
        // 声明超时，防御者胜利
        game.claimTimeout();
        
        // 验证游戏状态
        (
            address gameAttacker2,
            address gameDefender2,
            OptimisticDisputeGame.Turn currentTurn2,
            OptimisticDisputeGame.GameState gameState2,
            uint256 attackerStake2,
            uint256 defenderStake2,
            uint256 timeoutTimestamp2,
            uint256 timeoutExtension2,
            address tokenAddress2,
            uint256 initialStake2,
            uint256 requiredStake2
        ) = game.getGameInfo();
        
        assertEq(uint(gameState2), uint(OptimisticDisputeGame.GameState.DEFENDER_WON), "Game should be won by defender");
        
        // ===== 步骤5: 解决争议 =====
        
        vm.prank(user3);
        bool resolved = resolver.resolve(requestId);
        assertTrue(resolved, "Dispute should be resolved");
        
        // 验证提款请求状态
        (
            ,
            ,
            ,
            bool disputed2,
            bool valid2
        ) = resolver.getRequestDetails(requestId);
        
        assertTrue(disputed2, "Request should be marked as disputed");
        assertTrue(valid2, "Request should be valid after defender victory");
        
        // ===== 步骤6: 用户提款 =====
        
        // 让请求通过验证期
        vm.warp(block.timestamp + validationTimeout + 1);
        
        // 用户执行提款
        vm.startPrank(user1);
        uint256 balanceBefore = underlying.balanceOf(user1);
        
        // 验证可以赎回
        bool canRedeem = resolver.validateWithdraw(user1, requestId);
        assertTrue(canRedeem, "User should be able to redeem now");
        
        // 执行赎回
        wrapper.redeem(requestId);
        
        uint256 balanceAfter = underlying.balanceOf(user1);
        
        assertEq(balanceAfter - balanceBefore, 20 ether, "User should have redeemed 20 ether");
        
        vm.stopPrank();
    }
} 