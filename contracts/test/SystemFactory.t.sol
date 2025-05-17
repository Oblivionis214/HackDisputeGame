// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SystemFactory.sol";
import "../src/DisputeGameFactory.sol";
import "../src/DisputeResolver/OptimisticDisputeGameResolver.sol";
import "../src/ERC20Wrapper.sol";
import "../src/DisputeGame/OptimisticDisputeGame.sol";
import "../src/StakingPool.sol";
import "./mocks/MockERC20.sol";

//forge test --match-test SystemFactory --via-ir -vvvv
contract SystemFactoryTest is Test {
    // 系统工厂合约
    SystemFactory public systemFactory;
    
    // 实现合约
    OptimisticDisputeGame public gameImpl;
    StakingPool public poolImpl;
    
    // 模拟ERC20代币
    MockERC20 public mockToken;
    
    // 测试参数
    uint256 public constant DISPUTE_STAKE = 100 * 10**18; // 100 tokens
    uint256 public constant VALIDATION_TIMEOUT = 1 hours;
    string public constant WRAPPER_NAME = "Wrapped Test Token";
    string public constant WRAPPER_SYMBOL = "wTT";
    
    // 测试账户
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    function setUp() public {
        // 设置测试环境
        vm.startPrank(owner);
        
        // 部署模拟ERC20代币
        mockToken = new MockERC20("Test Token", "TT", 18);
        
        // 部署实现合约
        gameImpl = new OptimisticDisputeGame();
        poolImpl = new StakingPool();
        
        // 部署SystemFactory
        systemFactory = new SystemFactory(address(gameImpl), address(poolImpl));
        
        vm.stopPrank();
    }
    
    function testConstructorZeroAddress() public {
        // 测试构造函数零地址检查
        vm.startPrank(owner);
        
        // 测试游戏实现为零地址
        vm.expectRevert("Game implementation cannot be zero");
        new SystemFactory(address(0), address(poolImpl));
        
        // 测试质押池实现为零地址
        vm.expectRevert("Pool implementation cannot be zero");
        new SystemFactory(address(gameImpl), address(0));
        
        vm.stopPrank();
    }
    
    function testDeploySystem() public {
        vm.startPrank(owner);
        
        // 调用deploySystem函数
        (address factoryAddr, address resolverAddr, address wrapperAddr) = systemFactory.deploySystem(
            DISPUTE_STAKE,
            VALIDATION_TIMEOUT,
            WRAPPER_NAME,
            WRAPPER_SYMBOL,
            address(mockToken)
        );
        
        // 验证地址不为零
        assertNotEq(factoryAddr, address(0), "Factory address should not be zero");
        assertNotEq(resolverAddr, address(0), "Resolver address should not be zero");
        assertNotEq(wrapperAddr, address(0), "Wrapper address should not be zero");
        
        // 验证地址是否与存储的地址匹配
        assertEq(factoryAddr, systemFactory.gameFactoryAddress(), "Factory addresses should match");
        assertEq(resolverAddr, systemFactory.resolverAddress(), "Resolver addresses should match");
        assertEq(wrapperAddr, systemFactory.wrapperAddress(), "Wrapper addresses should match");
        
        // 验证合约类型
        DisputeGameFactory factory = DisputeGameFactory(factoryAddr);
        OptimisticDisputeGameResolver resolver = OptimisticDisputeGameResolver(resolverAddr);
        ERC20Wrapper wrapper = ERC20Wrapper(wrapperAddr);
        
        // 验证工厂实现地址
        assertEq(factory.optimisticGameImplementation(), address(gameImpl), "Game implementation not set correctly");
        assertEq(factory.stakingPoolImplementation(), address(poolImpl), "Pool implementation not set correctly");
        
        // 验证wrapper设置
        assertEq(address(wrapper.underlyingToken()), address(mockToken), "Underlying token not set correctly");
        assertEq(wrapper.name(), WRAPPER_NAME, "Wrapper name not set correctly");
        assertEq(wrapper.symbol(), WRAPPER_SYMBOL, "Wrapper symbol not set correctly");
        assertEq(wrapper.disputeResolver(), resolverAddr, "Dispute resolver not set correctly");
        
        vm.stopPrank();
    }
    
    function testDeploySystemRequirements() public {
        vm.startPrank(owner);
        
        // 测试底层代币为零地址
        vm.expectRevert("Underlying token cannot be zero");
        systemFactory.deploySystem(
            DISPUTE_STAKE,
            VALIDATION_TIMEOUT,
            WRAPPER_NAME,
            WRAPPER_SYMBOL,
            address(0)
        );
        
        // 测试零质押金额
        vm.expectRevert("Dispute stake must be greater than 0");
        systemFactory.deploySystem(
            0,
            VALIDATION_TIMEOUT,
            WRAPPER_NAME,
            WRAPPER_SYMBOL,
            address(mockToken)
        );
        
        // 测试零验证超时
        vm.expectRevert("Validation timeout must be greater than 0");
        systemFactory.deploySystem(
            DISPUTE_STAKE,
            0,
            WRAPPER_NAME,
            WRAPPER_SYMBOL,
            address(mockToken)
        );
        
        vm.stopPrank();
    }
    
    function testOnlyOwnerCanDeploy() public {
        // 测试非所有者调用
        vm.startPrank(user1);
        
        vm.expectRevert(); // 预期会因为onlyOwner修饰符而revert
        systemFactory.deploySystem(
            DISPUTE_STAKE,
            VALIDATION_TIMEOUT,
            WRAPPER_NAME,
            WRAPPER_SYMBOL,
            address(mockToken)
        );
        
        vm.stopPrank();
    }
    
} 