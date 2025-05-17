// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IDisputeResolver.sol";

/**
 * @title IBaseDisputeResolver
 * @notice Interface for BaseDisputeResolver including token wrapper management
 */
interface IBaseDisputeResolver is IDisputeResolver {
    struct WithdrawRequest {
        address user;
        uint256 amount;
        uint256 timestamp;
        bool disputed;
        bool valid;
    }
    
    // Events
    event WithdrawRequestCreated(uint256 indexed requestId, address indexed user, uint256 amount, uint256 timestamp);
    event WithdrawRequestValidated(uint256 indexed requestId, bool valid);
    event TokenWrapperSet(address indexed previousWrapper, address indexed newWrapper);
    
    /**
     * @notice Sets the TokenWrapper contract address
     * @param _tokenWrapper Address of the new TokenWrapper contract
     */
    function setTokenWrapper(address _tokenWrapper) external;
    
    /**
     * @notice Updates the validation timeout period
     * @param newTimeout New timeout period in seconds
     */
    function setValidationTimeout(uint256 newTimeout) external;
    
    /**
     * @notice Gets the current token wrapper address
     */
    function tokenWrapper() external view returns (address);
    
    /**
     * @notice Gets the validation timeout period
     */
    function validationTimeout() external view returns (uint256);
    
    /**
     * @notice Gets all request IDs for a specific user
     * @param user Address of the user
     * @return Array of request IDs for the user
     */
    function getUserRequestIds(address user) external view returns (uint256[] memory);
    
    /**
     * @notice Gets the details of a specific withdrawal request
     * @param requestId ID of the withdrawal request
     * @return user Address of the requesting user
     * @return amount Amount of tokens requested
     * @return timestamp Time when the request was created
     * @return disputed Whether the request has been disputed
     * @return valid Whether the request is valid
     */
    function getRequestDetails(uint256 requestId) external view returns (
        address user,
        uint256 amount,
        uint256 timestamp,
        bool disputed,
        bool valid
    );
} 