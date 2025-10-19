// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "../src/TP_UUPS.sol";


// -------------------------
// Tests demonstrating differences
// -------------------------
contract ProxyPatternsTest is Test {
    // Transparent proxy scenario
    TransparentProxy transparentProxy;
    ProxyAdmin proxyAdmin;
    LogicV1 logic1;
    LogicV2 logic2;

    // UUPS scenario
    EIP1967ProxyMinimal uupsProxy;
    UUPSImplVulnerable uupsVulnImpl;
    UUPSImplSafe uupsSafeImpl;

    address admin = address(0xA11CE);
    address alice = address(0xB0B);
    address attacker = address(0xE1E1);

    function setUp() public {
        // Transparent setup
        logic1 = new LogicV1();
        proxyAdmin = new ProxyAdmin();
        transparentProxy = new TransparentProxy(address(logic1), address(proxyAdmin));
        logic2 = new LogicV2();

        // UUPS setup - vulnerable impl
        uupsVulnImpl = new UUPSImplVulnerable();
        uupsProxy = new EIP1967ProxyMinimal(address(uupsVulnImpl));

        // UUPS safe impl
        uupsSafeImpl = new UUPSImplSafe();
    }

    // Helper to call proxy's initialize via delegatecall
    function proxyInitialize(address proxyAddr, address who) internal {
        (bool ok,) = proxyAddr.call(abi.encodeWithSignature("initialize(address)", who));
        require(ok, "proxy init failed");
    }

    function test_transparent_upgrade_by_admin() public {
        // initialize via proxy (delegatecall) - storage goes to proxy
        proxyInitialize(address(transparentProxy), alice);

        // Check owner via proxy delegatecall
        (bool ok, bytes memory ret) = address(transparentProxy).call(abi.encodeWithSignature("owner()"));
        require(ok, "owner via proxy failed");
        address ownerViaProxy = abi.decode(ret, (address));
        assertEq(ownerViaProxy, alice);

        // Admin upgrades implementation via ProxyAdmin helper (admin must call)
        // Note: In production, ProxyAdmin would have access control (e.g., only owner can call)
        // For this test, anyone can call ProxyAdmin.upgrade()
        proxyAdmin.upgrade(transparentProxy, address(logic2));

        // After upgrade, new implementation has inc()
        // call inc via proxy
        (ok,) = address(transparentProxy).call(abi.encodeWithSignature("inc()"));
        require(ok, "inc via proxy failed");

        // x should be still accessible and changed in proxy storage
        (ok, ret) = address(transparentProxy).call(abi.encodeWithSignature("getX()"));
        uint256 xVal = abi.decode(ret, (uint256));
        assertEq(xVal, 1);
    }

    function test_uups_vulnerable_upgrade_by_attacker() public {
        // initialize proxy via delegatecall as alice
        proxyInitialize(address(uupsProxy), alice);

        // Attacker calls upgradeTo on implementation *via proxy* (delegatecall) because implementation has unprotected upgradeTo
        vm.prank(attacker);
        (bool ok, ) = address(uupsProxy).call(abi.encodeWithSignature("upgradeTo(address)", address(logic2)));
        require(ok, "attacker upgrade failed");

        // Now the proxy implementation slot should point to logic2
        // Call inc() via proxy to see effect
        (ok, ) = address(uupsProxy).call(abi.encodeWithSignature("inc()"));
        require(ok, "inc via proxy failed");

        // Read getX()
        bytes memory ret;
        (ok, ret) = address(uupsProxy).call(abi.encodeWithSignature("getX()"));
        uint256 xVal = abi.decode(ret, (uint256));
        assertEq(xVal, 1);
    }

    function test_uups_safe_requires_owner_for_upgrade() public {
        // deploy proxy pointing to safe impl
        EIP1967ProxyMinimal safeProxy = new EIP1967ProxyMinimal(address(uupsSafeImpl));
        // initialize as alice
        proxyInitialize(address(safeProxy), alice);

        // attacker tries to upgrade
        vm.prank(attacker);
        (bool ok, ) = address(safeProxy).call(abi.encodeWithSignature("upgradeTo(address)", address(logic2)));
        // should revert because msg.sender != owner inside implementation's upgradeTo
        require(!ok, "attacker upgrade unexpectedly succeeded");

        // owner (alice) upgrades
        vm.prank(alice);
        (ok, ) = address(safeProxy).call(abi.encodeWithSignature("upgradeTo(address)", address(logic2)));
        require(ok, "owner upgrade failed");

        // inc via proxy works
        (ok, ) = address(safeProxy).call(abi.encodeWithSignature("inc()"));
        require(ok, "inc via proxy failed");
    }
}
