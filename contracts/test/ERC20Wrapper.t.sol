// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ERC20Wrapper.sol";
import "../src/interfaces/IDisputeResolver.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 用于测试的简单ERC20 Token
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 10000 * 10**18);
    }
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// 用于测试的简单DisputeResolver
contract MockDisputeResolver is IDisputeResolver {
    mapping(address => mapping(uint256 => bool)) public validRequests;
    uint256 public nextRequestId = 1;
    
    function pushWithdrawRequest(address user, uint256 amount) external override returns (uint256 requestId) {
        uint256 id = nextRequestId;
        nextRequestId += 1;
        validRequests[user][id] = true;
        return id;
    }
    
    function validateWithdraw(address user, uint256 requestId) external view override returns (bool isValid) {
        return validRequests[user][requestId];
    }
    
    // 用于测试的函数，模拟拒绝提款请求
    function invalidateRequest(address user, uint256 requestId) external {
        validRequests[user][requestId] = false;
    }
}

contract ERC20WrapperTest is Test {
    ERC20Wrapper public wrapper;
    MockToken public underlyingToken;
    MockDisputeResolver public disputeResolver;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    uint256 public constant INITIAL_BALANCE = 1000 * 10**18; // 1000 tokens
    
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);
    event WithdrawRequested(address indexed src, address indexed to, uint wad, uint256 indexed requestId);
    event Redeemed(address indexed src, address indexed to, uint wad, uint256 indexed requestId);
    
    function setUp() public {
        // 部署模拟合约
        underlyingToken = new MockToken();
        disputeResolver = MockDisputeResolver(address(1));
        
        // 部署需要测试的合约
        wrapper = new ERC20Wrapper(
            "Wrapped Mock Token",
            "wMOCK",
            address(underlyingToken),
            address(disputeResolver)
        );
        
        // 给测试账户一些代币
        underlyingToken.mint(alice, INITIAL_BALANCE);
        underlyingToken.mint(bob, INITIAL_BALANCE);
        
        // 切换到alice账户进行授权
        vm.startPrank(alice);
        underlyingToken.approve(address(wrapper), type(uint256).max);
        vm.stopPrank();
        
        // 切换到bob账户进行授权
        vm.startPrank(bob);
        underlyingToken.approve(address(wrapper), type(uint256).max);
        vm.stopPrank();
    }
    
    // 测试初始化状态
    function testInitialState() public {
        assertEq(wrapper.name(), "Wrapped Mock Token");
        assertEq(wrapper.symbol(), "wMOCK");
        assertEq(address(wrapper.underlyingToken()), address(underlyingToken));
        assertEq(address(wrapper.disputeResolver()), address(disputeResolver));
        assertEq(wrapper.totalSupply(), 0);
    }
    
    // 测试存款功能
    function testDeposit() public {
        uint256 depositAmount = 100 * 10**18; // 100 tokens
        
        // 切换到alice账户
        vm.startPrank(alice);
        
        // 记录存款前余额
        uint256 aliceUnderlyingBefore = underlyingToken.balanceOf(alice);
        uint256 wrapperUnderlyingBefore = underlyingToken.balanceOf(address(wrapper));
        
        // 预期事件
        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, depositAmount);
        
        // 执行存款
        wrapper.deposit(depositAmount);
        
        // 验证结果
        assertEq(wrapper.balanceOf(alice), depositAmount, "Wrapped token balance should increase");
        assertEq(underlyingToken.balanceOf(alice), aliceUnderlyingBefore - depositAmount, "Underlying token balance should decrease");
        assertEq(underlyingToken.balanceOf(address(wrapper)), wrapperUnderlyingBefore + depositAmount, "Wrapper should receive underlying tokens");
        
        vm.stopPrank();
    }
    
    // 测试存款金额为0时应该失败
    function test_RevertWhen_DepositZero() public {
        vm.startPrank(alice);
        vm.expectRevert("Amount must be greater than 0");
        wrapper.deposit(0);
        vm.stopPrank();
    }
    
    // 测试提款请求功能
    function testWithdrawRequest() public {
        uint256 depositAmount = 100 * 10**18; // 100 tokens
        uint256 withdrawAmount = 50 * 10**18;  // 50 tokens
        
        // 先进行存款
        vm.startPrank(alice);
        wrapper.deposit(depositAmount);
        
        // 记录提款前状态
        uint256 aliceWrappedBefore = wrapper.balanceOf(alice);
        
        // 预期事件
        vm.expectEmit(true, true, false, true);
        // requestId = 1 是因为MockDisputeResolver会返回1作为第一个请求ID
        emit WithdrawRequested(alice, alice, withdrawAmount, 1);
        
        // 执行提款请求
        wrapper.withdraw(withdrawAmount);
        
        // 验证结果
        assertEq(wrapper.balanceOf(alice), aliceWrappedBefore - withdrawAmount, "Wrapped token balance should decrease");
        
        // 验证提款请求是否正确记录
        (uint256 amount, address recipient) = wrapper.withdrawRequests(alice, 1);
        assertEq(amount, withdrawAmount, "Withdrawal request amount should match");
        assertEq(recipient, alice, "Withdrawal recipient should be correct");
        
        vm.stopPrank();
    }
    
    // 测试提款给指定接收者
    function testWithdrawToRecipient() public {
        uint256 depositAmount = 100 * 10**18; // 100 tokens
        uint256 withdrawAmount = 50 * 10**18;  // 50 tokens
        
        // 先进行存款
        vm.startPrank(alice);
        wrapper.deposit(depositAmount);
        
        // 记录提款前状态
        uint256 aliceWrappedBefore = wrapper.balanceOf(alice);
        
        // 预期事件
        vm.expectEmit(true, true, false, true);
        // 这次提款给bob
        emit WithdrawRequested(alice, bob, withdrawAmount, 1);
        
        // 执行提款请求
        wrapper.withdraw(withdrawAmount, bob);
        
        // 验证结果
        assertEq(wrapper.balanceOf(alice), aliceWrappedBefore - withdrawAmount, "Wrapped token balance should decrease");
        
        // 验证提款请求是否正确记录
        (uint256 amount, address recipient) = wrapper.withdrawRequests(alice, 1);
        assertEq(amount, withdrawAmount, "Withdrawal request amount should match");
        assertEq(recipient, bob, "Withdrawal recipient should be bob");
        
        vm.stopPrank();
    }
    
    // 测试赎回功能
    function testRedeem() public {
        uint256 depositAmount = 100 * 10**18; // 100 tokens
        uint256 withdrawAmount = 50 * 10**18;  // 50 tokens
        
        // 先进行存款
        vm.startPrank(alice);
        wrapper.deposit(depositAmount);
        
        // 执行提款请求
        wrapper.withdraw(withdrawAmount);
        
        // 记录赎回前状态
        uint256 aliceUnderlyingBefore = underlyingToken.balanceOf(alice);
        uint256 wrapperUnderlyingBefore = underlyingToken.balanceOf(address(wrapper));
        
        // 预期事件
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(alice, withdrawAmount);
        
        vm.expectEmit(true, true, false, true);
        emit Redeemed(alice, alice, withdrawAmount, 1);
        
        // 执行赎回
        wrapper.redeem(1);
        
        // 验证结果
        assertEq(underlyingToken.balanceOf(alice), aliceUnderlyingBefore + withdrawAmount, "Underlying token balance should increase");
        assertEq(underlyingToken.balanceOf(address(wrapper)), wrapperUnderlyingBefore - withdrawAmount, "Wrapper should send underlying tokens");
        
        // 验证提款请求是否已清除
        (uint256 amount, ) = wrapper.withdrawRequests(alice, 1);
        assertEq(amount, 0, "Withdrawal request should be cleared");
        
        vm.stopPrank();
    }
    
    // 测试赎回无效请求应该失败
    function test_RevertWhen_RedeemInvalidRequest() public {
        uint256 depositAmount = 100 * 10**18; // 100 tokens
        uint256 withdrawAmount = 50 * 10**18;  // 50 tokens
        
        // 先进行存款
        vm.startPrank(alice);
        wrapper.deposit(depositAmount);
        
        // 执行提款请求
        wrapper.withdraw(withdrawAmount);
        vm.stopPrank();
        
        // 使请求失效
        disputeResolver.invalidateRequest(alice, 1);
        
        // 尝试赎回应该失败
        vm.startPrank(alice);
        vm.expectRevert("Withdrawal request not validated");
        wrapper.redeem(1);
        vm.stopPrank();
    }
    
    // 测试尝试赎回不存在的请求应该失败
    function test_RevertWhen_RedeemNonexistentRequest() public {
        vm.startPrank(alice);
        vm.expectRevert("No withdrawal request found");
        wrapper.redeem(999); // 不存在的请求ID
        vm.stopPrank();
    }
    
    // 测试提款超过余额应该失败
    function test_RevertWhen_WithdrawExceedingBalance() public {
        uint256 depositAmount = 100 * 10**18; // 100 tokens
        
        // 先进行存款
        vm.startPrank(alice);
        wrapper.deposit(depositAmount);
        
        // 尝试提取超过余额的金额
        vm.expectRevert("Insufficient balance");
        wrapper.withdraw(depositAmount + 1);
        vm.stopPrank();
    }
    
    // 测试提款到零地址应该失败
    function test_RevertWhen_WithdrawToZeroAddress() public {
        uint256 depositAmount = 100 * 10**18; // 100 tokens
        
        // 先进行存款
        vm.startPrank(alice);
        wrapper.deposit(depositAmount);
        
        // 尝试提取到零地址
        vm.expectRevert("Invalid recipient");
        wrapper.withdraw(50 * 10**18, address(0));
        vm.stopPrank();
    }
} 