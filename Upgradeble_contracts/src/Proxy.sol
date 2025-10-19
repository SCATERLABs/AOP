// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Simple demonstration of an implementation contract that can be initialized
// directly (vulnerable) vs a contract that disables initializers in its constructor.
// This file contains minimal initializer logic (no OZ imports) for clarity and
// a Foundry test illustrating the issue.

import "forge-std/Test.sol";

contract ImplementationVulnerable {
    address public owner;
    bool private _initialized;

    // initializer (simulates OpenZeppelin's initializer modifier)
    function initialize() public {
        require(!_initialized, "already initialized");
        _initialized = true;
        owner = msg.sender;
    }

    // some protected action
    function privilegedAction() public view returns (string memory) {
        require(msg.sender == owner, "only owner");
        return "privileged";
    }
}

contract ImplementationSafe {
    address public owner;
    bool private _initialized;

    constructor() {
        // simulate OZ's _disableInitializers()
        _initialized = true;
    }

    function initialize() public {
        require(!_initialized, "already initialized");
        _initialized = true;
        owner = msg.sender;
    }

    function privilegedAction() public view returns (string memory) {
        require(msg.sender == owner, "only owner");
        return "privileged";
    }
}

// A minimal proxy that stores an implementation address and delegatecalls on fallback.
contract SimpleProxy {
    // EIP-1967-like slot (not strictly necessary here, but keeps the pattern)
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    constructor(address _impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly { sstore(slot, _impl) }
    }

    fallback() external payable {
        bytes32 slot = IMPLEMENTATION_SLOT;
        address impl;
        assembly { impl := sload(slot) }
        assembly {
            // copy calldata
            calldatacopy(0, 0, calldatasize())
            // delegatecall
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            // copy return data
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}