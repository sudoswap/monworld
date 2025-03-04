// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "solady/Milady.sol";

import "./SimplexNoise.sol";
import "../types/Types.sol";

enum TerrainType {
    WATER,
    GRASSLAND,
    FOREST,
    MOUNTAIN
}

library MapGen {
    using FixedPointMathLib for *;

    bytes32 private constant PERM_0_A =
        0x4871783ffab360ed8da8cd08b2e95a3db0bcbd2183d1640fa7ecc1aa31fcc279495135c4d49fdb4d4b33c7e2066fc9664e466786f66ef085b84a7543737bcffb;
    bytes32 private constant PERM_0_B =
        0x7ec887371bad0aacce22f720eb565da6a105dcab0ce530d22dc0170318a38bff72985f1d2a0b55e4f9f49c249953be9bc389024f2ba2f15e5be3ee9e23ae2f0d;
    bytes32 private constant PERM_0_C =
        0xbbb48e3ce17609651c477f8461596bbf29449d6c2ed39a3aaf1690da1526d813b97dbad08a14c682f2e73e417a403969819407e08f6a91258893d9de3827ea68;
    bytes32 private constant PERM_0_D =
        0xa0346d0158d53252b5288070969574f3dfdd1ed75c1a3bfdcca5575062e6110ec510042c771997efcb36d68ccaa4427c4c001fe863a954fe4512b6f892b1b7f5;

    bytes32 private constant PERM_1_A =
        0x8d165fde6efe8c646f4043c11a8a092399c6beef244ada3fd6f110767236c0a0a9d9f579a4617e5b7473b056201850a5c2f2c3db2f3b895d04651dcc2b688301;
    bytes32 private constant PERM_1_B =
        0x0a546c5c05b1a1e9b43730a848e829fbb82d7be19ef7916b5145e08800aef6fa32ea9cec3d493cfcebb56d862797bc0b38b37d3987924e1b57171e600794acbd;
    bytes32 private constant PERM_1_C =
        0x69f475f87caa774fa3ed4d6a194cf0ad9f9bdf620dd2e6d390ee463155d8dd3a63f382030f2547788e2c13af7f2eb91c2a5effb7cb417a2135d5149dcfc5c4f9;
    bytes32 private constant PERM_1_D =
        0xdcce42ab3ec80e805202ba28a6d43395fd151f668fb2cd531208e48be7d0a21184e581d17044b6e29a4b062693e38571d758c734675a22cac998bf0cbb59a796;

    int256 internal constant WAD = 1 ether;
    int256 internal constant ELEVATION_BIAS_WAD = 0.1 ether;

    int256 internal constant WATER_THRESHOLD_WAD = -0.2 ether;
    int256 internal constant MOUNTAIN_THRESHOLD_WAD = 0.3 ether;
    int256 internal constant FOREST_THRESHOLD_WAD = 0.55 ether;

    uint256 internal constant MIN_SIMILAR_NEIGHBORS = 2  // Minimum similar neighbors to prevent isolated tiles
    uint256 internal constant FOREST_SPREAD_THRESHOLD = 4 // Neighbors needed for forest to spread
    uint256 internal constant MOUNTAIN_SPREAD_THRESHOLD = 5 // Neighbors needed for mountains to spread
    uint256 internal constant WATER_SPREAD_THRESHOLD = 6 // Neighbors needed for water to spread

    /// @notice Returns the elevation at a position, result is between -1 and 1 and scaled by WAD.
    function getElevation(Position pos) internal pure returns (int256 elevationWad) {
        elevationWad = fractal({pos: pos, octaves: 3, persistenceWad: 0.5 ether, lacunarityWad: 2 ether, permId: 0});
        elevationWad += ELEVATION_BIAS_WAD;
        elevationWad = elevationWad.clamp(-WAD, WAD);
    }

    /// @notice Returns the moisture at a position, result is between 0 and 1 and scaled by WAD.
    function getMoisture(Position pos) internal pure returns (int256 moistureWad) {
        moistureWad = fractal({pos: pos, octaves: 2, persistenceWad: 0.5 ether, lacunarityWad: 2 ether, permId: 1});
        moistureWad = (moistureWad + WAD) / 2; // scale to 0-1
    }

    function getTerrainType(Position pos) internal pure returns (TerrainType terrain) {
        int256 elevationWad = getElevation(pos);
        int256 moistureWad = getMoisture(pos);

        // Use elevation and moisture to determine terrain type
        if (elevationWad < WATER_THRESHOLD_WAD) {
            terrain = TerrainType.WATER;
        } else if (elevationWad > MOUNTAIN_THRESHOLD_WAD) {
            terrain = TerrainType.MOUNTAIN;
        } else {
            if (moistureWad > FOREST_THRESHOLD_WAD) {
                terrain = TerrainType.FOREST;
            } else {
                terrain = TerrainType.GRASSLAND;
            }
        }

        // Apply terrain coherence
        terrain = applyTerrainCoherence(pos, terrain);

        return terrain;
    }

    function applyTerrainCoherence(Position pos, TerrainType terrain) internal pure returns (TerrainType newTerrain) {
        // TODO
    }

    function fractal(Position pos, uint8 octaves, int256 persistenceWad, int128 lacunarityWad, uint256 permId)
        private
        pure
        returns (int256 total)
    {
        if (octaves == 0) return 0;
        int128 x = pos.x();
        int128 y = pos.y();
        int128 frequency = 1;
        int256 amplitude = 1;
        int256 maxValue = 0;
        (bytes32 permA, bytes32 permB, bytes32 permC, bytes32 permD) =
            permId == 0 ? (PERM_0_A, PERM_0_B, PERM_0_C, PERM_0_D) : (PERM_1_A, PERM_1_B, PERM_1_C, PERM_1_D);
        for (uint256 i; i < octaves; i++) {
            total += SimplexNoise.noise(x * frequency, y * frequency, permA, permB, permC, permD) * amplitude;
            maxValue += amplitude;
            amplitude = amplitude.sMulWad(persistenceWad);
            frequency = frequency.sMulWad(lacunarityWad);
        }
        return total / maxValue;
    }
}
