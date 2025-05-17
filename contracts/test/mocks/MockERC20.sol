// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice 用于测试的模拟ERC20代币
 * @dev 扩展标准的OpenZeppelin ERC20合约，添加了铸造功能
 */
contract MockERC20 is ERC20 {
    uint8 private _decimals;
    
    /**
     * @notice 构造函数
     * @param name_ 代币名称
     * @param symbol_ 代币符号
     * @param decimals_ 代币小数位数
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }
    
    /**
     * @notice 返回代币小数位数
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @notice 铸造新代币
     * @param to 接收者地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
    
    /**
     * @notice 批量铸造代币到多个地址
     * @param recipients 接收者地址列表
     * @param amounts 对应的铸造数量列表
     */
    function batchMint(address[] memory recipients, uint256[] memory amounts) public {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }
    
    /**
     * @notice 烧毁代币
     * @param from 被烧毁代币持有者地址
     * @param amount 烧毁数量
     */
    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
} 