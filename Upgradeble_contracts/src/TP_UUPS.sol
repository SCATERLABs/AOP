// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Foundry-ready demo comparing Transparent Proxy pattern vs UUPS pattern.
// - Minimal TransparentProxy + ProxyAdmin implementation
// - Minimal UUPS proxy + implementations (one missing auth, one with auth)
// - Tests to show differences and exploit surface when protections are missing

import "forge-std/Test.sol";

// -------------------------
// Implementation: simple logic contract
// -------------------------
contract LogicV1 {
    uint256 public x;
    address public owner;

    function initialize(address _owner) public {
        require(owner == address(0), "initialized");
        owner = _owner;
    }

    function setX(uint256 _x) public {
        require(msg.sender == owner, "only owner");
        x = _x;
    }

    function getX() public view returns (uint256) {
        return x;
    }
}

contract LogicV2 is LogicV1 {
    function inc() public {
        x += 1;
    }
}

// -------------------------
// Minimal Transparent proxy + ProxyAdmin
// Proxy forwards calls to implementation unless caller is admin.
// Admin can upgrade implementation via ProxyAdmin contract.
// -------------------------
contract TransparentProxy {
    // EIP-1967 implementation slot
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    // EIP-1967 admin slot
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    constructor(address _impl, address _admin) {
        bytes32 implSlot = IMPLEMENTATION_SLOT;
        bytes32 adminSlot = ADMIN_SLOT;
        assembly { sstore(implSlot, _impl) }
        assembly { sstore(adminSlot, _admin) }
    }

    // Only admin calls manage proxy - admin calls are not forwarded.
    fallback() external payable {
        address admin;
        address impl;
        bytes32 adminSlot = ADMIN_SLOT;
        bytes32 implSlot = IMPLEMENTATION_SLOT;
        assembly { admin := sload(adminSlot) }
        assembly { impl := sload(implSlot) }

        if (msg.sender == admin) {
            // Admin functions are implemented in this proxy for demo simplicity
            // First 4 bytes determine function selector
            bytes4 sig = bytes4(msg.data);
            // selector for upgradeTo(address)
            if (sig == bytes4(keccak256("upgradeTo(address)"))) {
                address newImpl = abi.decode(msg.data[4:], (address));
                bytes32 implSlot = IMPLEMENTATION_SLOT;
                assembly { sstore(implSlot, newImpl) }
                return;
            }
            // selector for admin() -> returns admin
            if (sig == bytes4(keccak256("admin()"))) {
                assembly { 
                    mstore(0x00, admin)
                    return(0x00, 32)
                }
            }
            // if admin called any other function, revert to avoid accidental delegatecall
            revert("admin cannot call proxy forwarded functions");
        }

        // Non-admin: forward to implementation
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

contract ProxyAdmin {
    function upgrade(TransparentProxy proxy, address newImpl) public {
        // In a real system, access control (timelock/multisig) must be applied. Omitted here.
        // Calls proxy as admin to run its admin-only path
        (bool ok, ) = address(proxy).call(abi.encodeWithSignature("upgradeTo(address)", newImpl));
        require(ok, "upgrade failed");
    }
}

// -------------------------
// Minimal UUPS proxy (like ERC1967Proxy minimal)
// Proxy only stores impl and always delegatecalls.
// Upgrade happens by calling implementation's upgradeTo via delegatecall.
// -------------------------
contract EIP1967ProxyMinimal {
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    constructor(address _impl) {
        bytes32 implSlot = IMPLEMENTATION_SLOT;
        assembly { sstore(implSlot, _impl) }
    }

    fallback() external payable {
        address impl;
        bytes32 implSlot = IMPLEMENTATION_SLOT;
        assembly { impl := sload(implSlot) }
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

// UUPS Implementation WITHOUT authorization (vulnerable)
contract UUPSImplVulnerable is LogicV1 {
    // upgrade function WITHOUT access control - vulnerable!
    function upgradeTo(address newImpl) public {
        // write to implementation slot in proxy storage (delegatecall context)
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        assembly { sstore(slot, newImpl) }
    }
}

// UUPS Implementation WITH authorization (safe)
contract UUPSImplSafe is LogicV1 {
    function upgradeTo(address newImpl) public {
        require(msg.sender == owner, "not owner"); // simple owner check
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        assembly { sstore(slot, newImpl) }
    }
}

