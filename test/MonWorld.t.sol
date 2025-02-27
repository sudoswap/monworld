// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MonWorld} from "../src/MonWorld.sol";

contract CounterTest is Test {
    MonWorld public world;

    function setUp() public {
        world = new MonWorld();
    }
}
