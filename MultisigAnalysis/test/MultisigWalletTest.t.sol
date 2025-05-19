// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MultisigWallet} from "../src/Multisig_Wallet.sol";
import "MultisigAnalysis/lib/forge-std/src/Test.sol";

// import "MultisigAnalysis/lib/forge-std/src/console.sol";

contract MultisigWalletTest is Test {
    MultisigWallet wallet;
    address[] owners = new address[](3);
    address owner1 = address(0xA1);
    address owner2 = address(0xA2);
    address owner3 = address(0xA3);
    address recipient = address(0xB0);

    function setUp() public {
        address;
        owners[0] = owner1;
        owners[2] = owner3;

        wallet = new MultisigWallet(owners, 2);

        // Fund the wallet with 10 ether
        vm.deal(address(this), 10 ether);
        payable(address(wallet)).transfer(5 ether);
    }

    function testSubmitConfirmExecute() public {
        // Submit transaction by owner1
        vm.prank(owner1);
        bytes memory data = (abi.encodePacked(recipient, "send amout to nk"));
        wallet.submitTransaction(recipient, 1 ether, data);

        // Confirm by owner1
        vm.prank(owner1);
        wallet.confirmTransaction(0);

        // Confirm by owner2
        vm.prank(owner2);
        wallet.confirmTransaction(0);

        uint recipientBalanceBefore = recipient.balance;

        // Execute by owner3
        vm.prank(owner3);
        wallet.executeTransaction(0);

        uint recipientBalanceAfter = recipient.balance;
        assertEq(recipientBalanceAfter - recipientBalanceBefore, 1 ether);
    }

    function test_FailExecuteWithoutEnoughConfirmations() public {
        // Submit transaction by owner1
        vm.prank(owner1);
        bytes memory data = (abi.encodePacked(recipient, "send amout to nk"));
        wallet.submitTransaction(recipient, 1 ether, data);

        // Only one confirmation
        vm.prank(owner1);
        wallet.confirmTransaction(0);
        vm.expectRevert();
        // Should fail because not enough confirmations
        vm.prank(owner2);
        wallet.executeTransaction(0);
    }

    function test_Revert_When_DoubleConfirm() public {
        // Arrange
        vm.prank(owner1);
        wallet.submitTransaction(address(0), 0, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.expectRevert();
        vm.prank(owner1);
        wallet.confirmTransaction(0); // this will revert
    }
}
