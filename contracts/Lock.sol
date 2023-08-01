// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract Raffle {
    uint256 private immutable i_entranceFee;

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public {}
}
