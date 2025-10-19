

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;    

import "forge-std/Test.sol";
import "../src/Proxy.sol";
contract ProxyInitTest is Test {
    ImplementationVulnerable implVuln;
    ImplementationSafe implSafe;
    SimpleProxy proxy;

    address attacker = address(0xBEEF);
    address user = address(0xCAFE);

    function setUp() public {
        // Deploy vulnerable implementation and a proxy pointing to it
        implVuln = new ImplementationVulnerable();
        proxy = new SimpleProxy(address(implVuln));

        // Deploy safe implementation (constructor called => initializers disabled)
        implSafe = new ImplementationSafe();
    }

    function test_attacker_can_initialize_implementation_directly() public {
        // Before attacker calls anything, implementation's owner is zero
        assertEq(implVuln.owner(), address(0));

        // Attacker calls initialize() directly on the IMPLEMENTATION contract
        vm.prank(attacker);
        implVuln.initialize();

        // Attacker becomes owner of the implementation contract
        assertEq(implVuln.owner(), attacker);

        // Note: This is dangerous because the implementation exists on-chain.
        // Even if normal users interact through the proxy, the implementation
        // being claimable is an immediate HIGH severity issue.
    }

    function test_cannot_initialize_safe_implementation() public {
        // constructor called _initialized = true, so initialize() should revert
        vm.expectRevert(bytes("already initialized"));
        vm.prank(attacker);
        implSafe.initialize();
    }

    function test_proxy_interaction_initializes_proxy_storage() public {
        // Interact with the proxy to initialize the PROXY storage via delegatecall
        // build calldata for initialize()
        bytes memory data = abi.encodeWithSignature("initialize()");
        vm.prank(user);
        (bool success, ) = address(proxy).call(data);
        require(success, "proxy initialize failed");

        // When we read owner() via the IMPLEMENTATION address we get implementation.owner()
        // but the real owner used in the protocol is stored in the proxy slot via delegatecall.
        // Reading proxy.storage requires a small helper: call owner() on the proxy (delegatecall)
        (bool ok, bytes memory ret) = address(proxy).call(abi.encodeWithSignature("owner()"));
        require(ok, "owner() via proxy failed");
        address proxyOwner = abi.decode(ret, (address));
        assertEq(proxyOwner, user);

        // However, the implementation contract's owner variable remains untouched
        assertEq(implVuln.owner(), address(0));

        // This demonstrates that initializing via PROXY sets proxy storage (expected),
        // while initializing IMPLEMENTATION directly targets a different storage slot and is dangerous.
    }
}
