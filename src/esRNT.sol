// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract esRNT {
    struct LockInfo{
        address user;
        uint64 startTime; 
        uint256 amount;
    }
   
    LockInfo[] private _locks;

    constructor() { 
        for (uint256 i = 0; i < 11; i++) {
            _locks.push(LockInfo(address(uint160(i+1)), uint64(block.timestamp*2-i), 1e18*(i+1)));
        }
    }

    function getLock(uint256 i) external view returns (address user, uint64 startTime, uint256 amount) {
        require(i < _locks.length, "index out of bounds");
        LockInfo storage lock = _locks[i];
        return (lock.user, lock.startTime, lock.amount);
    }

    function getLocksLength() external view returns (uint256) {
        return _locks.length;
    }
}
