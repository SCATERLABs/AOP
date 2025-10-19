# 🔄 Upgradeable Proxy Patterns - Complete Guide

This project demonstrates two major proxy patterns: **Transparent Proxy** and **UUPS (Universal Upgradeable Proxy Standard)**. Both allow upgrading smart contract logic while preserving state, but they differ significantly in their upgrade mechanisms and security models.

---

## 📚 Table of Contents
1. [Core Concepts](#core-concepts)
2. [Transparent Proxy Pattern](#transparent-proxy-pattern)
3. [UUPS Pattern](#uups-pattern)
4. [Key Differences](#key-differences)
5. [Security Considerations](#security-considerations)
6. [Test Scenarios](#test-scenarios)

---

## 🎯 Core Concepts

### What is a Proxy?
A proxy is a contract that:
- **Stores all the state** (storage variables like balances, owner, etc.)
- **Delegates execution** to an implementation contract using `delegatecall`
- **Can be upgraded** to point to a new implementation

### How Delegatecall Works
```
User calls Proxy → Proxy uses delegatecall to Implementation
                    ↓
                 Executes Implementation's CODE
                 But uses Proxy's STORAGE
```

**Key Point:** When you call a function through a proxy:
- The code executed is from the **Implementation**
- The storage modified is in the **Proxy**
- `msg.sender` and `msg.value` are preserved

### EIP-1967 Storage Slots
Both patterns use standardized storage slots to avoid collisions:
```solidity
// Implementation slot
keccak256("eip1967.proxy.implementation") - 1
// = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc

// Admin slot (Transparent Proxy only)
keccak256("eip1967.proxy.admin") - 1
// = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
```

---

## 🛡️ Transparent Proxy Pattern

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    TRANSPARENT PROXY SYSTEM                  │
└─────────────────────────────────────────────────────────────┘

    ┌──────────────────────────┐
    │   ProxyAdmin Contract    │  ← Owns the proxy
    │  - upgrade(proxy, impl)  │  ← Only admin functions
    │  - Has access control    │
    └────────────┬─────────────┘
                 │
                 │ msg.sender = ProxyAdmin
                 ▼
┌────────────────────────────────────────────────────────────┐
│              TransparentProxy Contract                     │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ 🔒 Storage Slots (EIP-1967)                            │ │
│ │   - ADMIN_SLOT      = 0xb531...6103 → ProxyAdmin addr │ │
│ │   - IMPLEMENTATION_SLOT = 0x3608...2bbc → LogicV1 addr│ │
│ │                                                         │ │
│ │ 📦 Proxy's Own Storage (via delegatecall)             │ │
│ │   - uint256 x = 0                                      │ │
│ │   - address owner = alice                              │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                             │
│ fallback() logic:                                           │
│   if (msg.sender == admin) {                               │
│      // Execute admin functions in proxy                   │
│      if (upgradeTo) { update IMPLEMENTATION_SLOT }         │
│      if (admin) { return admin address }                   │
│      else { revert("admin can't call user functions") }    │
│   } else {                                                  │
│      // Normal user → delegatecall to implementation       │
│      delegatecall(implementation, msg.data)                │
│   }                                                         │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          │ delegatecall (for normal users)
                          ▼
            ┌───────────────────────────────┐
            │   LogicV1 Implementation      │
            │ ┌───────────────────────────┐ │
            │ │ CODE (no state stored):   │ │
            │ │ - initialize(owner)       │ │
            │ │ - setX(uint256)           │ │
            │ │ - getX() returns uint256  │ │
            │ └───────────────────────────┘ │
            └───────────────────────────────┘
```

### Call Flow Examples

#### 1️⃣ Normal User Call: `proxy.setX(42)`
```
┌──────┐         ┌─────────────────┐        ┌──────────────┐
│ User │         │ TransparentProxy│        │   LogicV1    │
└──┬───┘         └────────┬────────┘        └──────┬───────┘
   │                      │                        │
   │  setX(42)           │                        │
   ├────────────────────>│                        │
   │                      │                        │
   │                      │ Check: msg.sender == admin?
   │                      │ NO → delegatecall      │
   │                      │                        │
   │                      │  delegatecall(setX,42) │
   │                      ├───────────────────────>│
   │                      │                        │
   │                      │  executes setX() with  │
   │                      │  PROXY's storage       │
   │                      │  (proxy.x = 42)        │
   │                      │<───────────────────────┤
   │  success             │                        │
   │<─────────────────────┤                        │
```

#### 2️⃣ Admin Upgrade: `proxyAdmin.upgrade(proxy, LogicV2)`
```
┌──────────┐    ┌──────────────┐    ┌─────────────────┐
│ProxyAdmin│    │   Transparent│    │     LogicV2     │
│          │    │     Proxy    │    │                 │
└────┬─────┘    └──────┬───────┘    └─────────────────┘
     │                 │
     │ upgrade(addr)   │
     ├────────────────>│
     │                 │
     │                 │ Check: msg.sender == admin?
     │                 │ YES → execute admin function
     │                 │
     │                 │ if (sig == upgradeTo)
     │                 │   update IMPLEMENTATION_SLOT
     │                 │   = LogicV2 address ✅
     │                 │
     │  success        │
     │<────────────────┤
     │                 │
     
Now all future user calls will delegatecall to LogicV2!
```

### Key Mechanism: Function Selector Routing

```solidity
fallback() external payable {
    address admin = load(ADMIN_SLOT);
    address impl = load(IMPLEMENTATION_SLOT);
    
    if (msg.sender == admin) {
        // Admin path - handle admin functions
        bytes4 sig = bytes4(msg.data);
        
        if (sig == bytes4(keccak256("upgradeTo(address)"))) {
            address newImpl = abi.decode(msg.data[4:], (address));
            store(IMPLEMENTATION_SLOT, newImpl); // Update implementation
            return;
        }
        
        if (sig == bytes4(keccak256("admin()"))) {
            return admin; // Return admin address
        }
        
        // Prevent admin from accidentally calling user functions
        revert("admin cannot call proxy forwarded functions");
    }
    
    // User path - delegatecall to implementation
    delegatecall(impl, msg.data);
}
```

### Security Feature: Function Selector Clash Prevention

**Problem:** If implementation has a function with same selector as admin functions, collision occurs!

**Solution:** Transparent Proxy ensures:
- **Admin** can ONLY call admin functions (upgradeTo, admin)
- **Users** can ONLY call implementation functions (setX, getX, etc.)
- No one can accidentally trigger the wrong function

---

## ⚡ UUPS (Universal Upgradeable Proxy Standard) Pattern

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        UUPS SYSTEM                           │
└─────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│              EIP1967ProxyMinimal (UUPS Proxy)              │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ 🔒 Storage Slots (EIP-1967)                            │ │
│ │   - IMPLEMENTATION_SLOT = 0x3608...2bbc → Impl addr   │ │
│ │     (NO ADMIN_SLOT - no admin tracking!)              │ │
│ │                                                         │ │
│ │ 📦 Proxy's Own Storage (via delegatecall)             │ │
│ │   - uint256 x = 0                                      │ │
│ │   - address owner = alice                              │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                             │
│ fallback() logic:                                           │
│   // ALWAYS delegatecall - no admin check!                 │
│   address impl = load(IMPLEMENTATION_SLOT)                 │
│   delegatecall(impl, msg.data)                             │
│                                                             │
│ ⚠️  Simpler but upgrade logic MUST be in implementation!   │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          │ delegatecall (ALL calls)
                          ▼
            ┌─────────────────────────────────────┐
            │   UUPSImplSafe Implementation       │
            │ ┌─────────────────────────────────┐ │
            │ │ CODE includes:                  │ │
            │ │ - initialize(owner)             │ │
            │ │ - setX(uint256)                 │ │
            │ │ - getX()                        │ │
            │ │ - upgradeTo(address) ⚠️         │ │
            │ │   {                              │ │
            │ │     require(msg.sender==owner); │ │ 🔑 Auth here!
            │ │     update IMPLEMENTATION_SLOT; │ │
            │ │   }                              │ │
            │ └─────────────────────────────────┘ │
            └─────────────────────────────────────┘
```

### Call Flow Examples

#### 1️⃣ Normal User Call: `proxy.setX(42)`
```
┌──────┐         ┌──────────────┐        ┌──────────────┐
│ User │         │  UUPS Proxy  │        │  UUPSImpl    │
└──┬───┘         └──────┬───────┘        └──────┬───────┘
   │                    │                       │
   │  setX(42)         │                       │
   ├──────────────────>│                       │
   │                    │                       │
   │                    │ NO admin check!       │
   │                    │ ALWAYS delegatecall   │
   │                    │                       │
   │                    │  delegatecall(setX,42)│
   │                    ├──────────────────────>│
   │                    │                       │
   │                    │  executes setX() with │
   │                    │  PROXY's storage      │
   │                    │  (proxy.x = 42)       │
   │                    │<──────────────────────┤
   │  success          │                       │
   │<───────────────────┤                       │
```

#### 2️⃣ Owner Upgrade: `proxy.upgradeTo(LogicV2)` 
```
┌───────┐        ┌──────────────┐        ┌──────────────┐
│ Owner │        │  UUPS Proxy  │        │  UUPSImpl    │
└───┬───┘        └──────┬───────┘        └──────┬───────┘
    │                   │                       │
    │ upgradeTo(V2)     │                       │
    ├──────────────────>│                       │
    │                   │                       │
    │                   │ delegatecall           │
    │                   │ upgradeTo(V2)         │
    │                   ├──────────────────────>│
    │                   │                       │
    │                   │  require(msg.sender == owner) ✅
    │                   │  update IMPLEMENTATION_SLOT
    │                   │  = LogicV2 address    │
    │                   │<──────────────────────┤
    │  success          │                       │
    │<──────────────────┤                       │
```

#### 3️⃣ ⚠️ Attacker tries upgrade (VULNERABLE implementation):
```
┌──────────┐     ┌──────────────┐     ┌──────────────────┐
│ Attacker │     │  UUPS Proxy  │     │ UUPSImplVulnerable│
└────┬─────┘     └──────┬───────┘     └─────────┬────────┘
     │                  │                       │
     │ upgradeTo(Evil)  │                       │
     ├─────────────────>│                       │
     │                  │                       │
     │                  │ delegatecall          │
     │                  │ upgradeTo(Evil)       │
     │                  ├──────────────────────>│
     │                  │                       │
     │                  │  ⚠️ NO AUTH CHECK!    │
     │                  │  update IMPLEMENTATION_SLOT
     │                  │  = Evil address ❌    │
     │                  │<──────────────────────┤
     │  success ☠️      │                       │
     │<─────────────────┤                       │
     
💀 PROXY IS NOW COMPROMISED! Points to attacker's contract!
```

### Implementation Comparison

#### ❌ VULNERABLE Implementation (Missing Authorization)
```solidity
contract UUPSImplVulnerable is LogicV1 {
    function upgradeTo(address newImpl) public {
        // ⚠️ NO ACCESS CONTROL - ANYONE CAN UPGRADE!
        bytes32 slot = keccak256("eip1967.proxy.implementation") - 1;
        assembly { sstore(slot, newImpl) }
    }
}
```

#### ✅ SAFE Implementation (With Authorization)
```solidity
contract UUPSImplSafe is LogicV1 {
    function upgradeTo(address newImpl) public {
        require(msg.sender == owner, "not owner"); // 🔒 AUTH CHECK!
        bytes32 slot = keccak256("eip1967.proxy.implementation") - 1;
        assembly { sstore(slot, newImpl) }
    }
}
```

---

## 🔄 Key Differences

| Feature | Transparent Proxy | UUPS |
|---------|------------------|------|
| **Upgrade Logic Location** | In Proxy contract | In Implementation contract |
| **Admin Tracking** | Proxy stores admin in ADMIN_SLOT | No admin slot (auth in implementation) |
| **Function Selector Clash** | Solved by caller-based routing | Implementation must avoid clashes |
| **Upgrade Authorization** | ProxyAdmin contract controls | Implementation's upgradeTo() controls |
| **Gas Cost (per call)** | Higher (admin check on every call) | Lower (no admin check) |
| **Proxy Complexity** | More complex fallback logic | Simpler (always delegatecall) |
| **Implementation Complexity** | Simpler (no upgrade function needed) | Must include upgradeTo() |
| **Security Risk** | Admin key compromise | Forgetting auth in upgradeTo() |
| **Upgradeability** | Can always upgrade | Can be bricked if implementation has bug |

### Visual Comparison: Call Routing

```
TRANSPARENT PROXY:
┌────────────────────────────────────────┐
│ Is caller == admin?                    │
│  ├─ YES → Execute admin functions      │
│  │         (upgradeTo, admin)          │
│  │                                      │
│  └─ NO  → delegatecall to impl         │
│           (user functions)             │
└────────────────────────────────────────┘

UUPS PROXY:
┌────────────────────────────────────────┐
│ ALWAYS delegatecall to implementation  │
│ (both user and upgrade functions)      │
└────────────────────────────────────────┘
```

---

## 🔐 Security Considerations

### 1. Initialization Vulnerability

**Problem:** Implementations can be initialized directly on their deployed address!

```solidity
// Deploy implementation
Implementation impl = new Implementation();

// ❌ DANGER: Attacker can call initialize on implementation contract directly!
impl.initialize(); // Attacker becomes owner of implementation

// Even though users interact via proxy, the implementation 
// being controlled by attacker is a security issue
```

**Solution:** Disable initializers in implementation constructor (OpenZeppelin style):
```solidity
contract ImplementationSafe {
    bool private _initialized;
    
    constructor() {
        _initialized = true; // Disable initialization on implementation
    }
    
    function initialize() public {
        require(!_initialized, "already initialized");
        _initialized = true;
        owner = msg.sender;
    }
}
```

### 2. Storage Layout Compatibility

**Critical Rule:** New implementations MUST maintain storage layout!

```solidity
// ✅ SAFE UPGRADE
contract V1 {
    uint256 public x;  // slot 0
    address public owner; // slot 1
}

contract V2 {
    uint256 public x;  // slot 0 - same position ✅
    address public owner; // slot 1 - same position ✅
    uint256 public y;  // slot 2 - new variable OK ✅
}

// ❌ UNSAFE UPGRADE
contract V2Bad {
    address public owner; // slot 0 - WRONG! Was slot 1 ❌
    uint256 public x;  // slot 1 - WRONG! Was slot 0 ❌
}
```

### 3. UUPS Specific: Missing Authorization

```solidity
// ❌ CRITICAL BUG - Missing auth allows anyone to upgrade!
function upgradeTo(address newImpl) public {
    // No require() check!
    assembly { sstore(IMPLEMENTATION_SLOT, newImpl) }
}

// ✅ CORRECT - Only authorized users can upgrade
function upgradeTo(address newImpl) public {
    require(msg.sender == owner || hasRole(UPGRADER_ROLE, msg.sender));
    assembly { sstore(IMPLEMENTATION_SLOT, newImpl) }
}
```

### 4. Transparent Proxy: ProxyAdmin Security

```solidity
// ProxyAdmin should have:
// 1. Ownership / Access Control
// 2. Timelock for upgrades
// 3. Multi-sig requirements

contract ProxyAdmin is Ownable {
    function upgrade(TransparentProxy proxy, address newImpl) 
        public 
        onlyOwner  // 🔒 Only owner can upgrade
    {
        proxy.upgradeTo(newImpl);
    }
}
```

---

## 🧪 Test Scenarios

### Test 1: Transparent Proxy Upgrade
```solidity
function test_transparent_upgrade_by_admin() public {
    // 1. Initialize proxy with alice as owner
    proxy.initialize(alice);
    
    // 2. Verify alice is owner (via delegatecall to LogicV1)
    assertEq(proxy.owner(), alice);
    
    // 3. ProxyAdmin upgrades to LogicV2
    proxyAdmin.upgrade(transparentProxy, address(logic2));
    
    // 4. Call new function from LogicV2
    proxy.inc(); // Increments x
    
    // 5. State is preserved!
    assertEq(proxy.getX(), 1);
}
```

**Flow:**
```
Step 1: Proxy → delegatecall → LogicV1.initialize()
        Proxy.storage.owner = alice ✅

Step 2: Proxy → delegatecall → LogicV1.owner()
        Returns alice ✅

Step 3: ProxyAdmin.upgrade(LogicV2)
        → Proxy (as admin) → IMPLEMENTATION_SLOT = LogicV2 ✅

Step 4: Proxy → delegatecall → LogicV2.inc()
        Proxy.storage.x = 1 ✅

Step 5: Proxy → delegatecall → LogicV2.getX()
        Returns 1 ✅
```

### Test 2: UUPS Vulnerable to Attack
```solidity
function test_uups_vulnerable_upgrade_by_attacker() public {
    // 1. Initialize proxy with alice as owner
    uupsProxy.initialize(alice);
    
    // 2. Attacker calls upgradeTo() - NO AUTH CHECK!
    vm.prank(attacker);
    uupsProxy.upgradeTo(address(logic2)); // ❌ Should fail but doesn't!
    
    // 3. Proxy now points to logic2
    uupsProxy.inc(); // Works!
    assertEq(uupsProxy.getX(), 1);
    
    // 💀 Attacker successfully upgraded the proxy!
}
```

**Attack Flow:**
```
Step 1: Attacker → UUPSProxy.upgradeTo(EvilContract)
        ↓
Step 2: Proxy → delegatecall → UUPSImplVulnerable.upgradeTo()
        ↓
Step 3: NO require(msg.sender == owner) check!
        ↓
Step 4: IMPLEMENTATION_SLOT = EvilContract ☠️
        ↓
Result: ALL future calls go to attacker's contract!
```

### Test 3: UUPS Safe Implementation
```solidity
function test_uups_safe_requires_owner_for_upgrade() public {
    // 1. Deploy proxy with SAFE implementation
    EIP1967ProxyMinimal safeProxy = new EIP1967ProxyMinimal(address(uupsSafeImpl));
    safeProxy.initialize(alice);
    
    // 2. Attacker tries to upgrade - FAILS!
    vm.prank(attacker);
    (bool ok, ) = address(safeProxy).call(
        abi.encodeWithSignature("upgradeTo(address)", address(logic2))
    );
    require(!ok); // ✅ Correctly reverted!
    
    // 3. Owner (alice) upgrades - SUCCEEDS!
    vm.prank(alice);
    safeProxy.upgradeTo(address(logic2)); // ✅ Works!
    
    // 4. New functionality available
    safeProxy.inc();
    assertEq(safeProxy.getX(), 1);
}
```

**Safe Flow:**
```
Attacker attempts:
  Attacker → Proxy → delegatecall → UUPSImplSafe.upgradeTo()
  → require(msg.sender == owner) ❌ REVERTS!

Owner attempts:
  Alice → Proxy → delegatecall → UUPSImplSafe.upgradeTo()
  → require(msg.sender == owner) ✅ PASSES!
  → IMPLEMENTATION_SLOT = LogicV2 ✅
```

---

## 📊 Summary

### When to use Transparent Proxy:
✅ Need stronger separation between admin and user functions  
✅ Want to prevent function selector clashes automatically  
✅ Prefer admin logic separate from implementation  
✅ Willing to pay slightly higher gas costs  

### When to use UUPS:
✅ Want cheaper deployment and execution costs  
✅ Need upgrade logic customization per implementation  
✅ Have strong testing and audit processes  
✅ Want simpler proxy contract  

### Critical Reminders:
⚠️ **ALWAYS** implement authorization in UUPS `upgradeTo()`  
⚠️ **ALWAYS** disable initialization on implementation contracts  
⚠️ **ALWAYS** maintain storage layout compatibility  
⚠️ **ALWAYS** test upgrade paths thoroughly  
⚠️ **ALWAYS** use timelock/multisig for production upgrades  

---

## 🚀 Running Tests

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run specific test
forge test --match-test test_transparent_upgrade_by_admin -vvv
```

**Expected Results:**
```
✅ test_transparent_upgrade_by_admin() - Demonstrates safe Transparent Proxy upgrade
✅ test_uups_vulnerable_upgrade_by_attacker() - Shows UUPS vulnerability without auth
✅ test_uups_safe_requires_owner_for_upgrade() - Demonstrates safe UUPS with auth
```

