// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IDisputeResolver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BaseDisputeResolver
 * @author Oblivionis
 * @notice Abstract base implementation for withdrawal validation that provides fundamental request management and validation logic
 * @dev This abstract contract should be extended to implement specific validation strategies by overriding the _internalValidate function
 */
abstract contract BaseDisputeResolver is IDisputeResolver, Ownable {
    struct WithdrawRequest {
        address user;
        uint256 amount;
        uint256 timestamp;
        bool disputed;
        bool valid;
    }
    
    /// @notice request ID => WithdrawRequest
    mapping(uint256 => WithdrawRequest) public requests;
    
    /// @notice user address => request IDs
    mapping(address => uint256[]) public userRequestIds;
    
    /// @notice Current request ID counter
    uint256 private _currentRequestId;
    
    /// @notice Timeout period for validation in seconds
    uint256 public validationTimeout;
    
    /// @notice Address of the TokenWrapper contract
    address public tokenWrapper;
    
    /// @notice Events for tracking request lifecycle
    event WithdrawRequestCreated(uint256 indexed requestId, address indexed user, uint256 amount, uint256 timestamp);
    event WithdrawRequestValidated(uint256 indexed requestId, bool valid);
    event TokenWrapperSet(address indexed previousWrapper, address indexed newWrapper);
    
    /**
     * @notice Initializes the BaseDisputeResolver with a validation timeout
     * @param _validationTimeout Initial timeout period for validation in seconds
     */
    constructor(uint256 _validationTimeout) {
        validationTimeout = _validationTimeout;
    }
    
    /**
     * @notice Restricts function access to the TokenWrapper contract only
     */
    modifier onlyTokenWrapper() {
        require(msg.sender == tokenWrapper, "Caller is not the TokenWrapper");
        _;
    }
    
    /**
     * @notice Sets the TokenWrapper contract address
     * @param _tokenWrapper Address of the new TokenWrapper contract
     */
    function setTokenWrapper(address _tokenWrapper) external onlyOwner {
        require(_tokenWrapper != address(0), "TokenWrapper cannot be zero address");
        emit TokenWrapperSet(tokenWrapper, _tokenWrapper);
        tokenWrapper = _tokenWrapper;
    }
    
    /**
     * @notice Creates a new withdrawal request
     * @dev Only callable by the TokenWrapper contract
     * @param user Address of the user requesting withdrawal
     * @param amount Amount of tokens to withdraw
     * @return requestId Unique identifier for the withdrawal request
     */
    function pushWithdrawRequest(address user, uint256 amount) external override onlyTokenWrapper returns (uint256 requestId) {
        require(amount > 0, "Amount must be greater than 0");
        
        requestId = _currentRequestId++;
        
        requests[requestId] = WithdrawRequest({
            user: user,
            amount: amount,
            timestamp: block.timestamp,
            disputed: false,
            valid: false
        });
        
        userRequestIds[user].push(requestId);
        
        emit WithdrawRequestCreated(requestId, user, amount, block.timestamp);
        
        return requestId;
    }
    
    /**
     * @notice Validates a withdrawal request
     * @dev The base implementation approves requests after a timeout period
     * @param user Address of the user who made the request
     * @param requestId ID of the withdrawal request to validate
     * @return isValid Whether the withdrawal request is valid
     */
    function validateWithdraw(address user, uint256 requestId) external view override returns (bool isValid) {
        WithdrawRequest storage request = requests[requestId];
        
        // Logic that must be implemented in derived contracts
        return _internalValidate(user, requestId);
    }
    
    /**
     * @notice Internal validation logic that must be implemented by subclasses
     * @dev This function must be overridden to provide specific validation logic
     * @param user Address of the user who made the request
     * @param requestId ID of the withdrawal request to validate
     * @return Whether the withdrawal request is valid according to internal logic
     */
    function _internalValidate(address user, uint256 requestId) internal virtual view returns (bool);
    
    
    /**
     * @notice Updates the validation timeout period
     * @param newTimeout New timeout period in seconds
     */
    function setValidationTimeout(uint256 newTimeout) external onlyOwner {
        validationTimeout = newTimeout;
    }
    
    /**
     * @notice Gets all request IDs for a specific user
     * @param user Address of the user
     * @return Array of request IDs for the user
     */
    function getUserRequestIds(address user) external view returns (uint256[] memory) {
        return userRequestIds[user];
    }
    
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
    ) {
        WithdrawRequest storage request = requests[requestId];
        return (
            request.user,
            request.amount,
            request.timestamp,
            request.disputed,
            request.valid
        );
    }
} 