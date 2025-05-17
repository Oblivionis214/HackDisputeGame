# HackDisputeGame
HackDisputeGame monorepo for ETHBeijing 2025

## Project Introduction

HackDisputeGame is a universal optimistic withdraw queue solution designed for all on-chain applications, with the core goal of minimizing the risk of all hacks. It enables integrated protocols to:

- Integrate with a single click — no logic changes or redeployment required

- Preserve the original trust model — no additional trust assumptions, maintaining full decentralization

- Maintain seamless user experience — with support for EIP-7702, users need to take no extra steps

## System components

- `DisputeGameFactory`: Responsible for creating dispute game instances
- `StakingPool`: User staking pool, supporting both attacker and defender roles
- `OptimisticDisputeGameResolver`: Dispute resolver
- `ERC20Wrapper`: Token wrapping contract
- `SystemFactory`: System deployment factory

## Deployed address

The following are the contract deployment addresses on Ethereum Sepolia testnet:

| Contract  | Address |
|---------|------|
| OptimisticDisputeGame impl | 0x04409D09EA82d3954A23655f3640428C879F7442 |
| StakingPool impl | 0x0fbeBD16a02c26ecE90f39cd422D317C17dD808d |
| SystemFactory | 0x0aE4730BE8Dc6FDE9e4F40AFBEfaF63b3A383C1C |

We deployed a demo at:

| Contract Name | Address |
|---------|------|
| Mock WETH | 0x1df44B5C1160fca5AE1d9430D221A6c39CCEd00D |
| TokenWrapper | 0x0E5eee2Ae97ED5FDE258fdE27dB3d85c97124bC0 |
| OptimisticDisputeGameResolver | 0x1ebAbed3057e4C53F1d7E002046b3b832a330852 |
| DisputeGameFactory | 0xeD6f6b001D9d2A2517c196D56C29e2666056349A |

## Environment Setup

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- [Node.js](https://nodejs.org/) v16+
- [Git](https://git-scm.com/)

### Installation Steps

1. Clone the repository

```bash
git clone https://github.com/Oblivionis214/HackDisputeGame.git
cd HackDisputeGame
```

2. Install dependencies

```bash
forge install
```

## Build

Compile all contracts:

```bash
forge build --via-ir
```

## Testing

Run all tests:

```bash
forge test --via-ir
```

Run specific tests:

```bash
# Test the token wrapper
forge test --match-contract ERC20WrapperTest --via-ir -vv

# Test the whole HDG flow
forge test --match-contract ERC20DisputeFlowTest --via-ir -vv

# Test system deployment
forge test --match-contract SystemFactoryTest --via-ir -vv
```

Use verbosity flags for more details:
- `-v`: Display test names
- `-vv`: Also display fuzzing inputs
- `-vvv`: Also display emitted events
- `-vvvv`: Also display all traces, including for passing tests

## Integration Steps

To integrate your protocol into the HackDisputeGame system, follow these steps:

### 1. Deploy Using SystemFactory

The most straightforward way to integrate is by using the `deploySystem` function in SystemFactory:

```solidity
function deploySystem(
    uint256 _disputeStake,
    uint256 _validationTimeout,
    string memory _name,
    string memory _symbol,
    address _underlyingToken
) external returns (address factory, address resolver, address wrapper);
```

Parameters:
- `_disputeStake`: Minimum amount of tokens required to initiate a dispute
- `_validationTimeout`: Timeout period in seconds for withdrawal validation
- `_name`: Name for the wrapped token
- `_symbol`: Symbol for the wrapped token
- `_underlyingToken`: Address of your token to be wrapped

Example usage:

```solidity
// 1. Ensure you have deployed SystemFactory and implementation contracts
address systemFactoryAddress = 0x...;
SystemFactory factory = SystemFactory(systemFactoryAddress);

// 2. Configure your parameters
uint256 disputeStake = 10 * 10**18; // 10 tokens minimum stake
uint256 timeout = 1 days; // 1 day validation period
string memory name = "Wrapped MyToken";
string memory symbol = "WMYT";
address myToken = 0x...; // Your token address

// 3. Deploy the full system
(address gameFactory, address resolver, address wrapper) = factory.deploySystem(
    disputeStake,
    timeout,
    name,
    symbol,
    myToken
);

// 4. Store these addresses for further interaction
```

### 2. Verify Deployment

After deployment, verify the three returned addresses are valid:
- `gameFactory`: The dispute game factory that creates game instances
- `resolver`: The dispute resolver linked to your token
- `wrapper`: The ERC20 wrapper for your token

These addresses are essential for user interaction with the system.

## System Interaction

After the complete system is deployed, users can perform the following operations:

1. Deposit base tokens into the ERC20Wrapper to receive wrapped tokens
2. Request withdrawals using wrapped tokens
3. Wait for the verification period or participate in dispute games
4. Redeem base tokens after successful verification

