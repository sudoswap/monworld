// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MonWorld} from "../src/MonWorld.sol";

import "../src/types/Types.sol";

contract CounterTest is Test {
    MonWorld public world;

    function setUp() public {
        world = new MonWorld();
    }

    function testPosition(int128 xCord, int128 yCord) public pure {
        Position pos = PositionLib.fromCoordinates(xCord, yCord);
        (int128 x, int128 y) = (pos.x(), pos.y());
        assertEq(x, xCord, "x incorrect");
        assertEq(y, yCord, "y incorrect");
    }
}
