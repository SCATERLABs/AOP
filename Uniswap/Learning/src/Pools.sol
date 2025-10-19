// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Pools.sol";

contract Factory {
    address[] public pair_Token_pools;
    address public Owner;

    constructor(address _Owner) {
        Owner = _Owner;
    }
//events
    event PoolCreated(address indexed token1, address indexed token0, address poolAddress);
    modifier onlyOwner() {
        require(msg.sender == Owner, "Not the owner");
        _;
    }

    // Using CREATE2 for deterministic address calculation
    function createPair_Token_pool(address token1, address token0) public onlyOwner returns (address pool) {
        bytes32 salt = keccak256(abi.encodePacked(token1, token0));
        //compute the address of the new pool using CREATE2
        address computedAddress = computeAddress(token1, token0);
        require(computedAddress == address(0), "Pool already exists");
        emit PoolCreated(token1, token0, computedAddress);
        pool = address(new Pools{salt: salt}(token1, token0));
        pair_Token_pools.push(pool);
    }

    function getAllPools() public view returns (address[] memory) {
        return pair_Token_pools;
    }

    // Helper to predict address before deployment
    function computeAddress(address token1, address token0) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(token1, token0));
        bytes memory bytecode = abi.encodePacked(type(Pools).creationCode, abi.encode(token1, token0));
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
        );
        return address(uint160(uint256(hash)));
    }
}
