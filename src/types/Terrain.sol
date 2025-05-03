// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "./TerrainType.sol";

struct Terrain {
    TerrainType ttype;
    uint256 energyCost;
}

library TerrainLib {
    uint256 internal constant ENERGY_PER_BLOCK = 100;
    uint256 private constant IMPASSABLE = ENERGY_PER_BLOCK + 1;
    bytes private constant ENERGY_COST_LOOKUP = abi.encode(
        [
            IMPASSABLE, // NONE
            IMPASSABLE, // WATER
            20, // GRASSLAND
            50, // FOREST
            IMPASSABLE, // MOUNTAIN
            IMPASSABLE, // FENCE
            10, // ROAD
            20, // FARMLAND
            10, // PAVEMENT
            IMPASSABLE, // WALL
            10 // DOOR
        ]
    );

    function ttypeToTerrain(TerrainType ttype) internal pure returns (Terrain memory terrain) {
        uint256[11] memory energyCostLookup = abi.decode(ENERGY_COST_LOOKUP, (uint256[11]));
        terrain = Terrain({ttype: ttype, energyCost: energyCostLookup[uint8(ttype)]});
    }
}
