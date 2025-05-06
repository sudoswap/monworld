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

    function testTtypesPacked() public view {
        int128[] memory xList = new int128[](10);
        int128[] memory yList = new int128[](10);
        for (uint256 i; i < 10; i++) {
            xList[i] = int128(uint128(i));
            yList[i] = int128(uint128(i));
        }
        bytes memory packedTtypes = world.getTtypesPacked(xList, yList);
        assertEq(packedTtypes.length, 10, "length incorrect");
    }
}
