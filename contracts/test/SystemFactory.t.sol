// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SystemFactory.sol";
import "../src/ERC20Wrapper.sol";
import "../src/DisputeGameFactory.sol";
import "../src/DisputeGame/OptimisticDisputeGame.sol";
import "../src/DisputeResolver/OptimisticDisputeGameResolver.sol";

//forge test --match-contract SystemFactoryTest -vvv
// 内联定义IERC20接口，避免外部导入
interface TestIERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// 简单的ERC20测试代币合约
contract ERC20Mock is TestIERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }
    
    function name() public view returns (string memory) {
        return _name;
    }
    
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, msg.sender, currentAllowance - amount);
        }
        
        return true;
    }
    
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;
        
        emit Transfer(sender, recipient, amount);
    }
    
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

//forge test --match-contract SystemFactoryTest -vvv
contract SystemFactoryTest is Test {
    // 测试要使用的合约实例
    SystemFactory public systemFactory;
    ERC20Mock public mockToken; // 用于测试的模拟ERC20代币
    
    // 测试参数
    address public deployer = address(1);
    uint256 public validationTimeout = 3600; // 1小时
    uint256 public disputeStake = 1000 * 10**18; // 1000代币
    string public wrapperName = "Wrapped Test Token";
    string public wrapperSymbol = "wTEST";
    
    // 设置测试环境
    function setUp() public {
        // 使用模拟账户
        vm.startPrank(deployer);
        
        // 部署模拟ERC20代币
        mockToken = new ERC20Mock("Test Token", "TEST");
        
        // 铸造一些代币给测试账户
        mockToken.mint(deployer, 10000 * 10**18);
        
        // 部署SystemFactory合约
        systemFactory = new SystemFactory();
        
        vm.stopPrank();
    }
    
    // 测试deploySystem函数
    function testDeploySystem() public {
        // 使用deployer账户
        vm.startPrank(deployer);
        
        // 调用deploySystem函数
        SystemFactory.SystemInfo memory systemInfo = systemFactory.deploySystem(
            address(mockToken),
            validationTimeout,
            disputeStake,
            wrapperName,
            wrapperSymbol
        );
        
        // 验证系统是否已部署
        assertTrue(systemFactory.isSystemDeployed(address(mockToken)), unicode"系统未成功部署");
        
        // 验证返回的系统信息
        assertEq(systemInfo.erc20Address, address(mockToken), unicode"ERC20地址不匹配");
        assertFalse(systemInfo.erc20Wrapper == address(0), unicode"ERC20Wrapper未部署");
        assertFalse(systemInfo.disputeGameFactory == address(0), unicode"DisputeGameFactory未部署");
        assertFalse(systemInfo.disputeResolver == address(0), unicode"DisputeResolver未部署");
        assertFalse(systemInfo.gameImplementation == address(0), unicode"游戏实现未部署");
        assertFalse(systemInfo.stakingPoolImplementation == address(0), unicode"质押池实现未部署");
        
        // 通过getSystemInfo查询并验证
        SystemFactory.SystemInfo memory queriedInfo = systemFactory.getSystemInfo(address(mockToken));
        assertEq(queriedInfo.erc20Address, systemInfo.erc20Address, unicode"查询的ERC20地址不匹配");
        assertEq(queriedInfo.erc20Wrapper, systemInfo.erc20Wrapper, unicode"查询的ERC20Wrapper不匹配");
        assertEq(queriedInfo.disputeGameFactory, systemInfo.disputeGameFactory, unicode"查询的DisputeGameFactory不匹配");
        
        // 验证ERC20Wrapper是否正确初始化
        ERC20Wrapper wrapper = ERC20Wrapper(systemInfo.erc20Wrapper);
        assertEq(address(wrapper.underlyingToken()), address(mockToken), unicode"Wrapper中的基础代币地址不匹配");
        assertEq(wrapper.name(), wrapperName, unicode"Wrapper名称不匹配");
        assertEq(wrapper.symbol(), wrapperSymbol, unicode"Wrapper符号不匹配");
        
        // 验证DisputeResolver是否正确连接
        OptimisticDisputeGameResolver resolver = OptimisticDisputeGameResolver(systemInfo.disputeResolver);
        assertEq(address(resolver.gameFactory()), systemInfo.disputeGameFactory, unicode"Resolver中的工厂地址不匹配");
        assertEq(resolver.disputeStake(), disputeStake, unicode"争议质押金额不匹配");
        assertEq(resolver.validationTimeout(), validationTimeout, unicode"验证超时时间不匹配");
        assertEq(resolver.tokenWrapper(), systemInfo.erc20Wrapper, unicode"Resolver中的Wrapper地址不匹配");
        
        vm.stopPrank();
    }
    
    // 测试重复部署同一代币系统
    function testCannotDeployDuplicateSystem() public {
        // 使用deployer账户
        vm.startPrank(deployer);
        
        // 首次部署系统
        systemFactory.deploySystem(
            address(mockToken),
            validationTimeout,
            disputeStake,
            wrapperName,
            wrapperSymbol
        );
        
        // 尝试再次部署相同代币的系统，应该失败
        vm.expectRevert("System already deployed for this token");
        systemFactory.deploySystem(
            address(mockToken),
            validationTimeout,
            disputeStake,
            wrapperName,
            wrapperSymbol
        );
        
        vm.stopPrank();
    }
    
    // 测试使用零地址作为ERC20地址
    function testCannotDeployWithZeroAddress() public {
        // 使用deployer账户
        vm.startPrank(deployer);
        
        // 尝试使用零地址部署，应该失败
        vm.expectRevert("ERC20 address cannot be zero");
        systemFactory.deploySystem(
            address(0),
            validationTimeout,
            disputeStake,
            wrapperName,
            wrapperSymbol
        );
        
        vm.stopPrank();
    }
    
    // 测试无效参数
    function testCannotDeployWithInvalidParams() public {
        // 使用deployer账户
        vm.startPrank(deployer);
        
        // 测试零验证超时时间
        vm.expectRevert("Validation timeout must be greater than 0");
        systemFactory.deploySystem(
            address(mockToken),
            0, // 无效的验证超时时间
            disputeStake,
            wrapperName,
            wrapperSymbol
        );
        
        // 测试零争议质押金额
        vm.expectRevert("Dispute stake must be greater than 0");
        systemFactory.deploySystem(
            address(mockToken),
            validationTimeout,
            0, // 无效的争议质押金额
            wrapperName,
            wrapperSymbol
        );
        
        // 测试空包装器名称
        vm.expectRevert("Wrapper name cannot be empty");
        systemFactory.deploySystem(
            address(mockToken),
            validationTimeout,
            disputeStake,
            "", // 空名称
            wrapperSymbol
        );
        
        // 测试空包装器符号
        vm.expectRevert("Wrapper symbol cannot be empty");
        systemFactory.deploySystem(
            address(mockToken),
            validationTimeout,
            disputeStake,
            wrapperName,
            "" // 空符号
        );
        
        vm.stopPrank();
    }
    
    // 测试完整系统功能性 - 验证用户可以通过部署的系统进行存款
    function testSystemFunctionality() public {
        // 部署系统
        vm.startPrank(deployer);
        SystemFactory.SystemInfo memory systemInfo = systemFactory.deploySystem(
            address(mockToken),
            validationTimeout,
            disputeStake,
            wrapperName,
            wrapperSymbol
        );
        
        // 准备进行存款
        uint256 depositAmount = 100 * 10**18;
        ERC20Wrapper wrapper = ERC20Wrapper(systemInfo.erc20Wrapper);
        
        // 批准Wrapper合约使用代币
        mockToken.approve(address(wrapper), depositAmount);
        
        // 执行存款
        wrapper.deposit(depositAmount);
        
        // 验证存款结果
        assertEq(wrapper.balanceOf(deployer), depositAmount, unicode"存款后Wrapper代币余额不正确");
        assertEq(mockToken.balanceOf(address(wrapper)), depositAmount, unicode"Wrapper合约中的基础代币余额不正确");
        
        vm.stopPrank();
    }
} 