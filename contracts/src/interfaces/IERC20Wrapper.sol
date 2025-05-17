// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ITokenWrapper.sol";

/**
 * @title IERC20Wrapper
 * @notice Interface for the ERC20Wrapper contract
 * @dev Extends ITokenWrapper with additional ERC20Wrapper-specific functionality
 */
interface IERC20Wrapper is ITokenWrapper {
    // Events
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);
    event WithdrawRequested(address indexed src, address indexed to, uint wad, uint256 indexed requestId);
    event Redeemed(address indexed src, address indexed to, uint wad, uint256 indexed requestId);
    
    /**
     * @notice Struct representing a withdrawal request
     */
    struct WithdrawRequest {
        uint256 amount;
        address recipient;
    }
    
    /**
     * @notice Total supply of wrapped tokens
     * @return The total supply
     */
    function totalSupply() external view returns (uint256);
} 