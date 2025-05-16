// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title ERC20Mock
 * @dev 用于测试的简单ERC20代币
 */
contract ERC20Mock is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}
    
    /**
     * @dev 铸造代币
     * @param to 接收者地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
} 