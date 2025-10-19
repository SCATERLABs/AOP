import "./Pools";

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Factory {
    address[] public pair_Token_pools;
    address public Owner;
    constructor(address _Owner) {
        Owner = _Owner;
    }
    modifier onlyOwner() {
        require(msg.sender == Owner, "Not the owner");
        _;
    }

    function createPair_Token_pool(address token1,address token0) public  onlyOwner returns (address){

        address newPair_Token_pool = address(new Pair_Token_pool(address token1, address token0));
        pair_Token_pools.push(newPair_Token_pool);
        return newPair_Token_pool;
    }

}