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
    using SafeCastLib for *;
    using FixedPointMathLib for *;

    bytes32 private constant PERM_0_A = 0x2b6622a59179ac312924954506c6996ace203303dc6fe7d5c9a658c56d3ccbd6;
    bytes32 private constant PERM_0_B = 0x7d69defeda628f23508db18ae9b757e34198a242c0af8534cfaef45ec838c3f2;
    bytes32 private constant PERM_0_C = 0x48aa74ad196bd7b8f69654f1d0f52e2de500882a3b0f83351367051bba971d0a;
    bytes32 private constant PERM_0_D = 0xefb57b271415a18efcf9b972a9391171eb9e5a0d1ab33d8cd30204599037e216;
    bytes32 private constant PERM_0_E = 0x4dbb84e8402f43c40e529b535f92364cb056a7a4d261eaeeab639adf9f75ec5c;
    bytes32 private constant PERM_0_F = 0xb69480d921bf87fbe66cf3ffe0fd075dc2080b10861ff89dc7b481caa37355bd;
    bytes32 private constant PERM_0_G = 0x324ad47c9c5b76264f6e473edd68a0bc704e8b17933a303f1851e1e4f7bedbd8;
    bytes32 private constant PERM_0_H = 0x257801d128ed7e46cc12a8654b1efa2c49b27f0c89c182647a77f04409cd601c;

    bytes32 private constant PERM_1_A = 0xa6e2114596ef3843d767d566bbac6a544f6e6da25eb4f84bce728a7464d914ad;
    bytes32 private constant PERM_1_B = 0x3ddb51c2e053e7a17a250bcdf6dcf7210e629fe112b86ffc873733be286800f5;
    bytes32 private constant PERM_1_C = 0x2fd2fd7db73cd13699b28bd6e82a49b1d818cb6b717386084d4c193504e98e46;
    bytes32 private constant PERM_1_D = 0xf061a0767bdd0c59a99c2b025c9eb981bfd31af926804e91a4133e635f1d0527;
    bytes32 private constant PERM_1_E = 0xabff40dffb7993e3cc98eebc29de34ca22a5e4f465bac3a7708c85507884cf09;
    bytes32 private constant PERM_1_F = 0xec413b4a2030c4aa95529d150a48428947ead4ed8f771e07c1c5582c7f825d0f;
    bytes32 private constant PERM_1_G = 0x172e39607eb5c7012d9b31c6c0fec9b05b24a31cb397f3559a7c3afaa8c8ae1f;
    bytes32 private constant PERM_1_H = 0x3faf0df21b5a23b6168344f188dae50669bd8dd0109057e603756ceb92943256;

    int256 internal constant WAD = 1 ether;
    int256 internal constant ELEVATION_BIAS_WAD = 0.1 ether;

    int256 internal constant WATER_THRESHOLD_WAD = -0.2 ether;
    int256 internal constant MOUNTAIN_THRESHOLD_WAD = 0.3 ether;
    int256 internal constant FOREST_THRESHOLD_WAD = 0.55 ether;

    uint256 internal constant MIN_SIMILAR_NEIGHBORS = 2; // Minimum similar neighbors to prevent isolated tiles
    uint256 internal constant FOREST_SPREAD_THRESHOLD = 4; // Neighbors needed for forest to spread
    uint256 internal constant MOUNTAIN_SPREAD_THRESHOLD = 5; // Neighbors needed for mountains to spread
    uint256 internal constant WATER_SPREAD_THRESHOLD = 6; // Neighbors needed for water to spread

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
        // Count of neighbor terrain types
        uint256 waterCount = 0;
        uint256 forestCount = 0;
        uint256 mountainCount = 0;
        uint256 grasslandCount = 0;
        uint256 similarCount = 0;

        // Check all 8 immediate neighbors
        for (int128 dx = -1; dx <= 1; dx++) {
            for (int128 dy = -1; dy <= 1; dy++) {
                if (dx == 0 && dy == 0) continue;

                // Get neighbor position
                Position neighbor = PositionLib.fromCoordinates(pos.x() + dx, pos.y() + dy);

                // Determine neighbor terrain type directly from elevation/moisture
                int256 neighborElevation = getElevation(neighbor);
                TerrainType neighborTerrain;

                if (neighborElevation < WATER_THRESHOLD_WAD) {
                    neighborTerrain = TerrainType.WATER;
                    waterCount++;
                } else if (neighborElevation > MOUNTAIN_THRESHOLD_WAD) {
                    neighborTerrain = TerrainType.MOUNTAIN;
                    mountainCount++;
                } else {
                    // Middle elevations - check moisture for forest
                    if (getMoisture(neighbor) > FOREST_THRESHOLD_WAD) {
                        neighborTerrain = TerrainType.FOREST;
                        forestCount++;
                    } else {
                        neighborTerrain = TerrainType.GRASSLAND;
                        grasslandCount++;
                    }
                }

                // Count similar terrain
                if (neighborTerrain == terrain) {
                    similarCount++;
                }
            }
        }

        // Rule 1: Fix isolated terrain tiles
        if (similarCount < MIN_SIMILAR_NEIGHBORS) {
            // Find most common terrain type
            newTerrain = TerrainType.GRASSLAND; // Default
            uint256 maxCount = 0;

            if (waterCount > maxCount) {
                maxCount = waterCount;
                newTerrain = TerrainType.WATER;
            }

            if (grasslandCount > maxCount) {
                maxCount = grasslandCount;
                newTerrain = TerrainType.GRASSLAND;
            }

            if (forestCount > maxCount) {
                maxCount = forestCount;
                newTerrain = TerrainType.FOREST;
            }

            if (mountainCount > maxCount) {
                maxCount = mountainCount;
                newTerrain = TerrainType.MOUNTAIN;
            }

            return newTerrain;
        }

        // Rule 2: Encourage terrain clustering
        if (terrain == TerrainType.GRASSLAND) {
            // Convert grassland to forest if surrounded by forests
            if (forestCount >= FOREST_SPREAD_THRESHOLD) {
                newTerrain = TerrainType.FOREST;
            }
            // Mountains shouldn't be too close to water
            else if (mountainCount >= MOUNTAIN_SPREAD_THRESHOLD && waterCount == 0) {
                newTerrain = TerrainType.MOUNTAIN;
            }
            // Water spreads less aggressively
            else if (waterCount >= WATER_SPREAD_THRESHOLD) {
                newTerrain = TerrainType.WATER;
            }
            // Default: keep original terrain
            else {
                newTerrain = terrain;
            }
        }
        // Rule 3: Ensure mountains don't form next to water
        else if (terrain == TerrainType.MOUNTAIN && waterCount > 0) {
            newTerrain = TerrainType.GRASSLAND;
        }
        // Default: keep original terrain
        else {
            newTerrain = terrain;
        }
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
        (
            bytes32 permA,
            bytes32 permB,
            bytes32 permC,
            bytes32 permD,
            bytes32 permE,
            bytes32 permF,
            bytes32 permG,
            bytes32 permH
        ) = permId == 0
            ? (PERM_0_A, PERM_0_B, PERM_0_C, PERM_0_D, PERM_0_E, PERM_0_F, PERM_0_G, PERM_0_H)
            : (PERM_1_A, PERM_1_B, PERM_1_C, PERM_1_D, PERM_1_E, PERM_1_F, PERM_1_G, PERM_1_H);
        for (uint256 i; i < octaves; i++) {
            total += SimplexNoise.noise(
                x * frequency, y * frequency, permA, permB, permC, permD, permE, permF, permG, permH
            ) * amplitude;
            maxValue += amplitude;
            amplitude = amplitude.sMulWad(persistenceWad);
            frequency = frequency.sMulWad(lacunarityWad).toInt128();
        }
        return total / maxValue;
    }
}
