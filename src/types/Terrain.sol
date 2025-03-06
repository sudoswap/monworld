// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "./TerrainType.sol";

struct Terrain {
    TerrainType ttype;
    uint256 blocksToMove;
}

library TerrainLib {
    uint256 private constant IMPASSABLE = type(uint128).max;
    bytes private constant BLOCKS_TO_MOVE_LOOKUP = abi.encode(
        [
            IMPASSABLE, // NONE
            IMPASSABLE, // WATER
            10, // GRASSLAND
            20, // FOREST
            IMPASSABLE, // MOUNTAIN
            IMPASSABLE, // FENCE
            8, // ROAD
            10, // FARMLAND
            8, // PAVEMENT
            IMPASSABLE, // WALL
            8 // DOOR
        ]
    );

    function ttypeToTerrain(TerrainType ttype) internal pure returns (Terrain memory terrain) {
        uint256[] memory blocksToMoveLookup = abi.decode(BLOCKS_TO_MOVE_LOOKUP, (uint256[]));
        terrain = Terrain({ttype: ttype, blocksToMove: blocksToMoveLookup[uint8(ttype)]});
    }
}
