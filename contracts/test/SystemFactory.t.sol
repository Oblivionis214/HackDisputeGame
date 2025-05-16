// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SystemFactory Test
 * @author Oblivionis
 * @notice Test suite for the SystemFactory contract
 * @dev Tests the deployment and functionality of the SystemFactory
 */

import "forge-std/Test.sol";
import "../src/SystemFactory.sol";
import "../src/ERC20Wrapper.sol";
import "../src/DisputeGameFactory.sol";
import "../src/DisputeGame/OptimisticDisputeGame.sol";
import "../src/DisputeResolver/OptimisticDisputeGameResolver.sol";

//forge test --match-contract SystemFactoryTest -vvv

/**
 * @title TestIERC20
 * @dev Inline definition of the IERC20 interface to avoid external dependencies
 */
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

/**
 * @title ERC20Mock
 * @dev Simple ERC20 token implementation for testing purposes
 */
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

/**
 * @title SystemFactoryTest
 * @notice Test contract for the SystemFactory implementation
 * @dev Run tests with: forge test --match-contract SystemFactoryTest -vvv
 */
contract SystemFactoryTest is Test {
    // Contract instances for testing
    SystemFactory public systemFactory;
    ERC20Mock public mockToken; // Mock ERC20 token for testing
    
    // Test parameters
    address public deployer = address(1);
    uint256 public validationTimeout = 3600; // 1 hour
    uint256 public disputeStake = 1000 * 10**18; // 1000 tokens
    string public wrapperName = "Wrapped Test Token";
    string public wrapperSymbol = "wTEST";
    
    /**
     * @notice Set up the test environment
     * @dev Called before each test
     */
    function setUp() public {
        // Use mock account
        vm.startPrank(deployer);
        
        // Deploy mock ERC20 token
        mockToken = new ERC20Mock("Test Token", "TEST");
        
        // Mint tokens to the test account
        mockToken.mint(deployer, 10000 * 10**18);
        
        // Deploy SystemFactory contract
        systemFactory = new SystemFactory();
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test the deploySystem function
     * @dev Verifies that all system components are correctly deployed and linked
     */
    function testDeploySystem() public {
        // Use deployer account
        vm.startPrank(deployer);
        
        // Call deploySystem function
        SystemFactory.SystemInfo memory systemInfo = systemFactory.deploySystem(
            address(mockToken),
            validationTimeout,
            disputeStake,
            wrapperName,
            wrapperSymbol
        );
        
        // Verify system is deployed
        assertTrue(systemFactory.isSystemDeployed(address(mockToken)), "System not successfully deployed");
        
        // Verify returned system information
        assertEq(systemInfo.erc20Address, address(mockToken), "ERC20 address does not match");
        assertFalse(systemInfo.erc20Wrapper == address(0), "ERC20Wrapper not deployed");
        assertFalse(systemInfo.disputeGameFactory == address(0), "DisputeGameFactory not deployed");
        assertFalse(systemInfo.disputeResolver == address(0), "DisputeResolver not deployed");
        assertFalse(systemInfo.gameImplementation == address(0), "Game implementation not deployed");
        assertFalse(systemInfo.stakingPoolImplementation == address(0), "StakingPool implementation not deployed");
        
        // Query and verify system info
        SystemFactory.SystemInfo memory queriedInfo = systemFactory.getSystemInfo(address(mockToken));
        assertEq(queriedInfo.erc20Address, systemInfo.erc20Address, "Queried ERC20 address does not match");
        assertEq(queriedInfo.erc20Wrapper, systemInfo.erc20Wrapper, "Queried ERC20Wrapper does not match");
        assertEq(queriedInfo.disputeGameFactory, systemInfo.disputeGameFactory, "Queried DisputeGameFactory does not match");
        
        // Verify ERC20Wrapper initialization
        ERC20Wrapper wrapper = ERC20Wrapper(systemInfo.erc20Wrapper);
        assertEq(address(wrapper.underlyingToken()), address(mockToken), "Underlying token address in Wrapper does not match");
        assertEq(wrapper.name(), wrapperName, "Wrapper name does not match");
        assertEq(wrapper.symbol(), wrapperSymbol, "Wrapper symbol does not match");
        
        // Verify DisputeResolver connection
        OptimisticDisputeGameResolver resolver = OptimisticDisputeGameResolver(systemInfo.disputeResolver);
        assertEq(address(resolver.gameFactory()), systemInfo.disputeGameFactory, "Factory address in Resolver does not match");
        assertEq(resolver.disputeStake(), disputeStake, "Dispute stake does not match");
        assertEq(resolver.validationTimeout(), validationTimeout, "Validation timeout does not match");
        assertEq(resolver.tokenWrapper(), systemInfo.erc20Wrapper, "Wrapper address in Resolver does not match");
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test duplicate system deployment prevention
     * @dev Verifies that the same token cannot be deployed twice
     */
    function testCannotDeployDuplicateSystem() public {
        // Use deployer account
        vm.startPrank(deployer);
        
        // First system deployment
        systemFactory.deploySystem(
            address(mockToken),
            validationTimeout,
            disputeStake,
            wrapperName,
            wrapperSymbol
        );
        
        // Attempt to deploy system with same token, should fail
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
    
    /**
     * @notice Test zero address validation
     * @dev Verifies that zero address cannot be used as ERC20 address
     */
    function testCannotDeployWithZeroAddress() public {
        // Use deployer account
        vm.startPrank(deployer);
        
        // Attempt to deploy with zero address, should fail
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
    
    /**
     * @notice Test invalid parameters
     * @dev Verifies that system deployment fails with invalid parameters
     */
    function testCannotDeployWithInvalidParams() public {
        // Use deployer account
        vm.startPrank(deployer);
        
        // Test zero validation timeout
        vm.expectRevert("Validation timeout must be greater than 0");
        systemFactory.deploySystem(
            address(mockToken),
            0, // Invalid validation timeout
            disputeStake,
            wrapperName,
            wrapperSymbol
        );
        
        // Test zero dispute stake
        vm.expectRevert("Dispute stake must be greater than 0");
        systemFactory.deploySystem(
            address(mockToken),
            validationTimeout,
            0, // Invalid dispute stake
            wrapperName,
            wrapperSymbol
        );
        
        // Test empty wrapper name
        vm.expectRevert("Wrapper name cannot be empty");
        systemFactory.deploySystem(
            address(mockToken),
            validationTimeout,
            disputeStake,
            "", // Empty name
            wrapperSymbol
        );
        
        // Test empty wrapper symbol
        vm.expectRevert("Wrapper symbol cannot be empty");
        systemFactory.deploySystem(
            address(mockToken),
            validationTimeout,
            disputeStake,
            wrapperName,
            "" // Empty symbol
        );
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test complete system functionality
     * @dev Verifies user can deposit through the deployed system
     */
    function testSystemFunctionality() public {
        // Deploy system
        vm.startPrank(deployer);
        SystemFactory.SystemInfo memory systemInfo = systemFactory.deploySystem(
            address(mockToken),
            validationTimeout,
            disputeStake,
            wrapperName,
            wrapperSymbol
        );
        
        // Prepare for deposit
        uint256 depositAmount = 100 * 10**18;
        ERC20Wrapper wrapper = ERC20Wrapper(systemInfo.erc20Wrapper);
        
        // Approve token usage for Wrapper contract
        mockToken.approve(address(wrapper), depositAmount);
        
        // Execute deposit
        wrapper.deposit(depositAmount);
        
        // Verify deposit results
        assertEq(wrapper.balanceOf(deployer), depositAmount, "Wrapped token balance after deposit is incorrect");
        assertEq(mockToken.balanceOf(address(wrapper)), depositAmount, "Base token balance in Wrapper contract is incorrect");
        
        vm.stopPrank();
    }
} 