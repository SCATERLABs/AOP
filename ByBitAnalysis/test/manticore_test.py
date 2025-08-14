from manticore.ethereum import ManticoreEVM

m = ManticoreEVM()

# Create user account
user_account = m.create_account(balance=10**18)

# Load the contract
with open('src/SimpleBank.sol', 'r') as f:
    source_code = f.read()

contract_account = m.solidity_create_contract(
    source_code,
    owner=user_account,
    contract_name='SimpleBank'
)

# Symbolic value for withdrawal
symbolic_amount = m.make_symbolic_value()

# Deposit some ETH
contract_account.deposit(value=100, caller=user_account)

# Try withdrawing symbolic amount
contract_account.withdraw(symbolic_amount, caller=user_account)

# Explore paths
m.run()
