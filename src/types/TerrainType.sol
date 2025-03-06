// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

enum TerrainType {
    NONE,
    WATER,
    GRASSLAND,
    FOREST,
    MOUNTAIN,
    FENCE,
    ROAD,
    FARMLAND,
    PAVEMENT,
    WALL,
    DOOR
}

using TerrainTypeLib for TerrainType global;

library TerrainTypeLib {
    function isStructure(TerrainType ttype) internal pure returns (bool) {
        return uint8(ttype) >= uint8(TerrainType.FENCE);
    }
}
