// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20Wrapper.sol";
import "./DisputeGameFactory.sol";
import "./DisputeGame/OptimisticDisputeGame.sol";
import "./DisputeResolver/OptimisticDisputeGameResolver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title SystemFactory
 * @dev 用于部署和连接完整HackDisputeGame协议系统的工厂合约
 * 允许任何用户输入ERC20地址和协议参数，部署整套协议组件
 */
contract SystemFactory is Ownable {
    // 事件定义
    event SystemDeployed(
        address erc20Address,
        address erc20Wrapper,
        address disputeGameFactory,
        address disputeResolver,
        address optimisticGameImplementation
    );
    
    // 部署的系统映射，按基础代币地址索引
    mapping(address => SystemInfo) public deployedSystems;
    
    // 系统信息结构体
    struct SystemInfo {
        address erc20Address;           // 基础ERC20代币地址
        address erc20Wrapper;           // ERC20Wrapper合约地址
        address disputeGameFactory;     // DisputeGameFactory合约地址
        address disputeResolver;        // OptimisticDisputeGameResolver合约地址
        address gameImplementation;     // OptimisticDisputeGame实现合约地址
        address stakingPoolImplementation; // StakingPool实现合约地址
        uint256 deployedAt;            // 部署时间戳
    }
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev 部署完整的协议系统
     * @param _erc20Address 基础ERC20代币地址
     * @param _validationTimeout 验证超时时间(秒)
     * @param _disputeStake 发起争议的初始质押金额
     * @param _wrapperName 包装代币名称
     * @param _wrapperSymbol 包装代币符号
     * @return systemInfo 部署的系统信息
     */
    function deploySystem(
        address _erc20Address,
        uint256 _validationTimeout,
        uint256 _disputeStake,
        string memory _wrapperName,
        string memory _wrapperSymbol
    ) public returns (SystemInfo memory systemInfo) {
        require(_erc20Address != address(0), "ERC20 address cannot be zero");
        require(_validationTimeout > 0, "Validation timeout must be greater than 0");
        require(_disputeStake > 0, "Dispute stake must be greater than 0");
        require(bytes(_wrapperName).length > 0, "Wrapper name cannot be empty");
        require(bytes(_wrapperSymbol).length > 0, "Wrapper symbol cannot be empty");
        require(deployedSystems[_erc20Address].erc20Address == address(0), "System already deployed for this token");
        
        // 1. 创建顺序: 首先部署实现合约
        // 1.1 部署 OptimisticDisputeGame 实现
        OptimisticDisputeGame gameImplementation = new OptimisticDisputeGame();
        
        // 1.2 部署 StakingPool 实现
        StakingPool stakingPoolImplementation = new StakingPool();
        
        // 2. 部署 DisputeGameFactory
        DisputeGameFactory gameFactory = new DisputeGameFactory(
            address(gameImplementation),
            address(stakingPoolImplementation)
        );
        
        // 3. 部署 OptimisticDisputeGameResolver，连接到DisputeGameFactory
        OptimisticDisputeGameResolver disputeResolver = new OptimisticDisputeGameResolver(
            address(gameFactory),
            _disputeStake,
            _validationTimeout
        );
        
        // 4. 部署 ERC20Wrapper，连接到 DisputeResolver
        ERC20Wrapper wrapper = new ERC20Wrapper(
            _wrapperName,
            _wrapperSymbol,
            _erc20Address,
            address(disputeResolver)
        );
        
        // 5. 设置 tokenWrapper 到 DisputeResolver
        disputeResolver.setTokenWrapper(address(wrapper));
        
        // 6. 存储系统信息
        SystemInfo memory newSystem = SystemInfo({
            erc20Address: _erc20Address,
            erc20Wrapper: address(wrapper),
            disputeGameFactory: address(gameFactory),
            disputeResolver: address(disputeResolver),
            gameImplementation: address(gameImplementation),
            stakingPoolImplementation: address(stakingPoolImplementation),
            deployedAt: block.timestamp
        });
        
        deployedSystems[_erc20Address] = newSystem;
        
        // 7. 发出事件
        emit SystemDeployed(
            _erc20Address,
            address(wrapper),
            address(gameFactory),
            address(disputeResolver),
            address(gameImplementation)
        );
        
        return newSystem;
    }
    
    /**
     * @dev 获取指定ERC20代币的系统信息
     * @param _erc20Address 基础ERC20代币地址
     * @return 对应的系统信息
     */
    function getSystemInfo(address _erc20Address) external view returns (SystemInfo memory) {
        return deployedSystems[_erc20Address];
    }
    
    /**
     * @dev 检查指定ERC20代币是否已部署系统
     * @param _erc20Address 基础ERC20代币地址
     * @return 是否已部署系统
     */
    function isSystemDeployed(address _erc20Address) external view returns (bool) {
        return deployedSystems[_erc20Address].erc20Address != address(0);
    }
} 