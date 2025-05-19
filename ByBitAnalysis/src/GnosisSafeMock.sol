// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GnosisSafeMock {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function execTransaction(address to, bytes memory data) public {
        // Simulate a delegatecall (vulnerability point)
        (bool success, ) = to.delegatecall(data);
        require(success, "Delegatecall failed");
    }

    function sweepETH(address to) external {
        require(msg.sender == owner, "Not owner");
        payable(to).transfer(address(this).balance);
    }

    receive() external payable {}
}
