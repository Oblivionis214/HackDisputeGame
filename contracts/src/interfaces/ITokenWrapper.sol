// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ITokenWrapper
 * @notice Interface for token wrapping, defining functions for depositing and withdrawing tokens
 * @dev Extends the IERC20 interface with additional functionality for wrapped tokens
 */
interface ITokenWrapper is IERC20 {
    /**
     * @notice Get the address of the underlying token
     * @return The IERC20 token contract being wrapped
     */
    function underlyingToken() external view returns (IERC20);
    
    /**
     * @notice Get the address of the dispute resolver contract
     * @return The address of the dispute resolver
     */
    function disputeResolver() external view returns (address);
    
    /**
     * @notice Get the details of a withdrawal request
     * @param user Address of the user who made the request
     * @param requestId ID of the withdrawal request
     * @return amount The amount of tokens requested for withdrawal
     * @return recipient The address that will receive the tokens
     */
    function withdrawRequests(address user, uint256 requestId) external view returns (uint256 amount, address recipient);
    
    /**
     * @notice Deposit underlying tokens and receive wrapped tokens
     * @param wad Amount of tokens to deposit
     */
    function deposit(uint wad) external;
    
    /**
     * @notice Withdraw wrapped tokens to the caller's address
     * @param wad Amount of tokens to withdraw
     */
    function withdraw(uint wad) external;
    
    /**
     * @notice Withdraw wrapped tokens to a specified address
     * @param wad Amount of tokens to withdraw
     * @param to Recipient address
     */
    function withdraw(uint wad, address to) external;
    
    /**
     * @notice Redeem a validated withdrawal request
     * @param requestId ID of the withdrawal request to redeem
     */
    function redeem(uint256 requestId) external;
} 