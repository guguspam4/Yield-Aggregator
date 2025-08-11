# 🌾 Yield Aggregator Smart Contract

A decentralized yield aggregator built on the Stacks blockchain that automatically rebalances user deposits across multiple yield-generating strategies to maximize returns.

## 🚀 Features

- **🏦 Automated Deposits**: Seamlessly deposit STX tokens into the aggregator
- **📊 Strategy Rebalancing**: Automatically redistributes funds across strategies based on performance
- **💰 Multi-Strategy Support**: Manages multiple yield-generating strategies with different risk/reward profiles
- **🔄 Dynamic Allocation**: Adjusts strategy allocations based on APY performance
- **👑 Owner Controls**: Strategy management and fee collection for contract administrators
- **💳 Proportional Withdrawals**: Users can withdraw their share of the total pool at any time

## 🎯 Core Strategies

The contract comes pre-configured with three strategies:

1. **High Yield Strategy** (40% allocation) - 12% APY
2. **Stable Strategy** (30% allocation) - 8% APY  
3. **Conservative Strategy** (30% allocation) - 5% APY

## 📋 Contract Functions

### 💵 User Functions

- `deposit(amount)` - Deposit STX tokens into the aggregator
- `withdraw(amount)` - Withdraw your proportional share of funds
- `get-user-balance(user)` - View your current balance
- `get-user-share-percentage(user)` - View your ownership percentage

### 🔧 Owner Functions

- `add-strategy(name, allocation, apy)` - Add a new yield strategy
- `update-strategy-apy(strategy-id, new-apy)` - Update strategy APY
- `toggle-strategy(strategy-id)` - Enable/disable a strategy
- `rebalance-strategies()` - Manually trigger rebalancing
- `set-management-fee(fee)` - Set management fee (max 10%)
- `collect-fees()` - Collect accumulated management fees

### 📊 Read-Only Functions

- `get-total-deposited()` - Total STX deposited in the contract
- `get-strategy(strategy-id)` - Get strategy details
- `get-all-strategies()` - View all available strategies
- `get-rebalancing-status()` - Check if rebalancing is enabled

## 🛠️ Usage Instructions

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic knowledge of Clarity smart contracts

### 🚀 Getting Started

1. **Deploy the contract**:
   ```bash
   clarinet deploy
   ```

2. **Deposit funds**:
   ```clarity
   (contract-call? .yield-aggregator deposit u1000000)
   ```

3. **Check your balance**:
   ```clarity
   (contract-call? .yield-aggregator get-user-balance tx-sender)
   ```

4. **Trigger rebalancing** (owner only):
   ```clarity
   (contract-call? .yield-aggregator rebalance-strategies)
   ```

5. **Withdraw funds**:
   ```clarity
   (contract-call? .yield-aggregator withdraw u500000)
   ```

### 📈 Strategy Management

**Add a new strategy**:
```clarity
(contract-call? .yield-aggregator add-strategy "DeFi Strategy" u2000 u1500)
```

**Update strategy APY**:
```clarity
(contract-call? .yield-aggregator update-strategy-apy u1 u1300)
```

**Toggle strategy status**:
```clarity
(contract-call? .yield-aggregator toggle-strategy u1)
```

## 🔐 Security Features

- **Owner-only functions** protected by authorization checks
- **Input validation** for all amounts and parameters
- **Insufficient balance protection** for withdrawals
- **Strategy existence verification** before operations
- **Fee limits** to prevent excessive charges

## 💡 How Rebalancing Works

1. **Performance Analysis**: The contract evaluates each strategy's APY
2. **Optimal Allocation**: Calculates the best fund distribution
3. **Automatic Rebalancing**: Moves funds between strategies to optimize returns
4. **Continuous Monitoring**: Tracks performance and adjusts as needed

## 📊 Fee Structure

- **Management Fee**: Configurable (default 1%, max 10%)
- **Performance Fee**: Configurable (default 10%, max 100%)
- **Fee Collection**: Owner can collect accumulated fees

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

## 📝 Contract Constants

- `CONTRACT_OWNER`: The deployer address with administrative privileges
- `ERR_UNAUTHORIZED`: Access denied error (1000)
- `ERR_INSUFFICIENT_BALANCE`: Insufficient funds error (1001)
- `ERR_INVALID_AMOUNT`: Invalid amount error (1002)
- `ERR_STRATEGY_NOT_FOUND`: Strategy doesn't exist error (1003)

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

*Built with ❤️ on Stacks blockchain for decentralized yield optimization*
