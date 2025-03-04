// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {MoveDirection} from "./MoveDirection.sol";

type Position is bytes32;

using PositionLib for Position global;
using {equals as ==} for Position global;

function equals(Position pos1, Position pos2) pure returns (bool) {
    return Position.unwrap(pos1) == Position.unwrap(pos2);
}

library PositionLib {
    function x(Position pos) internal pure returns (int128) {
        return int128(uint128(bytes16(Position.unwrap(pos))));
    }

    function y(Position pos) internal pure returns (int128) {
        return int128(uint128(bytes16(Position.unwrap(pos) << 128)));
    }

    function fromCoordinates(int128 xCord, int128 yCord) internal pure returns (Position) {
        return Position.wrap(bytes32(uint256(uint128(xCord)) << 128 | uint256(uint128(yCord))));
    }

    function applyMove(Position pos, MoveDirection dir) internal pure returns (Position newPos) {
        uint128 dirValue = uint8(dir);

        // Extract axis and sign from direction value
        int128 isHorizontal = int128(dirValue >> 1);
        int128 directionMultiplier = 1 - 2 * int128(dirValue & 1);

        // Apply movement
        return PositionLib.fromCoordinates(
            pos.x() + isHorizontal * directionMultiplier, pos.y() + (1 - isHorizontal) * directionMultiplier
        );
    }
}
