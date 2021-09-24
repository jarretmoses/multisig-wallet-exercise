// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.0 <0.9.0;

contract SimpleStorage {
    uint public storedData;

    address public caller;

    function set(uint x) public {
        caller = msg.sender;
        storedData = x;
    }
}
