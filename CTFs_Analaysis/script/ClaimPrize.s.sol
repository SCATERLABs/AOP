// script/ClaimPrize.s.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

// We only need a minimal interface for the Attacker contract we are calling
interface IAttacker {
    function claim() external;
}

contract ClaimPrizeScript is Script {
    // The run function takes the address of the deployed Attacker contract as an argument
    function run(address attackerAddress) external {
        // Get the private key from your environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Call the claim() function on the already-deployed Attacker contract
        IAttacker(attackerAddress).claim();

        vm.stopBroadcast();
    }
}