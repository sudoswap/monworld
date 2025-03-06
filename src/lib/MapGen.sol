// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "solady/Milady.sol";

import "./SimplexNoise.sol";
import "../types/Types.sol";

library MapGen {
    using SafeCastLib for *;
    using FixedPointMathLib for *;

    bytes private constant PERM_0 =
        hex"cb74db577ff9dca03ecd0c40793d89da8197fb763f48299013f510cc5a01068aa116d015c191c9805195ffaa1f845c6f8e2724c54c56caf18c6c2d7894ef030de2266639fc9e96b6d7508263734b4ddf32eeddbcb431a45e0f720a936853ec3a4ac247ac3baf65c0e5ae98b2a569aba8676b144964c3f3375d2871365925e32ce62e55a9751c60862118be38fdb97a83b3d923d358442fa25fc8bd086ed2adb061346a9be16da34207fa5b879f3cf0eb7da646c4f8852270e4bfd88bedf7f28dcf772bde52029d1930bab1623599ce452a9ac71d54f617334f7cc60bb5fee9921b1109207b1ee041ea7ea700e8d6d59c1a4eb8f4430512e7d1b7040ed4bb888f";
    bytes private constant PERM_1 =
        hex"161c0e3f5a41dc520f79a697a530a2e4b080241df6ba90d5fd22f0f5c623faa7f79bd7448fa358087a18c426fbd111c5e972d22909150bd927d404b942d314849e35f4bef2fce8ea6907ef8cace0daaf6631773e6b9dd8fe3c36861e7f49ff821995ec5194bfe2a4eb819fce91f16a85398e4c37bb55b7eebd76015f3d45b8c8e7a1aedf9217aa89cc133b2d5bca4ef3bc0a2847b4c02560de73e675db886cab4b545c989368d000cb561fb26d8b9a02995e432ae153a88a507465207e59cd2c12ed2e0d70b65d6164b3adcf349c578ddd78e562634d2f213af8a06703338305107c876f3246a938c96eb5c17dc77bc32bc24ab1711a484fd696f940e31b0c06";

    int256 internal constant WAD = 1 ether;
    int256 internal constant ELEVATION_BIAS_WAD = 0.1 ether;

    int256 internal constant WATER_THRESHOLD_WAD = -0.2 ether;
    int256 internal constant MOUNTAIN_THRESHOLD_WAD = 0.35 ether;
    int256 internal constant FOREST_THRESHOLD_WAD = 0.55 ether;

    uint256 internal constant MIN_SIMILAR_NEIGHBORS = 2; // Minimum similar neighbors to prevent isolated tiles
    uint256 internal constant FOREST_SPREAD_THRESHOLD = 4; // Neighbors needed for forest to spread
    uint256 internal constant MOUNTAIN_SPREAD_THRESHOLD = 5; // Neighbors needed for mountains to spread
    uint256 internal constant WATER_SPREAD_THRESHOLD = 6; // Neighbors needed for water to spread

    /// @notice Returns the elevation at a position, result is between -1 and 1 and scaled by WAD.
    function getElevation(Position pos) internal pure returns (int256 elevationWad) {
        elevationWad = fractal({
            pos: pos,
            octaves: 4,
            persistenceWad: 0.7 ether,
            lacunarityWad: 1.43 ether,
            scaleWad: 1 ether,
            permId: 0
        });
        elevationWad += ELEVATION_BIAS_WAD;
        elevationWad = elevationWad.clamp(-WAD, WAD);
    }

    /// @notice Returns the moisture at a position, result is between 0 and 1 and scaled by WAD.
    function getMoisture(Position pos) internal pure returns (int256 moistureWad) {
        moistureWad = fractal({
            pos: pos,
            octaves: 6,
            persistenceWad: 0.5 ether,
            lacunarityWad: 2 ether,
            scaleWad: 1 ether,
            permId: 1
        });
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

    function fractal(
        Position pos,
        uint8 octaves,
        int256 persistenceWad,
        int128 lacunarityWad,
        int128 scaleWad,
        uint256 permId
    ) private pure returns (int256 total) {
        if (octaves == 0) return 0;
        int128 x = pos.x();
        int128 y = pos.y();
        int128 frequencyWad = scaleWad;
        int256 amplitudeWad = WAD;
        int256 maxValueWad = 0;
        bytes memory perm = permId == 0 ? PERM_0 : PERM_1;
        for (uint256 i; i < octaves; i++) {
            total += SimplexNoise.noise(x.sMulWad(frequencyWad).toInt128(), y.sMulWad(frequencyWad).toInt128(), perm)
                .sMulWad(amplitudeWad);
            maxValueWad += amplitudeWad;
            amplitudeWad = amplitudeWad.sMulWad(persistenceWad);
            frequencyWad = frequencyWad.sMulWad(lacunarityWad).toInt128();
        }
        return total.sDivWad(maxValueWad);
    }
}
