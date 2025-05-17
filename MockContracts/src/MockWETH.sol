// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockWETH
 * @dev 用于测试目的的模拟WETH代币
 * 包含一个允许任何人mint代币的函数
 */
contract MockWETH is ERC20 {
    /**
     * @dev 初始化合约，设置代币名称和符号
     */
    constructor() ERC20("Mock Wrapped Ether", "MockWETH") {}

    /**
     * @dev 允许任何人调用的铸造函数
     * @param to 接收铸造代币的地址
     * @param amount 铸造的代币数量
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @dev 存入ETH并获得等量的WETH
     */
    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    /**
     * @dev 销毁WETH并提取等量的ETH
     * @param amount 要提取的ETH数量
     */
    function withdraw(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "MockWETH: insufficient balance");
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {
    }
} 