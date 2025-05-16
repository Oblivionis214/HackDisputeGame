// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IDisputeResolver.sol";
import "./interfaces/ITokenWrapper.sol";

/**
 * @title ERC20Wrapper
 * @author Oblivionis
 * @notice HDG ERC20 token wrapper contract based on WETH9 design that allows users to deposit underlying tokens 
 * and receive wrapped tokens in return
 * @dev Withdrawals require validation through the DisputeResolver contract
 */

contract ERC20Wrapper is ERC20, ITokenWrapper {
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);
    event WithdrawRequested(address indexed src, address indexed to, uint wad, uint256 indexed requestId);
    event Redeemed(address indexed src, address indexed to, uint wad, uint256 indexed requestId);
    
    struct WithdrawRequest {
        uint256 amount;
        address recipient;
    }
    
    /// @notice Maps user addresses to their withdrawal requests by requestId
    mapping (address => mapping (uint256 => WithdrawRequest)) public withdrawRequests;
    
    IERC20 public underlyingToken;
    IDisputeResolver private _disputeResolver;
    
    /**
     * @notice Initialize the TokenWrapper contract
     * @param _name Name of the wrapped token
     * @param _symbol Symbol of the wrapped token
     * @param _underlyingToken Address of the token to be wrapped
     * @param __disputeResolver Address of the dispute resolution contract
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _underlyingToken,
        address __disputeResolver
    ) ERC20(_name, _symbol) {
        require(_underlyingToken != address(0), "Invalid underlying token");
        require(__disputeResolver != address(0), "Invalid dispute resolver");
        underlyingToken = IERC20(_underlyingToken);
        _disputeResolver = IDisputeResolver(__disputeResolver);
    }
    
    /**
     * @notice Get the address of the dispute resolver contract
     * @return The address of the dispute resolver
     */
    function disputeResolver() public view returns (address) {
        return address(_disputeResolver);
    }
    
    /**
     * @notice Deposit underlying tokens and receive wrapped tokens
     * @param wad Amount of tokens to deposit
     */
    function deposit(uint wad) public override {
        require(wad > 0, "Amount must be greater than 0");
        require(underlyingToken.transferFrom(msg.sender, address(this), wad), "Transfer failed");
        _mint(msg.sender, wad);
        emit Deposit(msg.sender, wad);
    }
    
    /**
     * @notice Withdraw wrapped tokens to a specified address
     * @param wad Amount of tokens to withdraw
     * @param to Recipient address
     */
    function withdraw(uint wad, address to) public override {
        require(to != address(0), "Invalid recipient");
        require(balanceOf(msg.sender) >= wad, "Insufficient balance");
        _burn(msg.sender, wad);
        
        // Submit withdrawal request to DisputeResolver
        uint256 requestId = _disputeResolver.pushWithdrawRequest(msg.sender, wad);
        withdrawRequests[msg.sender][requestId] = WithdrawRequest({
            amount: wad,
            recipient: to
        });
        
        emit WithdrawRequested(msg.sender, to, wad, requestId);
    }
    
    /**
     * @notice Convenience method to withdraw to the caller's own address
     * @param wad Amount of tokens to withdraw
     */
    function withdraw(uint wad) public override {
        withdraw(wad, msg.sender);
    }
    
    /**
     * @notice Redeem a validated withdrawal request
     * @param requestId ID of the withdrawal request to redeem
     */
    function redeem(uint256 requestId) public override {
        WithdrawRequest memory request = withdrawRequests[msg.sender][requestId];
        require(request.amount > 0, "No withdrawal request found");
        
        // Validate the withdrawal request
        require(_disputeResolver.validateWithdraw(msg.sender, requestId), "Withdrawal request not validated");
        
        address recipient = request.recipient;
        uint256 amount = request.amount;
        
        // Clear the withdrawal request
        withdrawRequests[msg.sender][requestId].amount = 0;
        
        // Transfer underlying tokens to the specified recipient
        require(underlyingToken.transfer(recipient, amount), "Transfer failed");
        
        emit Withdrawal(msg.sender, amount);
        emit Redeemed(msg.sender, recipient, amount, requestId);
    }
    
    /**
     * @notice Get the total supply of wrapped tokens
     * @return Total supply amount
     */
    function totalSupply() public view override(ERC20, IERC20) returns (uint256) {
        return super.totalSupply();
    }
} 