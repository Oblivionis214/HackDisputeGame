// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IDisputeResolver
 * @notice Interface for withdrawal validation, used to verify user withdrawal requests
 * @dev Implementations must provide methods to create and validate withdrawal requests
 */
interface IDisputeResolver {
    /**
     * @notice Create a new withdrawal request for a user
     * @param user Address of the user requesting withdrawal
     * @param amount Amount of tokens to withdraw
     * @return requestId Unique identifier for the withdrawal request
     */
    function pushWithdrawRequest(address user, uint256 amount) external returns (uint256 requestId);
    
    /**
     * @notice Validate a withdrawal request
     * @param user Address of the user who made the request
     * @param requestId ID of the withdrawal request to validate
     * @return isValid Whether the withdrawal request is valid
     */
    function validateWithdraw(address user, uint256 requestId) external view returns (bool isValid);
} 